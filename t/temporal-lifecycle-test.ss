;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :agentic-ai-lab/testing-api yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :std/test
        :agentic-ai-lab/modules/temporal-causality/objects
        :agentic-ai-lab/modules/temporal-causality/funs
        :agentic-ai-lab/modules/temporal-causality/admission/interface
        :agentic-ai-lab/modules/temporal-causality/lifecycle/interface
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/interface)
(export temporal-lifecycle-test)
(def (model position)
  (agentic-ai-lab-temporal-model "family"
   (list (agentic-ai-lab-temporal-clock-domain "clock" 'event-time))
   (list (agentic-ai-lab-temporal-model-observation "build" "clock" position "ledger" 'observed)
         (agentic-ai-lab-temporal-model-observation "deploy" "clock" 2 "ledger" 'observed))
   (list (agentic-ai-lab-temporal-hypothesis "target" "build" "deploy"
          (list (agentic-ai-lab-temporal-constraint "order" 'before "build" "deploy")))) #t))
(def query (agentic-ai-lab-temporal-query "query" "target" #f))
(def (admit generation-value position)
  (let (m (model position))
    (agentic-ai-lab-temporal-family-admit
     m query (agentic-ai-lab-temporal-source-snapshot
              "source" "host" "deployment" "read-only"
              (string-append "cut-" (number->string generation-value))
              (string-append "projection-" (number->string generation-value))
              "policy" generation-value m) "claim")))
(def (frontier previous admission complete?)
  (let* ((revision (.ref previous 'revision)) (source (.ref admission 'source))
         (index (agentic-ai-lab-temporal-dependency-index
                 "index" (.ref revision 'cut-digest) (.ref revision 'projection-digest)
                 complete? (list (agentic-ai-lab-temporal-derivation
                                 (.ref revision 'identity) (.ref revision 'cut-digest)
                                 (.ref revision 'projection-digest) "policy" '("build") '())))))
    (agentic-ai-lab-temporal-reverse-dependency-plan
     index (.ref source 'cut-digest) (.ref source 'projection-digest) '("build"))))
(def temporal-lifecycle-test
  (test-suite "native family proof bound conclusion lifecycle"
    (yuanxu-test-case "same classification still gets new proof and predecessor"
      (let* ((root (agentic-ai-lab-temporal-family-revision-root (admit 7 1)))
             (next (admit 8 1))
             (changed (agentic-ai-lab-temporal-family-revision-change root next (frontier root next #t) 'correct))
             (checked (agentic-ai-lab-temporal-family-revision-replay changed)))
        (check (.ref (.ref root 'admission) 'classification) => 'necessary)
        (check (.ref (.ref checked 'admission) 'classification) => 'necessary)
        (check (.ref (.ref checked 'revision) 'predecessor-identity)
               => (.ref (.ref root 'revision) 'identity))
        (check (equal? (.ref root 'semantic-digest) (.ref checked 'semantic-digest)) => #f)
        (check (.ref checked 'action-authorized?) => #f)))
    (yuanxu-test-case "refutation binds a tombstone without erasing necessary history"
      (let* ((root (agentic-ai-lab-temporal-family-revision-root (admit 7 1)))
             (a2 (admit 8 1))
             (corrected (agentic-ai-lab-temporal-family-revision-change root a2 (frontier root a2 #t) 'correct))
             (a3 (admit 9 3))
             (withdrawn (agentic-ai-lab-temporal-family-revision-change corrected a3 (frontier corrected a3 #t) 'retract))
             (journal (agentic-ai-lab-temporal-family-revision-journal "history" (list root corrected withdrawn))))
        (check (length (.ref journal 'revisions)) => 3)
        (check (.ref (.ref withdrawn 'revision) 'operation) => 'retract)
        (check (.ref (.ref withdrawn 'revision) 'result-identity) => #f)
        (check (.ref (.ref root 'admission) 'classification) => 'necessary)
        (check (.ref withdrawn 'source-authenticated?) => #f)
        (check (.ref withdrawn 'runtime-executed?) => #f)
        (let (revived (admit 10 1))
          (check-exception (agentic-ai-lab-temporal-family-revision-change
                           withdrawn revived (frontier withdrawn revived #t) 'correct) true))))
    (yuanxu-test-case "frontier alone and incomplete frontier cannot withdraw"
      (let* ((root (agentic-ai-lab-temporal-family-revision-root (admit 7 1))) (next (admit 8 1)))
        (check-exception (agentic-ai-lab-temporal-family-revision-change root next (frontier root next #t) 'retract) true)
        (check-exception (agentic-ai-lab-temporal-family-revision-change root next (frontier root next #f) 'correct) true)
        (check-exception (agentic-ai-lab-temporal-family-revision-change
                         root next (.o (:: @ (frontier root next #f)) status: 'scoped-complete) 'correct) true)))
    (yuanxu-test-case "wrong revised cut and nonadvancing generation reject"
      (let* ((root (agentic-ai-lab-temporal-family-revision-root (admit 7 1)))
             (next (admit 8 1)) (plan (frontier root next #t)))
        (check-exception (agentic-ai-lab-temporal-family-revision-change
                         root next (.o (:: @ plan) revised-cut-digest: "foreign") 'correct) true)
        (check-exception (agentic-ai-lab-temporal-family-revision-change root (admit 7 3) plan 'correct) true)))
    (yuanxu-test-case "independently valid foreign source or query cannot replace a claim"
      (let* ((root (agentic-ai-lab-temporal-family-revision-root (admit 7 1)))
             (next (admit 8 1)) (m (.ref next 'model)) (s (.ref next 'source))
             (other-query (agentic-ai-lab-temporal-family-admit
                           m (agentic-ai-lab-temporal-query "foreign-query" "target" #f) s "claim"))
             (other-source (agentic-ai-lab-temporal-family-admit
                            m query (agentic-ai-lab-temporal-source-snapshot
                                     "foreign" "host" "deployment" "read-only"
                                     "cut-8" "projection-8" "policy" 8 m) "claim")))
        (check-exception (agentic-ai-lab-temporal-family-revision-change root other-query (frontier root next #t) 'correct) true)
        (check-exception (agentic-ai-lab-temporal-family-revision-change root other-source (frontier root next #t) 'correct) true)))
    (yuanxu-test-case "forged proof and digest cannot enter a journal"
      (let* ((root (agentic-ai-lab-temporal-family-revision-root (admit 7 1)))
             (next (admit 8 3))
             (changed (agentic-ai-lab-temporal-family-revision-change root next (frontier root next #t) 'retract)))
        (check-exception (agentic-ai-lab-temporal-family-revision-journal
                         "history" (list root (.o (:: @ changed) semantic-digest: "forged"))) true)
        (check-exception (agentic-ai-lab-temporal-family-revision-replay
                         (.o (:: @ changed) revision: (.o (:: @ (.ref changed 'revision)) proof-identity: "forged"))) true)))
    (yuanxu-test-case "missing predecessor inventory cannot masquerade as complete journal"
      (let* ((root (agentic-ai-lab-temporal-family-revision-root (admit 7 1))) (next (admit 8 3))
             (changed (agentic-ai-lab-temporal-family-revision-change root next (frontier root next #t) 'retract)))
        (check-exception (agentic-ai-lab-temporal-family-revision-journal "history" (list changed)) true)))
    (yuanxu-test-case "native archive replays a canonical full premise graph"
      (let* ((root (agentic-ai-lab-temporal-family-revision-root (admit 7 1)))
             (next (admit 8 3))
             (changed (agentic-ai-lab-temporal-family-revision-change root next (frontier root next #t) 'retract))
             (archive (agentic-ai-lab-temporal-family-archive "archive" (list changed root)))
             (ordered (agentic-ai-lab-temporal-family-archive "archive" (list root changed)))
             (replayed (agentic-ai-lab-temporal-family-archive-replay archive)))
        (check (agentic-ai-lab-temporal-family-archive? archive) => #t)
        (check (.ref archive 'semantic-digest) => (.ref ordered 'semantic-digest))
        (check (.ref replayed 'semantic-digest) => (.ref archive 'semantic-digest))
        (check (length (.ref replayed 'family-revisions)) => 2)
        (check (.ref replayed 'durable?) => #f)
        (check (.ref replayed 'source-authenticated?) => #f)
        (check (.ref replayed 'action-authorized?) => #f)))
    (yuanxu-test-case "archive rejects forged hashes and incomplete history"
      (let* ((root (agentic-ai-lab-temporal-family-revision-root (admit 7 1)))
             (next (admit 8 3))
             (changed (agentic-ai-lab-temporal-family-revision-change root next (frontier root next #t) 'retract))
             (archive (agentic-ai-lab-temporal-family-archive "archive" (list root changed))))
        (check-exception (agentic-ai-lab-temporal-family-archive "archive" (list changed)) true)
        (check-exception (agentic-ai-lab-temporal-family-archive-replay
                          (.o (:: @ archive) semantic-digest: "forged")) true)
        (check-exception (agentic-ai-lab-temporal-family-archive-replay
                          (.o (:: @ archive) journal:
                            (.o (:: @ (.ref archive 'journal)) revisions:
                              (list (.o (:: @ (.ref root 'revision)) proof-identity: "forged")
                                    (.ref changed 'revision))))) true)
        (check-exception (agentic-ai-lab-temporal-family-archive-replay
                          (.o (:: @ archive) journal: (.o (:: @ (.ref archive 'journal)) semantic-digest: "forged"))) true)))))
