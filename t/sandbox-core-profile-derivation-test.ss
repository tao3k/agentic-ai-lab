;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox-core profile derivation follows native POO extension.
;;; Invariant: derived profiles are inert recipes; no backend runtime executes.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :agentic-ai-lab/modules/agent-sandbox/config
        :agentic-ai-lab/modules/nono-sandbox/config
        :agentic-ai-lab/modules/nono-sandbox/objects
        :agentic-ai-lab/modules/sandbox-core/profile)

;;; Fixture alist reads stay local to the derivation receipt assertions so the
;;; test does not depend on profile projection internals for metadata lookup.
;; | DerivationMetadata = Alist
;; | DerivationMetadataKey = Symbol
;; : (-> DerivationMetadata DerivationMetadataKey Value Value)
(def (derivation-test-alist-ref entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;;; Lineage order is the behavior under test: the final step must describe the
;;; task derivation, not an intermediate project/session parent.
;; | DerivationLineage = (cons Alist [Alist])
;; : (-> DerivationLineage Alist)
(def (derivation-test-last values)
  (if (null? (cdr values))
    (car values)
    (derivation-test-last (cdr values))))

;;; Negative cases assert that malformed rows fail before backend realization;
;;; the helper keeps the suite focused on the validation boundary.
;; | DerivationValidationThunk = (-> Unit Value)
;; : (-> DerivationValidationThunk Boolean)
(def (derivation-test-error? thunk)
  (with-catch (lambda (_failure) #t)
              (lambda ()
                (thunk)
                #f)))

(export sandbox-core-profile-derivation-test)

(def sandbox-core-profile-derivation-test
 (test-suite "sandbox-core profile derivation"
   (yuanxu-test-case "derives session and task profiles through POO extensions"
     (let* ((project-profile
             (agentic-ai-lab-nono-sandbox-profile-config
              'project/dev
              '((capabilities :append filesystem-read)
                (metadata (project . marlin)))))
            (session-profile
             (agentic-ai-lab-sandbox-profile-object-derive
              agentic-ai-lab-nono-sandbox-profile-object
              project-profile
              'session/dev
              '((capabilities :append filesystem-write)
                (metadata (session . "s-1")))
              '((scope . session) (scope-ref . "s-1"))))
            (task-profile
             (agentic-ai-lab-sandbox-profile-object-derive
              agentic-ai-lab-nono-sandbox-profile-object
              session-profile
              'task/build
              '((capabilities :append process-run)
                (capabilities :remove filesystem-read)
                (metadata (task . build)))
              '((scope . task) (scope-ref . build))))
            (metadata (agentic-ai-lab-sandbox-profile-metadata task-profile))
            (lineage
             (derivation-test-alist-ref metadata 'derivation-path '()))
            (last-step (derivation-test-last lineage)))
       (check-equal? (agentic-ai-lab-sandbox-profile-name task-profile)
                     'task/build)
       (check-equal? (agentic-ai-lab-sandbox-profile-backend-kind task-profile)
                     'nono)
       (check-equal? (agentic-ai-lab-sandbox-profile-backend-ref task-profile)
                     'task/build)
       (check-equal? (agentic-ai-lab-sandbox-profile-capabilities task-profile)
                     '(process filesystem tmpdir filesystem-write process-run))
       (check-equal? (length lineage) 2)
       (check-equal? (derivation-test-alist-ref last-step
                                                'parent-profile
                                                #f)
                     'session/dev)
       (check-equal? (derivation-test-alist-ref last-step 'scope #f)
                     'task)
       (check-equal? (derivation-test-alist-ref last-step 'scope-ref #f)
                     'build)
       (check-equal? (derivation-test-alist-ref metadata 'runtime-executed #t)
                     #f)))
   (yuanxu-test-case "rejects backend rows during derivation"
     (let (project-profile
           (agentic-ai-lab-nono-sandbox-profile-config
            'project/dev
            '((metadata (project . marlin)))))
       (check-equal?
        (derivation-test-error?
         (lambda ()
           (agentic-ai-lab-sandbox-profile-object-derive
            agentic-ai-lab-nono-sandbox-profile-object
            project-profile
            'session/bad
            '((backend docker)))))
        #t)))
   (yuanxu-test-case "rejects non-symbol names before profile resolution"
     (let (project-profile
           (agentic-ai-lab-nono-sandbox-profile-config
            'project/dev
            '((metadata (project . marlin)))))
       (check-equal?
        (derivation-test-error?
         (lambda ()
           (agentic-ai-lab-sandbox-profile-object-derive
            agentic-ai-lab-nono-sandbox-profile-object
            project-profile
            "session/bad"
            '((metadata (session . bad))))))
        #t)
       (check-equal?
        (derivation-test-error?
         (lambda ()
           (agentic-ai-lab-nono-sandbox-profile-config
            "project/bad"
            '((metadata (project . bad))))))
        #t)))
   (yuanxu-test-case "rejects non-profile parents during derivation"
     (check-equal?
      (derivation-test-error?
       (lambda ()
         (agentic-ai-lab-sandbox-profile-object-derive
          agentic-ai-lab-nono-sandbox-profile-object
          'not-a-profile
          'session/bad-parent
          '((metadata (session . bad-parent))))))
      #t))
   (yuanxu-test-case "rejects unknown rows through POO field validation"
     (let (project-profile
           (agentic-ai-lab-nono-sandbox-profile-config
            'project/dev
            '((metadata (project . marlin)))))
       (check-equal?
        (derivation-test-error?
         (lambda ()
           (agentic-ai-lab-sandbox-profile-object-derive
            agentic-ai-lab-nono-sandbox-profile-object
            project-profile
            'session/unknown-row
            '((unknown-row value)))))
        #t)))
   (yuanxu-test-case "rejects unsafe filesystem resources before runtime handoff"
     (let (project-profile
           (agentic-ai-lab-nono-sandbox-profile-config
            'project/dev
            '((metadata (project . marlin)))))
       (check-equal?
        (derivation-test-error?
         (lambda ()
           (agentic-ai-lab-sandbox-profile-object-derive
            agentic-ai-lab-nono-sandbox-profile-object
            project-profile
            'session/unsafe-filesystem
            '((resources filesystem)))))
        #t)))))
