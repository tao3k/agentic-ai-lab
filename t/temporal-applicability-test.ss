;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :agentic-ai-lab/testing-api yuanxu-test-case)
        (only-in :clan/poo/object .o .ref)
        :std/test
        :agentic-ai-lab/modules/temporal-causality/objects
        :agentic-ai-lab/modules/temporal-causality/funs
        :agentic-ai-lab/modules/temporal-causality/admission/interface
        :agentic-ai-lab/modules/temporal-causality/applicability/interface)
(export temporal-applicability-test)
(def (model position)
  (agentic-ai-lab-temporal-model "family"
   (list (agentic-ai-lab-temporal-clock-domain "clock" 'event-time))
   (list (agentic-ai-lab-temporal-model-observation "build" "clock" position "ledger" 'observed)
         (agentic-ai-lab-temporal-model-observation "deploy" "clock" 2 "ledger" 'observed))
   (list (agentic-ai-lab-temporal-hypothesis "target" "build" "deploy"
          (list (agentic-ai-lab-temporal-constraint "order" 'before "build" "deploy")))) #t))
(def query (agentic-ai-lab-temporal-query "query" "target" #f))
(def (source id authority policy generation-value value)
  (agentic-ai-lab-temporal-source-snapshot id authority "deployment" "read-only"
   "cut" "projection" policy generation-value value))
(def temporal-applicability-test
  (test-suite "replayed family proof and current source applicability"
    (yuanxu-test-case "current source replays original premises"
      (let* ((m (model 1)) (s (source "source" "host" "policy" 7 m))
             (a (agentic-ai-lab-temporal-family-admit m query s "conclusion"))
             (checked (agentic-ai-lab-temporal-family-applicability a s)))
        (check (.ref checked 'status) => 'current)
        (check (.ref checked 'action-authorized?) => #f)
        (check (.ref checked 'source-authenticated?) => #f)
        (check (.ref checked 'runtime-executed?) => #f)
        (check (.ref (agentic-ai-lab-temporal-family-admission-replay a) 'semantic-digest)
               => (.ref a 'semantic-digest))))
    (yuanxu-test-case "generation policy authority and corrected rows stale history"
      (let* ((m (model 1)) (s (source "source" "host" "policy" 7 m))
             (a (agentic-ai-lab-temporal-family-admit m query s "conclusion")))
        (for-each
         (lambda (current)
           (check (.ref (agentic-ai-lab-temporal-family-applicability a current) 'status) => 'stale))
         (list (source "source" "host" "policy" 8 m)
               (source "source" "host" "revoked-policy" 7 m)
               (source "source" "other-host" "policy" 7 m)
               (source "source" "host" "policy" 8 (model 3))))
        (check (.ref a 'classification) => 'necessary)
        (let* ((corrected (model 3)) (s2 (source "source" "host" "policy" 8 corrected))
               (a2 (agentic-ai-lab-temporal-family-admit corrected query s2 "revised")))
          (check (.ref a2 'classification) => 'refuted)
          (check (.ref (agentic-ai-lab-temporal-family-applicability a2 s2) 'status) => 'current))))
    (yuanxu-test-case "foreign logical source cannot establish currentness"
      (let* ((m (model 1)) (s (source "source" "host" "policy" 7 m))
             (a (agentic-ai-lab-temporal-family-admit m query s "conclusion")))
        (check-exception (agentic-ai-lab-temporal-family-applicability a
                         (source "foreign" "host" "policy" 7 m)) true)))
    (yuanxu-test-case "forged proof fields and source digest fail replay"
      (let* ((m (model 1)) (s (source "source" "host" "policy" 7 m))
             (a (agentic-ai-lab-temporal-family-admit m query s "conclusion")))
        (check-exception
         (agentic-ai-lab-temporal-family-applicability
          (.o (:: @ a) classification: 'refuted) s) true)
        (check-exception
         (agentic-ai-lab-temporal-family-applicability
          (.o (:: @ a) semantic-digest: "forged") s) true)
        (check-exception
         (agentic-ai-lab-temporal-family-applicability a
          (.o (:: @ s) semantic-digest: "forged")) true)))))
