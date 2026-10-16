;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;; Private source fragment included by governor-core.ss.
(def (loop-governor-slot-rows name strategy overrides)
  (loop-governor-slot-rows/tail
   (list
    (cons 'name name)
    (cons 'strategy strategy))
   overrides))

(def (make-loop-governor name strategy . maybe-overrides)
  (poo-core-role-object
   (slot-rows
    (loop-governor-slot-rows
     name
     strategy
     (if (null? maybe-overrides) '() (car maybe-overrides))))
   (supers loop-governor-prototype)))

(def (loop-governor? governor)
  (and (object? governor)
       (eq? (loop-governor-slot governor 'kind #f)
            'loop-governor)))

(def (loop-governor-slot governor slot default)
  (role-slot/default governor slot default))

(def (loop-governor-node? node)
  (and (object? node)
       (loop-governor-node-kind node)
       #t))

(def (loop-governor-node-slot node slot default)
  (role-slot/default node slot default))

(def (loop-governor-node-name node)
  (loop-governor-node-slot node 'name #f))

(def (loop-governor-node-kind node)
  (loop-governor-node-slot node 'governance-node-kind #f))

(def (loop-governor-node-responsibility node)
  (let (specific
        (loop-governor-node-slot node 'governance-responsibility #f))
    (if specific
      specific
      (loop-governor-node-slot node 'responsibility #f))))

(def (loop-governor-node-human-intervention? node)
  (loop-governor-node-slot node 'human-intervention #f))

(def (loop-governor-node-control-owner node)
  (loop-governor-node-slot node 'control-owner #f))

(def (loop-governor-node-execution-owner node)
  (loop-governor-node-slot node 'execution-owner #f))

(def (loop-governor-node-metadata node)
  (loop-governor-node-slot node 'metadata '()))

(def (loop-governor-require-slots/validated! name strategy priority-table shared-denylist state-key collision-policy aggregate-budget agent-judges agent-judge-nodes human-inbox handoff control-owner execution-owner metadata)
  (loop-governor-check-slot! +loop-governor-name-contract+ name)
  (loop-governor-check-slot! +loop-governor-strategy-contract+ strategy)
  (loop-governor-check-slot!
   +loop-governor-priority-table-contract+
   priority-table)
  (loop-governor-check-slot!
   +loop-governor-shared-denylist-contract+
   shared-denylist)
  (loop-governor-check-slot! +loop-governor-state-key-contract+ state-key)
  (loop-governor-check-slot!
   +loop-governor-collision-policy-contract+
   collision-policy)
  (loop-governor-check-slot!
   +loop-governor-aggregate-budget-contract+
   aggregate-budget)
  (loop-governor-check-slot! +loop-governor-agent-judges-contract+ agent-judges)
  (loop-governor-check-slot!
   +loop-governor-agent-judge-nodes-contract+
   agent-judge-nodes)
  (loop-governor-check-slot! +loop-governor-human-inbox-contract+ human-inbox)
  (loop-governor-check-slot! +loop-governor-handoff-contract+ handoff)
  (loop-governor-check-slot!
   +loop-governor-control-owner-contract+ control-owner)
  (loop-governor-check-slot!
   +loop-governor-execution-owner-contract+
   execution-owner)
  (loop-governor-check-slot! +loop-governor-metadata-contract+ metadata)
  #t)

(def (loop-governor-node->contract node)
  (list (cons 'schema +loop-governor-node-schema+)
        (cons 'kind 'loop-governance-node)
        (cons 'name (loop-governor-node-name node))
        (cons 'governance-node-kind (loop-governor-node-kind node))
        (cons 'governance-responsibility
              (loop-governor-node-responsibility node))
        (cons 'human-intervention
              (loop-governor-node-human-intervention? node))
        (cons 'control-owner (loop-governor-node-control-owner node))
        (cons 'execution-owner (loop-governor-node-execution-owner node))
        (cons 'metadata (loop-governor-node-metadata node))))

(def (loop-governor-node-contracts nodes)
  (cond
   ((null? nodes) '())
   (else
    (cons (loop-governor-node->contract (car nodes))
          (loop-governor-node-contracts (cdr nodes))))))

(def (loop-governor-alist-ref alist key default)
  (cond
   ((assoc key alist) => cdr)
   (else default)))

(def (loop-governor-alist? value)
  (and (list? value) (andmap pair? value)))

(def (loop-governor-list-of? predicate values)
  (and (list? values) (andmap predicate values)))

(def (loop-governor-action-key? value)
  (or (symbol? value)
      (string? value)))

(def (loop-governor-action-key-list? value)
  (loop-governor-list-of? loop-governor-action-key? value))

(def (loop-governor-node-list? value)
  (loop-governor-list-of? loop-governor-node? value))

(def (loop-governor-strategy-plan-slot? value)
  (loop-strategy-plan? value))

(def (loop-governor-node-type-contract->alist)
  (poo-flow-native-contract->alist +loop-governor-node-type-contract+))

(def (loop-governor-type-contract->alist)
  (poo-flow-native-contract->alist +loop-governor-type-contract+))

(def (loop-governor-check-slot! contract value)
  (poo-flow-contract-check-slot! contract value))

(def (loop-governor-require-node-slots! name governance-node-kind responsibility human-intervention? control-owner execution-owner metadata)
  (loop-governor-check-slot! +loop-governor-node-name-contract+ name)
  (loop-governor-check-slot!
   +loop-governor-node-governance-node-kind-contract+
   governance-node-kind)
  (loop-governor-check-slot!
   +loop-governor-node-governance-responsibility-contract+
   responsibility)
  (loop-governor-check-slot!
   +loop-governor-node-human-intervention-contract+
   human-intervention?)
  (loop-governor-check-slot!
   +loop-governor-node-control-owner-contract+
   control-owner)
  (loop-governor-check-slot!
   +loop-governor-node-execution-owner-contract+
   execution-owner)
  (loop-governor-check-slot! +loop-governor-node-metadata-contract+ metadata)
  #t)

(def (loop-governor-name governor)
  (loop-governor-slot governor 'name #f))

(def (loop-governor-strategy governor)
  (loop-governor-slot governor 'strategy #f))

(def (loop-governor-priority-table governor)
  (loop-governor-slot governor 'priority-table '()))

(def (loop-governor-shared-denylist governor)
  (loop-governor-slot governor 'shared-denylist '()))

(def (loop-governor-aggregate-budget governor)
  (loop-governor-slot governor 'aggregate-budget '()))

(def (loop-governor-state-key governor)
  (loop-governor-slot governor 'state-key '()))

(def (loop-governor-collision-policy governor)
  (loop-governor-slot governor 'collision-policy '()))

(def (loop-governor-agent-judges governor)
  (loop-governor-slot governor 'agent-judges '()))

(def (loop-governor-agent-judge-nodes governor)
  (loop-governor-slot governor 'agent-judge-nodes '()))

(def (loop-governor-human-inbox governor)
  (loop-governor-slot governor 'human-inbox '()))

(def (loop-governor-handoff governor)
  (loop-governor-slot governor 'handoff '()))

(def (loop-governor-control-owner governor)
  (loop-governor-slot governor 'control-owner #f))

(def (loop-governor-execution-owner governor)
  (loop-governor-slot governor 'execution-owner #f))

(def (loop-governor-metadata governor)
  (loop-governor-slot governor 'metadata '()))
