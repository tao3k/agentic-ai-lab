;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: custom user-interface multi-agent session graph scenario.
;;; Invariant: graph, registry, and communication receipts are declarative;
;;; Scheme never delivers messages or starts agents.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-flag-entry
                 yuanxu-user-module-selection-key)
        :agentic-ai-lab/modules/session/config
        (only-in "../user-interface/custom/my-module/cases/session-agent-graph"
                 agentic-ai-lab-custom-my-module-session-agent-graph-case))

(export user-interface-custom-session-agent-graph-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref row key)
  (let (entry (assoc key row))
    (if entry (cdr entry) #f)))

;; : (-> [Alist] Symbol [Alist])
(def (rows-with-kind rows kind)
  (let loop ((remaining rows)
             (rows-rev '()))
    (if (null? remaining)
      (reverse rows-rev)
      (let (row (car remaining))
        (loop (cdr remaining)
              (if (and (list? row)
                       (eq? (test-ref row 'kind) kind))
                (cons row rows-rev)
                rows-rev))))))

;; : (-> [PooUserModuleSelection] [Value])
(def (module-config-rows module-selection-bundle)
  (let* ((selection (car module-selection-bundle))
         (entry
          (yuanxu-user-module-selection-flag-entry selection ':session-rows)))
    (if entry (cdr entry) '())))

;; : TestSuite
(def user-interface-custom-session-agent-graph-test
  (test-suite "agentic-ai-lab custom user-interface session-agent-graph case"
    (yuanxu-test-case "projects custom session graph and communication receipts"
      (let* ((selection
              (car agentic-ai-lab-custom-my-module-session-agent-graph-case))
             (rows
              (module-config-rows
               agentic-ai-lab-custom-my-module-session-agent-graph-case))
             (registry-entry-count (.ref (car rows) 'entry-count))
             (graph (agentic-ai-lab-session-agent-graph->alist (cadr rows)))
             (build-audit-channel
              (agentic-ai-lab-session-communication-channel-receipt->alist
               (list-ref rows 2)))
             (build-audit (agentic-ai-lab-session-communication-receipt->alist
                           (list-ref rows 4)))
             (communication-channel-rows
              (rows-with-kind
               rows
               'agentic-ai-lab.session.communication-channel-receipt))
             (communication-rows
              (rows-with-kind rows 'agentic-ai-lab.session.communication-receipt)))
        (check-equal? (yuanxu-user-module-selection-key selection)
                      '(session . session))
        (check-equal? registry-entry-count 3)
        (check-equal? (test-ref graph 'kind)
                      'agentic-ai-lab.session.agent-graph)
        (check-equal? (test-ref graph 'agent-count) 2)
        (check-equal? (test-ref graph 'session-count) 3)
        (check-equal? (test-ref graph 'agent-ids)
                      '(agent/build agent/audit))
        (check-equal? (test-ref graph 'communication-receipt-count) 2)
        (check-equal? (map (lambda (row) (test-ref row 'relation-kind))
                           (test-ref graph 'communication-receipts))
                      '(sibling child-parent))
        (check-equal? (test-ref graph 'communication-channel-receipt-count) 2)
        (check-equal? (map (lambda (row) (test-ref row 'channel-id))
                           (test-ref graph 'communication-channel-receipts))
                      '(channel/build-audit channel/audit-root))
        (check-equal? (test-ref graph 'runtime-executed) #f)
        (check-equal? (test-ref build-audit-channel 'channel-id)
                      'channel/build-audit)
        (check-equal? (test-ref build-audit 'relation-kind) 'sibling)
        (check-equal? (test-ref build-audit 'runtime-executed) #f)
        (check-equal? (length communication-channel-rows) 2)
        (check-equal? (length communication-rows) 2)))))
