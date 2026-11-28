;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: reusable POO composition performance scenarios and gates.

(import (only-in :clan/poo/object .o .ref)
        (only-in "../support/poo-performance-fixtures"
                 poo-performance-composition-lazy-demand-fixture)
        "./composition-gates"
        "./composition-large-library")

(export poo-performance-composition-profile-declaration-valid-count
        poo-performance-composition-profile-declaration-gate-receipt
        poo-performance-composition-profiles-bulk-valid-count
        poo-performance-composition-profiles-bulk-gate-receipt
        poo-performance-composition-local-override-valid-count
        poo-performance-composition-local-override-gate-receipt
        poo-performance-composition-hook-override-valid-count
        poo-performance-composition-hook-override-gate-receipt
        poo-performance-composition-poo-object-reuse-valid-count
        poo-performance-composition-poo-object-reuse-gate-receipt
        poo-performance-composition-poo-object-reuse-large-library-valid-count
        poo-performance-composition-poo-object-reuse-large-library-gate-receipt
        poo-performance-composition-lazy-demand-valid-count
        poo-performance-composition-lazy-demand-gate-receipt
        poo-performance-poo-object-list-indexed-family-valid-count
        poo-performance-poo-object-list-indexed-family-gate-receipt
        poo-performance-composition-macro-style-matrix-valid-count
        poo-performance-composition-macro-style-matrix-gate-receipt
        poo-performance-composition-construction-count
        poo-performance-composition-reset-construction-count!)

;; : Integer
(def poo-performance-composition-construction-count-value 0)

;; : (-> Unit)
(def (poo-performance-composition-note-construction!)
  (set! poo-performance-composition-construction-count-value
        (+ poo-performance-composition-construction-count-value 1)))

;; : (-> Integer)
(def (poo-performance-composition-construction-count)
  poo-performance-composition-construction-count-value)

;; : (-> Unit)
(def (poo-performance-composition-reset-construction-count!)
  (set! poo-performance-composition-construction-count-value 0))

