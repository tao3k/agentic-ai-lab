;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :clan/poo/object .ref .o)
        (only-in :agentic-ai-lab/testing-api yuanxu-test-case)
        :agentic-ai-lab/modules/temporal-causality/time/objects
        :agentic-ai-lab/modules/temporal-causality/revisions/interface
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/interface)
(export temporal-support-test)
(def (at n) (agentic-ai-lab-temporal-instant (number->string n) "txn" n "ledger" 'observed))
(def (valid n) (agentic-ai-lab-temporal-instant (number->string n) "valid" n "ledger" 'observed))
(def (validity) (agentic-ai-lab-temporal-interval "validity" (valid 0) (valid 10) #t #f))
(def (revision id subject op predecessor n)
  (agentic-ai-lab-temporal-evidence-revision id subject op predecessor (at n) (and (not (eq? op 'retract)) (validity))
                                     (and (not (eq? op 'retract)) id)))
(def history
  (agentic-ai-lab-temporal-evidence-journal "journal" "txn"
    (list (revision "a1" "a" 'assert #f 1) (revision "b1" "b" 'assert #f 1)
          (revision "a2" "a" 'retract "a1" 2) (revision "b2" "b" 'retract "b1" 3))))
(def (program complete?)
  (agentic-ai-lab-temporal-support-program "program" "policy" complete?
    (list (agentic-ai-lab-temporal-support "left" "claim" "proof-a"
            (list (agentic-ai-lab-temporal-support-premise "a" "a1")) '())
          (agentic-ai-lab-temporal-support "right" "claim" "proof-b"
            (list (agentic-ai-lab-temporal-support-premise "b" "b1")) '())
          (agentic-ai-lab-temporal-support "child" "downstream" "proof-child" '() '("claim")))))
(def (result p journal n budget)
  (agentic-ai-lab-temporal-support-evaluate p journal (at n) #f budget))
(def (claim r) (car (.ref r 'conclusions)))
(def temporal-support-test
  (test-suite "acyclic temporal support applicability"
    (yuanxu-test-case "named inventory preserves unsupported claims and scoped uncertainty"
      (let* ((complete (agentic-ai-lab-temporal-support-inventory "empty" "policy" #t '("unproved") '()))
             (partial (agentic-ai-lab-temporal-support-inventory "empty" "policy" #f '("unproved") '())))
        (check (.ref (claim (result complete history 1 128)) 'status) => 'unsupported)
        (check (.ref (claim (result partial history 1 128)) 'status) => 'unknown)
        (check-exception (agentic-ai-lab-temporal-support-inventory "bad" "policy" #t '("claim" "claim") '()) true)
        (check-exception (agentic-ai-lab-temporal-support-inventory "bad" "policy" #t '("foreign") (.ref (program #t) 'supports)) true)))
    (yuanxu-test-case "reverse claim projection groups alternatives and includes downstream claims"
      (let* ((p (program #t))
             (first (agentic-ai-lab-temporal-support-reverse-plan p history (at 1) (at 2) #f))
             (last (agentic-ai-lab-temporal-support-reverse-plan p history (at 2) (at 3) #f)))
        (check (.ref first 'changed-subject-identities) => '("a"))
        (check (.ref first 'affected-conclusion-identities) => '("claim" "downstream"))
        (check (.ref last 'changed-subject-identities) => '("b"))
        (check (.ref last 'affected-conclusion-identities) => '("claim" "downstream"))
        (check (.ref first 'inventory-complete?) => #t)
        (check (.ref (agentic-ai-lab-temporal-support-reverse-plan (program #f) history (at 1) (at 2) #f)
                    'status) => 'partial)))

    (yuanxu-test-case "two supports then one then none preserves historical cuts"
      (let* ((p (program #t)) (two (result p history 1 128))
             (one (result p history 2 128)) (none (result p history 3 128)))
        (check (.ref (claim two) 'active-support-identities) => '("left" "right"))
        (check (.ref (claim one) 'active-support-identities) => '("right"))
        (check (.ref (claim one) 'status) => 'supported)
        (check (.ref (claim none) 'status) => 'unsupported)
        (check (.ref (cadr (.ref none 'conclusions)) 'status) => 'unsupported)
        (check (.ref two 'semantic-digest) => (.ref (result p history 1 128) 'semantic-digest))
        (check (.ref none 'proof-admitted?) => #f)
        (check (.ref none 'action-authorized?) => #f)))
    (yuanxu-test-case "partial inventory and budget never certify no support"
      (check (.ref (claim (result (program #f) history 3 128)) 'status) => 'unknown)
      (let (r (result (program #t) history 3 0))
        (check (.ref (claim r) 'status) => 'unknown)
        (check (.ref r 'budget-exhausted?) => #t)))
    (yuanxu-test-case "correction binds exact revision and conflicts remain unknown"
      (let* ((journal (agentic-ai-lab-temporal-evidence-journal "correction" "txn"
                       (list (revision "a1" "a" 'assert #f 1)
                             (revision "a2" "a" 'correct "a1" 2)
                             (revision "a3" "a" 'correct "a1" 3))))
             (p (agentic-ai-lab-temporal-support-program "one" "policy" #t
                  (list (agentic-ai-lab-temporal-support "left" "claim" "proof-a"
                          (list (agentic-ai-lab-temporal-support-premise "a" "a1")) '())))))
        (check (.ref (claim (result p journal 1 128)) 'status) => 'supported)
        (check (.ref (claim (result p journal 2 128)) 'status) => 'unsupported)
        (check (.ref (claim (result p journal 3 128)) 'status) => 'unknown)))
    (yuanxu-test-case "future evidence is unknown until its admission cut"
      (check (.ref (claim (result (program #t) history 0 128)) 'status) => 'unknown)
      (check (.ref (claim (result (program #t) history 1 128)) 'status) => 'supported)
      (check (.ref (claim (agentic-ai-lab-temporal-support-evaluate (program #t) history (at 1) (valid 11) 128)) 'status) => 'unsupported))
    (yuanxu-test-case "recursive and foreign support declarations reject"
      (check-exception (agentic-ai-lab-temporal-support-program "cycle" "policy" #t
                         (list (agentic-ai-lab-temporal-support "loop" "claim" "proof" '() '("claim")))) true)
      (check-exception (result (agentic-ai-lab-temporal-support-program "foreign" "policy" #t
                                 (list (agentic-ai-lab-temporal-support "x" "claim" "proof"
                                   (list (agentic-ai-lab-temporal-support-premise "foreign" "a1")) '()))) history 1 128) true))
    (yuanxu-test-case "policy half-open window keeps proof and effects unadmitted"
      (let* ((p (program #t)) (policy (agentic-ai-lab-temporal-support-policy "policy" "rev1" (at 1) (at 4)))
             (evaluate (lambda (n) (agentic-ai-lab-temporal-support-guard p history (at 1) #f 128
                         policy (.ref policy 'semantic-digest) (at n))))
             (early (evaluate 0)) (active (evaluate 1)) (expired (evaluate 4)))
        (check (.ref early 'policy-status) => 'not-yet-effective)
        (check (.ref active 'policy-status) => 'applicable)
        (check (.ref active 'policy-applicable?) => #t)
        (check (.ref expired 'policy-status) => 'expired-policy)
        (check (.ref expired 'policy-applicable?) => #f)
        (check (.ref (claim (.ref expired 'evaluation)) 'status) => 'supported)
        (check (.ref active 'proof-admitted?) => #f)
        (check (.ref active 'selection-admitted?) => #f)
        (check (.ref active 'action-authorized?) => #f)
        (check (.ref active 'durable?) => #f)))
    (yuanxu-test-case "replacement policy cannot inherit the old binding"
      (let* ((old (agentic-ai-lab-temporal-support-policy "policy" "rev1" (at 1) (at 4)))
             (new (agentic-ai-lab-temporal-support-policy "policy" "rev2" (at 1) (at 4)))
             (r (agentic-ai-lab-temporal-support-guard (program #t) history (at 1) #f 128
                  new (.ref old 'semantic-digest) (at 2))))
        (check (.ref r 'policy-status) => 'stale-policy)
        (check (.ref r 'policy-applicable?) => #f)
        (check-exception (agentic-ai-lab-temporal-support-guard (program #t) history (at 1) #f 128
          (agentic-ai-lab-temporal-support-policy "foreign" "rev1" (at 1) (at 4))
          (.ref old 'semantic-digest) (at 2)) true)))
    (yuanxu-test-case "historical replay binds policy evidence and declared time"
      (let* ((p (program #t)) (policy (agentic-ai-lab-temporal-support-policy "policy" "rev1" (at 1) (at 4)))
             (r (agentic-ai-lab-temporal-support-guard p history (at 1) #f 128 policy
                  (.ref policy 'semantic-digest) (at 2)))
             (replay (agentic-ai-lab-temporal-support-guard-replay r p history policy)))
        (check (.ref replay 'semantic-digest) => (.ref r 'semantic-digest))
        (check-exception (agentic-ai-lab-temporal-support-guard-replay
          (.o (:: @ r) effective-at: (at 4)) p history policy) true)
        (check-exception (agentic-ai-lab-temporal-support-guard-replay
          (.o (:: @ r) as-of: (at 3)) p history policy) true)
        (check-exception (agentic-ai-lab-temporal-support-guard-replay
          (.o (:: @ r) action-authorized?: #t) p history policy) true)
        (check-exception (agentic-ai-lab-temporal-support-guard-replay r p history
          (agentic-ai-lab-temporal-support-policy "policy" "rev2" (at 1) (at 4))) true)
        (check-exception (agentic-ai-lab-temporal-support-guard-replay
          (.o (:: @ r) semantic-digest: "forged") p history policy) true)))
    (yuanxu-test-case "invalid policy windows time domains and forged values reject"
      (let (policy (agentic-ai-lab-temporal-support-policy "policy" "rev1" (at 1) (at 4)))
        (check-exception (agentic-ai-lab-temporal-support-policy "policy" "rev1" (at 4) (at 1)) true)
        (check-exception (agentic-ai-lab-temporal-support-policy "policy" "rev1" (at 1) (at 1)) true)
        (check-exception (agentic-ai-lab-temporal-support-policy "policy" "rev1" (at 1) (valid 4)) true)
        (check-exception (agentic-ai-lab-temporal-support-guard (program #t) history (at 1) #f 128
          policy (.ref policy 'semantic-digest) (valid 2)) true)
        (check-exception (agentic-ai-lab-temporal-support-guard (program #t) history (at 1) #f 128
          (.o (:: @ policy) semantic-digest: "forged") (.ref policy 'semantic-digest) (at 2)) true)
        (check-exception (agentic-ai-lab-temporal-support-policy "policy" "rev1"
          (agentic-ai-lab-temporal-instant "uncertain" "txn" 1 "ledger" 'uncertain) (at 4)) true)))))
