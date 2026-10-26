;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Real catalog/journal replay without Sessions, Tasks or dummy observations.
(import
 (only-in :clan/poo/object .o .ref)
 :agentic-ai-lab/modules/ai-agentic-context/query-provider
 :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal)
(export context-query-catalog-driver)

(def (ensure value message)
  (unless value (error message)))

(def (rejected? operation)
  (with-catch (lambda (e) #t) (lambda () (operation) #f)))

(def (original-source)
  (call-with-input-file
      "modules/ai-agentic-context/org-contract/templates/evidence-source.org"
    (lambda (port) (read-line port #f))))

;;; The journal owns commit, bytes and writer epoch. This test deliberately
;;; drives it directly; it does not claim automatic durable-owner integration.
(def (save-root! journal id key root)
  (journal-receive! journal id root)
  (journal-begin! journal id)
  (journal-put! journal key root)
  (journal-commit! journal))

(def (prepare! journal)
  (let* ((host (context-query-host))
         (src (context-query-source! host (context-org-source "catalog-source" 1 (original-source))))
         (root (context-query-export host)))
    (ensure (null? (.ref root 'queries)) "Export created a dummy Query")
    (ensure (not (.ref root 'observation-ref)) "Export created an observation ref")
    (save-root! journal "unqueried-source" "unqueried" root)
    ;; Keep a wholly empty catalog too: no source or consumer is a valid root.
    (save-root! journal "empty-catalog" "empty" (context-query-export (context-query-host)))
    (displayln "CATALOG-PREPARED source-generation=" (.ref src 'generation)
               " queries=0 sessions=0 epoch=" (journal-epoch journal))))

(def (restore-catalog root)
  (let-values (((host observed) (context-query-restore root)))
    (ensure (not observed) "Root restoration fabricated an observation")
    host))

(def (replay! journal)
  (let* ((root (journal-get journal "unqueried"))
         (host (restore-catalog root))
         (src (context-query-current-source host "catalog-source"))
         (observed (context-query-execute host "catalog-source" (context-org-query src "work"))))
    (ensure (= (.ref src 'generation) 1) "Unqueried source generation was lost")
    (ensure (equal? (.ref src 'source) (original-source)) "Original Org bytes changed")
    (ensure (context-query-current? host observed) "First real Query lacks native support")
    (restore-catalog (journal-get journal "empty"))
    (ensure
     (rejected? (lambda ()
       (context-query-restore (.o (:: @ root) observation-ref: "missing-observation"))))
     "Missing observation ref was accepted")

    ;; Equal empty Query journals with different source heads must not alias.
    (let ((other (context-query-host)))
      (context-query-source! other (context-org-source "catalog-source" 2 (original-source)))
      (ensure (rejected? (lambda () (context-query-restore root other)))
              "Same empty Query journal concealed a different source head")
      (ensure (= (.ref (context-query-current-source other "catalog-source") 'generation) 2)
              "Rejected restoration mutated the shared catalog"))

    ;; Retain an old real proof, retract its source, then re-admit the same IDs
    ;; and bytes at a new generation. Old support must remain withdrawn.
    (context-query-withdraw! host "catalog-source" 2)
    (let (src3 (context-query-source! host (context-org-source "catalog-source" 3 (original-source))))
      (let (fresh-value (context-query-execute host "catalog-source" (context-org-query src3 "work")))
        (ensure (not (context-query-current? host observed)) "Re-admission revived old proof")
        (ensure (context-query-current? host fresh-value) "Fresh native proof is not current")
        (save-root! journal "withdraw-readmit" "latest" (context-query-export host))
        (journal-receive! journal "retained-observations" (.o old: observed fresh: fresh-value))
        (journal-begin! journal "retained-observations")
        (journal-put! journal "observations" (.o old: observed fresh: fresh-value))
        (journal-commit! journal)))
    (displayln "CATALOG-REPLAY original-bytes=#t empty-root=#t native-proof=#t"
               " same-query-different-head-refused=#t old-current=#f fresh-current=#t")))

(def (verify! journal)
  (let* ((host (restore-catalog (journal-get journal "latest")))
         (observations (journal-get journal "observations")))
    (ensure (= (.ref (context-query-current-source host "catalog-source") 'generation) 3)
            "Latest source head rolled back")
    (ensure (not (context-query-current? host (.ref observations 'old)))
            "Old proof revived in another process")
    (ensure (context-query-current? host (.ref observations 'fresh))
            "Fresh proof did not survive journal replay")
    (ensure (= (length (.ref (context-query-export host) 'queries)) 2)
            "Canonical Query journal lost an original observation")
    (ensure (rejected? (lambda ()
      (context-query-restore (journal-get journal "unqueried") host)))
      "Delayed old capsule rewound a shared catalog")
    (displayln "CATALOG-VERIFIED source-generation=3 original-queries=2"
               " old-current=#f fresh-current=#t stale-root-refused=#t")))

(def (context-query-catalog-driver path mode)
  (let (journal (journal-open path))
    (cond
     ((equal? mode "prepare") (prepare! journal))
     ((equal? mode "replay") (replay! journal))
     ((equal? mode "verify") (verify! journal))
     (else (error "Unknown catalog scenario" mode)))
    (ensure (journal-verify! journal) "Durable decision chain verification failed")
    (journal-close! journal))
  (displayln "MODULE-OK t/context-query-catalog-test.ss")
  (displayln "HARNESS-OK context-query-catalog")
  (displayln "OK"))
