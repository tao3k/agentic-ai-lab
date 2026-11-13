;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :clan/poo/object .get .cc .o)
        (only-in :std/source this-source-file)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :std/crypto/digest sha256)
        (only-in :tao3k/yuanxu/ops/interface Ops)
        (only-in :tao3k/yuanxu/ops/func run-script)
        (only-in :tao3k/yuanxu/ops/progress execution-progress!)
        (only-in :tao3k/yuanxu/observability/testing-script make-compiler-progress-reader)
        (only-in :tao3k/yuanxu/module-system/source/observations module-source-read)
        (only-in :tao3k/yuanxu/module-system/building/products artifact-files)
        (only-in "./qualification/yuanxu-build-events.ss" compile-events))
(export yuanxu-context-memory-downstream-test)

(def (copy-source from to)
  (if (eq? (file-info-type (file-info from)) 'directory)
    (begin
      (create-directory to)
      (for-each (lambda (name) (copy-source (path-expand name from) (path-expand name to)))
                (directory-files from)))
    (copy-file from to)))

(def (rewrite path old new)
  (def text (module-source-read path))
  (def at (string-contains text old))
  (unless at (error "Context fixture declaration missing" path old))
  (call-with-output-file (list path: path truncate: #t)
    (lambda (out)
      (display (substring text 0 at) out)
      (display new out)
      (display (substring text (+ at (string-length old)) (string-length text)) out))))

(def (product-digests targets library)
  (map (lambda (path) (cons path (sha256 (call-with-input-file path read-all-as-u8vector))))
       (list-sort string<? (artifact-files (map string->symbol targets) library))))

(def base-compile-targets
  '("agentic-ai-lab/modules/ai-agentic-context/config"
    "agentic-ai-lab/modules/ai-agentic-context/funs-features"
    "agentic-ai-lab/modules/ai-agentic-context/interface"
    "agentic-ai-lab/modules/ai-agentic-context/objects"
    "agentic-ai-lab/modules/ai-agentic-context/types"
    "agentic-ai-lab/modules/temporal-causality/time/types"
    "yuanxu-context-consumer/init"
    "yuanxu-context-consumer/main"
    "yuanxu-context-consumer/modules/review/config"
    "yuanxu-context-consumer/modules/review/interface"
    "yuanxu-context-consumer/modules/review/objects"
    "yuanxu-context-consumer/modules/review/types"))

(def memory-compile-targets
  (append
    (map (cut string-append "agentic-ai-lab/modules/ai-agentic-context/features/memory/" <>)
         '("config" "interface" "objects" "objects-builtin" "objects-catalog" "objects-core"
           "objects-durable" "objects-handoff" "objects-validation" "org-selection"
           "session-selection"))
    '("agentic-ai-lab/modules/module-authoring/module-config-syntax"
      "agentic-ai-lab/modules/session/durable-policy"
      "agentic-ai-lab/modules/session/objects-core"
      "agentic-ai-lab/modules/session/transform-support/memory-intent")))

