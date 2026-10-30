;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: generic module extension tests keep POO resolution semantics out
;;; of feature-specific workflow code.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :yuanxu/graph/interface
        :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/sandbox-core/shared-object
        :agentic-ai-lab/modules/nono-sandbox/objects
        :agentic-ai-lab/modules/cubeSandbox/objects)

(export module-extension-test)

;; : (-> YuanxuGraph Symbol MaybeAny)
(def (slot-value node slot-name)
  (let (entry (assoc slot-name (yuanxu-graph-root-payload node)))
    (if entry (cdr entry) #f)))

;;; This suite locks extension composition behavior for user-authored modules
;;; without introducing a second module-system surface.
;; : TestSuite
(def module-extension-resolution-test
  (test-suite "agentic-ai-lab module extension resolution"
    (yuanxu-test-case "applies slot and child-node operations to a stable object graph"
      (let* ((build-node
              (yuanxu-graph-rooted
               'workflow/pipeline/default/task/build
               '((run . "gxi build.ss")
                 (env . (DEBUG CI))
                 (artifacts . ()))
               '()))
             (legacy-node
              (yuanxu-graph-rooted
               'workflow/pipeline/default/task/legacy
               '((run . "echo legacy"))
               '()))
             (root-node
              (yuanxu-graph-rooted
               'workflow/pipeline/default
               '((needs . (test)))
               (list build-node legacy-node)))
             (package-node
              (yuanxu-graph-rooted
               'workflow/pipeline/default/task/package
               '((run . "tar dist"))
               '()))
             (root-contribution
              (yuanxu-graph-contribution
               'workflow/pipeline/default
               (list
                (yuanxu-graph-slot-prepend 'needs '(setup))
                (yuanxu-graph-slot-append 'needs '(lint test))
                (yuanxu-graph-node-remove
                 'workflow/pipeline/default/task/legacy)
                (yuanxu-graph-node-extend package-node))))
             (build-contribution
              (yuanxu-graph-contribution
               'workflow/pipeline/default/task/build
               (list
                (yuanxu-graph-slot-override
                 'run
                 "gxi build.ss --optimized")
                (yuanxu-graph-slot-remove 'env '(DEBUG))
                (yuanxu-graph-slot-append 'artifacts '("dist")))))
             (result
              (yuanxu-graph-resolve
               root-node
               (list root-contribution build-contribution)))
             (resolved-root
              (yuanxu-graph-result-root result))
             (resolved-build
              (yuanxu-graph-root-ref
               (yuanxu-graph-root-children resolved-root)
               'workflow/pipeline/default/task/build))
             (resolved-package
              (yuanxu-graph-root-ref
               (yuanxu-graph-root-children resolved-root)
               'workflow/pipeline/default/task/package))
             (removed-legacy
              (yuanxu-graph-root-ref
               (yuanxu-graph-root-children resolved-root)
               'workflow/pipeline/default/task/legacy)))
        (check-equal? (yuanxu-graph-result? result) #t)
        (check-equal? (yuanxu-graph-result-applied? result) #t)
        (check-equal? (yuanxu-graph-result-changed-passes result) 1)
        (check-equal? (slot-value resolved-root 'needs) '(setup test lint))
        (check-equal? removed-legacy #f)
        (check-equal? (yuanxu-graph? resolved-package) #t)
        (check-equal? (slot-value resolved-build 'run)
                      "gxi build.ss --optimized")
        (check-equal? (slot-value resolved-build 'env) '(CI))
        (check-equal? (slot-value resolved-build 'artifacts) '("dist"))))

    (yuanxu-test-case "merges module config contributions through POO field contracts"
      (let* ((needs-field
              (yuanxu-module-field-contract
               'needs YuanxuModuleListType 'append '() '((domain . workflow))))
             (features-field
              (yuanxu-module-field-contract
               'features YuanxuModuleListType 'prepend '() '((domain . workflow))))
             (run-field
              (yuanxu-module-field-contract
               'run YuanxuModuleStringType 'override #f '((domain . workflow))))
             (root-node
              (yuanxu-graph-rooted
               'workflow/pipeline/default
               '((needs . (test))
                 (features . (ci)))
               '()))
             (result
              (yuanxu-module-field-contributions-resolve
               root-node
               (list
                (yuanxu-module-field-contribution
                 'workflow/pipeline/default needs-field '(lint test))
                (yuanxu-module-field-contribution
                 'workflow/pipeline/default features-field '(sandbox))
                (yuanxu-module-field-contribution
                 'workflow/pipeline/default run-field "gxi build.ss")
                (yuanxu-module-field-contribution
                 'workflow/pipeline/default run-field
                 "gxi build.ss --optimized"))))
             (resolved-root
              (yuanxu-module-field-resolution-result-root result)))
        (check-equal? (yuanxu-module-field-contract? needs-field) #t)
        (check-equal? (yuanxu-module-field-contract-accepts?
                       needs-field '(lint))
                      #t)
        (check-equal? (yuanxu-module-field-contract-accepts?
                       needs-field 'lint)
                      #f)
        (check-equal? (yuanxu-module-field-resolution-result? result) #t)
        (check-equal? (yuanxu-module-field-resolution-result-applied? result) #t)
        (check-equal? (yuanxu-module-field-resolution-result-changed-passes result) 1)
        (check-equal? (slot-value resolved-root 'needs) '(test lint))
        (check-equal? (slot-value resolved-root 'features) '(sandbox ci))
        (check-equal? (slot-value resolved-root 'run)
                      "gxi build.ss --optimized")))))

;;; This suite keeps object inheritance and C4 precedence separate from the
;;; slot-level resolution tests above.
;; : TestSuite
(def module-extension-object-inheritance-test
  (test-suite "agentic-ai-lab module object inheritance"
    (yuanxu-test-case "inherits shared sandbox module objects for nono and cube"
      (let* ((shared-sandbox-object
              (yuanxu-module-object
               'sandbox/shared
               '()
               (list
                (yuanxu-module-field-contract
                 'backend YuanxuModuleSymbolType 'override 'sandbox '())
                (yuanxu-module-field-contract
                 'flags YuanxuModuleListType 'append '() '())
                (yuanxu-module-field-contract
                 'runtime-args YuanxuModuleListType 'append '() '()))
               '((domain . sandbox))))
             (nono-sandbox-object
              (yuanxu-module-object
               'sandbox/nono
               (list shared-sandbox-object)
               (list
                (yuanxu-module-field-contract
                 'backend YuanxuModuleSymbolType 'override 'nono '())
                (yuanxu-module-field-contract
                 'binding YuanxuModuleSymbolType 'override 'none '()))
               '((backend . nono))))
             (cube-sandbox-object
              (yuanxu-module-object
               'sandbox/cube
               (list shared-sandbox-object)
               (list
                (yuanxu-module-field-contract
                 'backend YuanxuModuleSymbolType 'override 'cube '())
                (yuanxu-module-field-contract
                 'profile YuanxuModuleSymbolType 'override 'default '()))
               '((backend . cube))))
             (root-node
              (yuanxu-graph-rooted
               'sandbox/shared
               '()
               (list
                (yuanxu-module-object-node nono-sandbox-object '() '())
                (yuanxu-module-object-node cube-sandbox-object '() '()))))
             (result
              (yuanxu-module-field-contributions-resolve
               root-node
               (append
                (yuanxu-module-object-contributions
                 nono-sandbox-object
                 '((flags . (doctor nono))
                   (runtime-args . ("--trace-nono"))
                   (binding . c)))
                (yuanxu-module-object-contributions
                 cube-sandbox-object
                 '((flags . (doctor cube))
                   (runtime-args . ("--trace-cube"))
                   (profile . strict))))))
             (resolved-root
              (yuanxu-module-field-resolution-result-root result))
             (resolved-nono
              (yuanxu-graph-root-ref
               (yuanxu-graph-root-children resolved-root)
               'sandbox/nono))
             (resolved-cube
              (yuanxu-graph-root-ref
               (yuanxu-graph-root-children resolved-root)
               'sandbox/cube)))
        (check-equal? (yuanxu-module-object? shared-sandbox-object) #t)
        (check-equal? (map yuanxu-module-field-contract-identity
                           (yuanxu-module-object-resolved-fields
                            nono-sandbox-object))
                      '(backend flags runtime-args binding))
        (check-equal? (slot-value resolved-nono 'backend) 'nono)
        (check-equal? (slot-value resolved-nono 'flags) '(doctor nono))
        (check-equal? (slot-value resolved-nono 'runtime-args)
                      '("--trace-nono"))
        (check-equal? (slot-value resolved-nono 'binding) 'c)
        (check-equal? (slot-value resolved-cube 'backend) 'cube)
        (check-equal? (slot-value resolved-cube 'flags) '(doctor cube))
        (check-equal? (slot-value resolved-cube 'runtime-args)
                      '("--trace-cube"))
        (check-equal? (slot-value resolved-cube 'profile) 'strict)))

    (yuanxu-test-case "resolves module object fields through gerbil-poo C4 precedence"
      (let* ((root-object
              (yuanxu-module-object
               'object/root
               '()
               (list
                (yuanxu-module-field-contract
                 'shared YuanxuModuleSymbolType 'override 'root '())
                (yuanxu-module-field-contract
                 'root-only YuanxuModuleSymbolType 'override 'root-only '()))
               '()))
             (right-object
              (yuanxu-module-object
               'object/right
               (list root-object)
               (list
                (yuanxu-module-field-contract
                 'shared YuanxuModuleSymbolType 'override 'right '())
                (yuanxu-module-field-contract
                 'right-only YuanxuModuleSymbolType 'override 'right-only '()))
               '()))
             (left-object
              (yuanxu-module-object
               'object/left
               (list root-object)
               (list
                (yuanxu-module-field-contract
                 'shared YuanxuModuleSymbolType 'override 'left '())
                (yuanxu-module-field-contract
                 'left-only YuanxuModuleSymbolType 'override 'left-only '()))
               '()))
             (child-object
              (yuanxu-module-object
               'object/child
               (list left-object right-object)
               (list
                (yuanxu-module-field-contract
                 'child-only YuanxuModuleSymbolType 'override 'child-only '()))
               '())))
        (check-equal? (map yuanxu-module-field-contract-identity
                           (yuanxu-module-object-fields child-object))
                      '(child-only))
        (check-equal? (map yuanxu-module-field-contract-identity
                           (yuanxu-module-object-resolved-fields
                            child-object))
                      '(shared root-only right-only left-only child-only))
        (check-equal? (yuanxu-module-field-contract-default
                       (yuanxu-module-object-field child-object 'shared))
                      'left)
        (check-equal? (yuanxu-module-field-contract-default
                       (yuanxu-module-object-field child-object 'right-only))
                      'right-only)
        (check-equal? (yuanxu-module-field-contract-default
                       (yuanxu-module-object-field child-object 'root-only))
                      'root-only)))))

;;; This suite keeps inconsistent graph handling and real object namespace
;;; merging apart from the inheritance examples.
;; : TestSuite
(def module-extension-object-merge-test
  (test-suite "agentic-ai-lab module object merge"
    (yuanxu-test-case "rejects inconsistent gerbil-poo C4 module object graphs"
      (let* ((root-object
              (yuanxu-module-object
               'object/root
               '()
               (list
                (yuanxu-module-field-contract
                 'shared YuanxuModuleSymbolType 'override 'root '()))
               '()))
             (a-object
              (yuanxu-module-object
               'object/a
               (list root-object)
               '()
               '()))
             (b-object
              (yuanxu-module-object
               'object/b
               (list root-object)
               '()
               '()))
             (x-object
              (yuanxu-module-object
               'object/x
               (list a-object b-object)
               '()
               '()))
             (y-object
              (yuanxu-module-object
               'object/y
               (list b-object a-object)
               '()
               '()))
             (broken-object
              (yuanxu-module-object
               'object/broken
               (list x-object y-object)
               '()
               '()))
             (failure
              (with-catch (lambda (failure) failure)
                          (lambda ()
                            (yuanxu-module-object-resolved-fields
                             broken-object)))))
        (check-equal? (not (not failure)) #t)))

    (yuanxu-test-case "merges real module objects under the objects namespace"
      (let* ((objects
              (append agentic-ai-lab-shared-module-objects
                      agentic-ai-lab-nono-sandbox-module-objects
                      agentic-ai-lab-cubeSandbox-module-objects))
             (result
              (yuanxu-module-objects-resolve-contributions
               objects
               (append
                (yuanxu-module-object-contributions
                 agentic-ai-lab-nono-sandbox-object
                 '((flags . (doctor nono))
                   (runtime-args . ("--trace-nono"))
                   (binding . c)))
                (yuanxu-module-object-contributions
                 agentic-ai-lab-cubeSandbox-object
                 '((flags . (doctor cube))
                   (runtime-args . ("--trace-cube"))
                   (profile . strict))))))
             (resolved-objects
              (yuanxu-module-field-resolution-result-root result))
             (resolved-shared
              (yuanxu-module-objects-ref
               resolved-objects
               'objects.shared.sandbox))
             (resolved-nono
              (yuanxu-module-objects-ref
               resolved-objects
               'objects.nono-sandbox.sandbox))
             (resolved-cube
              (yuanxu-module-objects-ref
               resolved-objects
               'objects.cubeSandbox.sandbox)))
        (check-equal? (yuanxu-graph-root-id
                       resolved-objects)
                      'objects)
        (check-equal? (slot-value resolved-objects 'namespace) 'objects)
        (check-equal? (slot-value resolved-shared 'backend) 'sandbox)
        (check-equal? (slot-value resolved-nono 'backend) 'nono)
        (check-equal? (slot-value resolved-nono 'flags) '(doctor nono))
        (check-equal? (slot-value resolved-nono 'binding) 'c)
        (check-equal? (slot-value resolved-cube 'backend) 'cube)
        (check-equal? (slot-value resolved-cube 'flags) '(doctor cube))
        (check-equal? (slot-value resolved-cube 'profile) 'strict)))))

;;; Aggregate export preserves the historical module-extension-test symbol while
;;; the parser sees smaller suite owners.
;; : TestSuite
(def module-extension-test
  (test-suite "agentic-ai-lab module extension"
    module-extension-resolution-test
    module-extension-object-inheritance-test
    module-extension-object-merge-test))