;; : PooObject
(def poo-performance-composition-library
  (.o (agent (.o (name 'agent) (scope '(session))))
      (task (.o (name 'task) (scope '(workflow))))
      (memory (.o (name 'memory)
                  (scope '(session workflow))
                  (analysis '(checksum))
                  (retention '(checkpoint-linked))))
      (guardrail (.o (name 'guardrail) (scope '(workflow))))
      (runtime-handoff (.o (name 'runtime-handoff) (scope '(runtime))))))

;; : PooObject
(def poo-performance-runtime-enterprise-profile
  (.o (name 'enterprise-report)
      (scope '(session publish-channel))
      (publish '(human-approved legal-review proof-gated))
      (retention '(seven-years audit-log))))

;; : (-> PooObject PooObject)
(def (poo-performance-audit-retention-hook profile)
  (.o (:extends profile)
      (name (.ref profile 'name))
      (analysis '(checksum provenance citation-trace))
      (retention '(project-retained audit-log))))

;; : (-> PooObject)
(def (poo-performance-composition-macro-style-source)
  (poo-performance-composition-note-construction!)
  (let* ((memory-profile (.ref poo-performance-composition-library 'memory))
         (local-audited-memory
          (.o (:extends memory-profile)
              (name 'local-audited-memory)
              (retention '(project-retained audit-log))))
         (hook-audited-memory
          (poo-performance-audit-retention-hook memory-profile))
         (enterprise-report
          (.o (:extends poo-performance-runtime-enterprise-profile)
              (name 'enterprise-report)
              (analysis '(checksum provenance citation-trace)))))
    (.o (name 'macro-style-performance)
        (modules
         (list (.o (name 'macro-style)
                   (value poo-performance-composition-library))))
        (stages
         (list
          (.o (name 'production)
              (clauses
               (list
                (.o (name 'compose)
                    (payload
                     (list
                      (.o (name 'declared-agent)
                          (scope '(session)))
                      (.o (name 'declared-task)
                          (scope '(workflow)))
                      (.o (name 'declared-memory)
                          (scope '(session workflow))
                          (analysis '(checksum))
                          (retention '(checkpoint-linked)))
                      (.ref poo-performance-composition-library 'agent)
                      (.ref poo-performance-composition-library 'task)
                      memory-profile
                      (.ref poo-performance-composition-library 'guardrail)
                      (.ref poo-performance-composition-library 'runtime-handoff)
                      local-audited-memory
                      hook-audited-memory
                      enterprise-report)))
                (.o (name 'prove)
                    (payload
                     '(declared-profile-object
                       grouped-profile-import
                       local-override-runtime-poo
                       hook-override-runtime-poo
	                       poo-object-reused-directly)))))))))))

;; : (-> PooObject)
(def (poo-performance-composition-profile-declaration)
  (poo-performance-composition-macro-style-source))

;; : (-> PooObject)
(def (poo-performance-composition-profiles-bulk)
  (poo-performance-composition-macro-style-source))

;; : (-> PooObject)
(def (poo-performance-composition-local-override)
  (poo-performance-composition-macro-style-source))

;; : (-> PooObject)
(def (poo-performance-composition-hook-override)
  (poo-performance-composition-macro-style-source))

;; : (-> PooObject)
(def (poo-performance-composition-poo-object-reuse)
  (poo-performance-composition-macro-style-source))

;; : (-> PooObject)
(def (poo-performance-composition-poo-object-reuse-large-library)
  (poo-performance-composition-note-construction!)
  (poo-performance-large-runtime-profile-composition))

;; : (-> PooObject)
(def (poo-performance-poo-object-list-indexed-family)
  (poo-performance-composition-note-construction!)
  (poo-performance-large-runtime-profile-composition))

;; poo-performance-composition-valid-count
;;   : (-> PooObject Integer Integer)
;;   | doc m%
;;       Validates that one composed profile payload is non-empty once, then
;;       keeps benchmark rounds scalar.
;;
;;       # Examples
;;       ```scheme
;;       (poo-performance-composition-valid-count
;;        (poo-performance-composition-profile-declaration)
;;        1)
;;       ;; => 1
;;       ```
;;     %
(def (poo-performance-composition-valid-count composition rounds)
  (let* ((stage (car (.ref composition 'stages)))
         (clause (car (.ref stage 'clauses)))
         (payload (.ref clause 'payload))
         (payload-count (length payload)))
    (* rounds (if (> payload-count 0) 1 0))))

;; : (-> Integer Integer)
(def (poo-performance-composition-profile-declaration-valid-count rounds)
  (poo-performance-composition-valid-count
   (poo-performance-composition-profile-declaration)
   rounds))

;; : (-> Integer Alist)
(def (poo-performance-composition-profile-declaration-gate-receipt rounds)
  (let (composition (poo-performance-composition-profile-declaration))
    (poo-performance-family-run-gate
     +poo-performance-benchmark-receipt-family+
     (poo-performance-composition-profile-declaration-fixture)
     (lambda () (poo-performance-composition-valid-count composition rounds)))))

;; : (-> Integer Integer)
(def (poo-performance-composition-profiles-bulk-valid-count rounds)
  (poo-performance-composition-valid-count
   (poo-performance-composition-profiles-bulk)
   rounds))

;; : (-> Integer Alist)
(def (poo-performance-composition-profiles-bulk-gate-receipt rounds)
  (let (composition (poo-performance-composition-profiles-bulk))
    (poo-performance-family-run-gate
     +poo-performance-benchmark-receipt-family+
     (poo-performance-composition-profiles-bulk-fixture)
     (lambda () (poo-performance-composition-valid-count composition rounds)))))

;; : (-> Integer Integer)
(def (poo-performance-composition-local-override-valid-count rounds)
  (poo-performance-composition-valid-count
   (poo-performance-composition-local-override)
   rounds))

;; : (-> Integer Alist)
(def (poo-performance-composition-local-override-gate-receipt rounds)
  (let (composition (poo-performance-composition-local-override))
    (poo-performance-family-run-gate
     +poo-performance-benchmark-receipt-family+
     (poo-performance-composition-local-override-fixture)
     (lambda () (poo-performance-composition-valid-count composition rounds)))))

;; : (-> Integer Integer)
(def (poo-performance-composition-hook-override-valid-count rounds)
  (poo-performance-composition-valid-count
   (poo-performance-composition-hook-override)
   rounds))

;; : (-> Integer Alist)
(def (poo-performance-composition-hook-override-gate-receipt rounds)
  (let (composition (poo-performance-composition-hook-override))
    (poo-performance-family-run-gate
     +poo-performance-benchmark-receipt-family+
     (poo-performance-composition-hook-override-fixture)
     (lambda () (poo-performance-composition-valid-count composition rounds)))))

;; : (-> Integer Integer)
(def (poo-performance-composition-poo-object-reuse-valid-count rounds)
  (poo-performance-composition-valid-count
   (poo-performance-composition-poo-object-reuse)
   rounds))

;; : (-> Integer Alist)
(def (poo-performance-composition-poo-object-reuse-gate-receipt rounds)
  (let (composition (poo-performance-composition-poo-object-reuse))
    (poo-performance-family-run-gate
     +poo-performance-benchmark-receipt-family+
     (poo-performance-composition-poo-object-reuse-fixture)
     (lambda () (poo-performance-composition-valid-count composition rounds)))))

;; : (-> PooObject Integer Integer)
(def (poo-performance-composition-macro-style-matrix-valid-count*
      composition
      rounds)
  (poo-performance-composition-valid-count composition rounds))

;; : (-> Integer Integer)
(def (poo-performance-composition-macro-style-matrix-valid-count rounds)
  (poo-performance-composition-macro-style-matrix-valid-count*
   (poo-performance-composition-macro-style-source)
   rounds))

;; : (-> Integer Alist)
(def (poo-performance-composition-macro-style-matrix-gate-receipt rounds)
  (let (composition (poo-performance-composition-macro-style-source))
    (poo-performance-family-run-gate
     +poo-performance-benchmark-receipt-family+
     (poo-performance-composition-macro-style-matrix-fixture)
     (lambda ()
       (poo-performance-composition-macro-style-matrix-valid-count*
        composition
        rounds)))))

;; : (-> PooObject Integer Integer)
(def (poo-performance-composition-poo-object-reuse-large-library-valid-count*
      composition
      rounds)
  (poo-performance-large-runtime-profile-valid-count* composition rounds))

;; : (-> Integer Integer)
(def (poo-performance-composition-poo-object-reuse-large-library-valid-count
      rounds)
  (poo-performance-composition-poo-object-reuse-large-library-valid-count*
   (poo-performance-composition-poo-object-reuse-large-library)
   rounds))

;; : (-> Integer Alist)
(def (poo-performance-composition-poo-object-reuse-large-library-gate-receipt
      rounds)
  (let (composition
        (poo-performance-composition-poo-object-reuse-large-library))
    (poo-performance-family-run-gate
     +poo-performance-benchmark-receipt-family+
     (poo-performance-composition-poo-object-reuse-large-library-fixture)
     (lambda ()
       (poo-performance-composition-poo-object-reuse-large-library-valid-count*
        composition
        rounds)))))

;; : (-> Integer Integer)
(def (poo-performance-composition-lazy-demand-valid-count rounds)
  (def evidence (poo-performance-composition-lazy-demand-evidence))
  (if (and (eq? (.ref evidence 'selected-route) 'triage-fast-path)
           (eq? (.ref evidence 'repeated-route) 'triage-fast-path)
           (eq? (.ref evidence 'shared-route) 'triage-fast-path)
           (eq? (.ref evidence 'selected-image) 'gerbil-runtime)
           (eq? (.ref evidence 'unused-route) 'cold-path)
           (.ref evidence 'shared-model?)
           (= (.ref evidence 'shared-model-route-force-count-before-full) 1)
           (= (.ref evidence 'shared-model-route-force-count-after-full) 1)
           (= (.ref evidence 'shared-sandbox-image-force-count-before-full) 1)
           (= (.ref evidence 'shared-sandbox-image-force-count-after-full) 1)
           (= (.ref evidence 'large-library-force-count) 0)
           (= (.ref evidence 'unused-route-force-count-before-full) 0)
           (= (.ref evidence 'unused-route-force-count-after-full) 1))
    rounds
    0))

(def (poo-performance-composition-lazy-demand-gate-receipt rounds)
  (poo-performance-family-run-gate
   +poo-performance-benchmark-receipt-family+
   (poo-performance-composition-lazy-demand-fixture)
   (lambda ()
     (poo-performance-composition-lazy-demand-valid-count rounds))))

;; : (-> Integer Integer)
(def (poo-performance-poo-object-list-indexed-family-valid-count rounds)
  (poo-performance-composition-poo-object-reuse-large-library-valid-count*
   (poo-performance-poo-object-list-indexed-family)
   rounds))

;; : (-> Integer Alist)
(def (poo-performance-poo-object-list-indexed-family-gate-receipt rounds)
  (let (composition
        (poo-performance-poo-object-list-indexed-family))
    (poo-performance-family-run-gate
     +poo-performance-benchmark-receipt-family+
     (poo-performance-poo-object-list-indexed-family-fixture)
     (lambda ()
       (poo-performance-composition-poo-object-reuse-large-library-valid-count*
        composition
        rounds)))))
