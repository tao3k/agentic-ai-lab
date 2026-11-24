;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test
        (only-in :clan/poo/object .get)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :tao3k/agentic-ai-lab/t/yanxu/interface Lab))

(export graph-engine-module-test)

(def graph-engine-module-test
  (test-suite "GraphEngine Yuanxu module publication"
    (yuanxu-test-case "loads unified GraphEngine through Lab init module namespace"
      (def scope (.get Lab graph-engine))
      (check-equal? (.get scope library)
                    'tao3k/agentic-ai-lab/modules/graph-engine/interface)
      (check (procedure? (.get scope reconcile-frontier)) => #t)
      (check (procedure? (.get scope plan-funflow-c4-frontier)) => #t)
      (check (procedure? (.get scope reconcile-to-fixed-point)) => #t)
      (check (procedure? (.get scope reconcile-event-stream)) => #t)
      (check (procedure? (.get scope work-snapshot->obligation-graph)) => #t)
      (check (procedure? (.get scope attenuate-delegation-envelope)) => #t)
      (check (procedure? (.get scope admit-delegated-execution-fence)) => #t)
      (check (procedure? (.get scope make-context-trunk)) => #t)
      (check (procedure? (.get scope spawn-trunk-branch)) => #t)
      (check (procedure? (.get scope execute-branch-funflow-dag)) => #t)
      (check (procedure? (.get scope absorb-branch-contribution)) => #t)
      (check (procedure? (.get scope converge-trunk-to-apex)) => #t))))