(def yuanxu-context-memory-downstream-test
  (test-suite "Agentic Context Memory in an independent Gerbil package"
    (test-case "selected scope and compiler closure agree through enable, refinement and withdrawal"
      (def lab (path-normalize (path-expand ".." (path-directory (this-source-file)))))
      (def fixture (path-expand "t/qualification/yuanxu-context-consumer" lab))
      (def packages (path-expand "pkg" (gerbil-path)))
      (def installed-lab (path-expand "github.com/tao3k/agentic-ai-lab" packages))
      (unless (and (file-exists? installed-lab)
                   (let ((actual (file-info installed-lab)) (expected (file-info lab)))
                     (and (= (file-info-device actual) (file-info-device expected))
                          (= (file-info-inode actual) (file-info-inode expected)))))
        (error "install the Lab package under test before running the downstream acceptance" lab installed-lab))
      (def prerequisites (load-path))
      (def runtime-options (getenv "GAMBOPT"))
      (def completed 0)
      (call-with-temporary-directory "lab-context-memory-"
        (lambda (temporary)
          (def (state name flag)
            (def directory (path-expand name temporary))
            (def source (path-expand "source" directory))
            (def prefix (path-expand "prefix" directory))
            (create-directory* (path-expand "lib" prefix))
            ;; Reuse Gerbil's installed package set. Only the source fixture
            ;; and generated products belong to this downstream environment.
            (create-symbolic-link packages (path-expand "pkg" prefix))
            (copy-source fixture source)
            (rewrite (path-expand "init.ss" source) " +memory" flag)
            (.o name source prefix library: (path-expand "lib" prefix)))
          (def (action state command)
            (def started (real-time))
            (displayln "LAB-CONTEXT-ACTION enter state=" (.get state name) " command=" command
                       " at=" started " epoch=" (time->seconds (current-time)))
            (force-output)
            (def result
              (run-script
                (.cc (.get Ops prototypes Script)
                  command: command directory: (.get state source) timeout: 120 idle-timeout: 60
                  progress: make-compiler-progress-reader
                  environment: (.o GERBIL_PATH: (.get state prefix) GAMBOPT: runtime-options
                    GERBIL_BUILD_VERBOSE: (if (equal? (car command) "gerbil") "2" "0")
                    GERBIL_LOADPATH: (string-join (cons (.get state library) prerequisites) ":")))
                '() output-port: (current-error-port)))
            (def output (.get result output))
            (when (ormap (cut string-contains output <>)
                         '("*** ERROR" "ERROR CASE" "ERROR CHECK" "ERROR HARNESS" "Heap overflow" "Stack overflow"))
              (error "Context downstream action failed" command output))
            (set! completed (1+ completed))
            (execution-progress! 'lab-context-memory-actions completed)
            (displayln "LAB-CONTEXT-ACTION return state=" (.get state name) " command=" command
                       " seconds=" (- (real-time) started) " process=" (.get result seconds)
                       " epoch=" (time->seconds (current-time)))
            (force-output)
            output)
          (def (build! state (operation "build"))
            (def output (action state (list "gerbil" operation)))
            (check-equal? (and (string-contains output "BUILD-STAGE main return") #t) #t)
            (check-equal? (string-contains output "scope-factory") #f)
            (compile-events output))
          (def (use! state name)
            (check-equal?
              (and (string-contains (action state (list "gxi" "use.ss" name))
                                    (string-append "LAB-CONTEXT-USE-OK mode=" name)) #t) #t))
          (def base (state "base" ""))
          (def enabled (state "enabled" " +memory"))
          (def withdrawn (state "withdrawn" " -memory"))
          (def memory-prefix "agentic-ai-lab/modules/ai-agentic-context/features/memory/")
          (def base-targets (build! base))
          (check-equal? base-targets base-compile-targets)
          (def enabled-targets (build! enabled))
          (check-equal?
            (member "agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy"
                    enabled-targets)
            #f)
          (check-equal?
            (filter (cut string-prefix? (string-append memory-prefix "durable/") <>)
                    enabled-targets)
            '())
          ;; Exact lists also reject duplicate dispatch and equal-count substitutions.
          (check-equal? enabled-targets
            (list-sort string<? (append base-compile-targets memory-compile-targets)))
          (def withdrawn-targets (build! withdrawn))
          (def added (filter (lambda (target) (not (member target base-targets))) enabled-targets))
          (check-equal? base-targets withdrawn-targets)
          (check-equal? (artifact-files (map string->symbol added) (.get withdrawn library) #f) '())
          (def enabled-products (product-digests enabled-targets (.get enabled library)))
          (check-equal? (pair? enabled-products) #t)
          (use! base "base")
          (use! enabled "enabled")
          (use! withdrawn "withdrawn")
          (check-equal? (build! enabled) '())
          (check-equal? (build! withdrawn "clean") '())
          (check-equal? (artifact-files (map string->symbol withdrawn-targets) (.get withdrawn library) #f) '())
          (def refused (state "refused" " +memory"))
          (rewrite (path-expand "modules/review/objects.ss" (.get refused source))
                   "config: (.o (:: @ (.get scope config)) review: #t)"
                   "profile: (.o accepted?: #t feature-ids: '(ai-agentic-context/core))")
          (check-equal? (and (string-contains (action refused '("gxi" "refuse.ss"))
                                              "LAB-CONTEXT-REFUSAL-OK owner=ai-agentic-context feature=memory") #t) #t)
          (check-equal? (product-digests enabled-targets (.get enabled library)) enabled-products)
          (displayln "LAB-CONTEXT-MEMORY-DOWNSTREAM-OK base=" (length base-targets)
                     " enabled=" (length enabled-targets) " exclusive=" (length added)
                     " withdrawn=" (length withdrawn-targets) " hot=0 clean-isolation=ok scopes-during-build=0"))))))
