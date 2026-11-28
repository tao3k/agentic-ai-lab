;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Context `+durable` Feature Bridge:
;;; Composes ai-agentic-context (progressive L0..L3 disclosure + inert rule
;;; overrides + thin Org <-> Durable adapter) with Pure Durable Work Engine
;;; (`modules/durable/work.ss`).

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :clan/poo/type Type. define-type)
        (only-in "../../org-contract/elements.ss" context-org-source)
        (only-in "../../funs-org-elements-gql.ss"
                 agentic-ai-lab-ai-agentic-context-org-element-graph)
        (only-in "../../funs-org-progressive-rules.ss"
                 agentic-ai-lab-ai-agentic-context-parse-rule-overrides
                 agentic-ai-lab-ai-agentic-context-ascent-progressive-plan)
        (only-in "../../../durable/work.ss"
                 DurableWorkExports
                 work-effective-rules
                 opt-ref)
        (only-in "./org-adapter.ss"
                 ContextDurableOrgExports
                 org->work-snapshot
                 org-work-funflow-dag
                 org-work-orchestration-plan
                 org-work-reanchor-mainline
                 org-work-archive-transition
                 org-work-commit-archive!
                 org-work-reopen!
                 org-work-recover
                 org-shared-context-perceive-claims
                 org-shared-context-assert-write-owner
                 org-shared-context-claim!
                 org-shared-context-extend!
                 org-shared-context-handover!))

(export context-durable-effective-rules
        context-durable-orchestration-plan
        ContextDurableExports
        ContextDurableFeatureContract
        EnableContextDurable)

(def (context-durable-effective-rules node org-source-text)
  (let ((overrides (if (and (string? org-source-text) (> (string-length org-source-text) 0))
                     (agentic-ai-lab-ai-agentic-context-parse-rule-overrides org-source-text)
                     #f)))
    (work-effective-rules node overrides)))

(def (context-durable-orchestration-plan task org-source-text journal-state)
  (let* ((overrides (if (and (string? org-source-text) (> (string-length org-source-text) 0))
                      (agentic-ai-lab-ai-agentic-context-parse-rule-overrides org-source-text)
                      #f))
         (plan (org-work-orchestration-plan task org-source-text journal-state
                                            rule-overrides: overrides))
         (dag-proj (.ref plan 'dag-projection))
         (task-id (.ref plan 'task-id))
         (progressive
          (with-catch
            (lambda (_err) #f)
            (lambda ()
              (let* ((src-cut-obj (context-org-source (or (opt-ref task 'org-path task-id) task-id)
                                                      1
                                                      org-source-text
                                                      #t))
                     (elem-graph (agentic-ai-lab-ai-agentic-context-org-element-graph
                                  task-id (list src-cut-obj))))
                (agentic-ai-lab-ai-agentic-context-ascent-progressive-plan
                 elem-graph
                 (.o focus-property-ids: (list (.ref dag-proj 'root-id))
                     drill-downs: (opt-ref journal-state 'drill-downs '()))))))))
    (.o (:: @ plan)
        bind-these: #f
        progressive-plan: progressive)))

(def ContextDurableExports
  (.o bind-these: #f
      work-core: DurableWorkExports
      org-adapter: ContextDurableOrgExports
      effective-rules: context-durable-effective-rules
      funflow-dag: org-work-funflow-dag
      orchestration-plan: context-durable-orchestration-plan
      reanchor-mainline: org-work-reanchor-mainline
      archive-transition: org-work-archive-transition
      commit-archive!: org-work-commit-archive!
      reopen!: org-work-reopen!
      recover: org-work-recover
      perceive-claims: org-shared-context-perceive-claims
      assert-write-owner: org-shared-context-assert-write-owner
      claim!: org-shared-context-claim!
      extend!: org-shared-context-extend!
      handover!: org-shared-context-handover!))

(define-type (ContextDurableFeatureContract @ Type.)
  identity: 'ai-agentic-context/durable-feature
  .element?: (lambda (scope)
    (and (object? scope)
         (.slot? scope 'durable)
         (object? (.ref scope 'durable)))))

(def (EnableContextDurable inherited)
  (.o (:: self inherited)
      durable: ContextDurableExports))
