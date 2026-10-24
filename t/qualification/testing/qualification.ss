;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product source projection over Core TestingScript and source Fixtures.
(import :clan/poo/object
        (only-in :std/source this-source-file)
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :yuanxu/observability/testing-script TestingScript.)
        (only-in :yuanxu/module-system/source/admission
                 module-source-read module-source-admit-current!))
(export qualification-source qualification-script)

(def implementation (this-source-file))
(def (qualification-source files inputs)
  (def paths (delete-duplicates/hash (cons implementation (append files inputs)) from-end?: #t))
  (def observations
    (map (lambda (path) (cons path (module-source-read path))) paths))
  (.o spec: files source-root: (current-directory)
      admit-current: (lambda () (module-source-admit-current! observations))))

(def (qualification-script files command seconds
       inputs: (inputs '()) case-count: (count #f)
       harness: (harness #f) required-lines: (required '()))
  (.cc TestingScript.
    'source (qualification-source files inputs)
    'command command 'case-count count 'harness harness 'required-lines required
    ;; These gates had total caps; watched commands retain their original
    ;; five-second byte-progress watchdog. Do not add a new idle cutoff.
    'idle-timeout #f
    'profile (.cc (.get TestingScript. profile)
                 'max-duration-milliseconds (* 1000 seconds))))
