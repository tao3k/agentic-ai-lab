;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: standalone downstream memory-core case module.
;;; Invariant: this declares memory store specs and validation receipts only;
;;; no memory backend recall or commit is executed.

(import :agentic-ai-lab/modules/session/syntax
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/config
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-flag-entry
                 yuanxu-user-module-selection->alist))

(export agentic-ai-lab-custom-my-module-memory-core-case)

(def agentic-ai-lab-custom-my-module-memory-core-case
  (let* ((selection
        (car
         (agentic-ai-lab-memory-configs
           (.def (project-memory-store @ memory-store-spec
                                       store-ref store-kind namespace
                                       scopes recall-policies commit-policies
                                       runtime-owner handoff-operation durable?
                                       runtime-backend metadata)
             store-ref: 'memory/project-notes
             store-kind: 'durable-project
             namespace: 'project
             scopes: '(current-session parent-summary project)
             recall-policies: '(semantic-search exact-key)
             commit-policies: '(append review-only)
             runtime-owner: "marlin-agent-core"
             handoff-operation: 'memory/project-notes
             |durable?|: #t
             runtime-backend: 'marlin-memory-adapter
             metadata: '((source . user-interface)
                         (case . memory-core)))
           (.def (custom-memory-catalog @ memory-catalog catalog-ref metadata)
             catalog-ref: 'memory-core/custom
             metadata: '((source . user-interface)
                         (case . memory-core))))))
       (catalog
        (cdr
         (yuanxu-user-module-selection-flag-entry
          selection
          ':memory-catalog)))
       (memory-intent
        (session-memory-intent recall-project-notes
          (store memory/project-notes)
          (scope project)
          (recall current-ticket design-notes)
          (commit append)
          (metadata (source . user-interface)
                    (case . memory-core))))
       (validation
        (memory-catalog-validation validation/custom-memory-core
          catalog
          (memory-intent)
          (metadata (source . user-interface)
                    (case . memory-core)))))
  (list
   (yuanxu-user-module-selection->alist selection)
   (agentic-ai-lab-memory-catalog->alist catalog)
   (memory-catalog-validation-row validation))))
