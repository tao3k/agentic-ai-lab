;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: reads and validates memory intent carried by session POO objects.
;;; Invariant: transformation preserves explicit store and handoff references.
(import :gerbil/core
        (only-in :clan/poo/object .ref object?)
        :agentic-ai-lab/modules/session/objects)

(export agentic-ai-lab-session-memory-intent-ref
        agentic-ai-lab-session-memory-intent?
        agentic-ai-lab-session-memory-intent-name
        agentic-ai-lab-session-memory-intent-store-ref
        agentic-ai-lab-session-memory-intent-scope
        agentic-ai-lab-session-memory-intent-recall
        agentic-ai-lab-session-memory-intent-commit-policy
        agentic-ai-lab-session-memory-intent-runtime-owner
        agentic-ai-lab-session-memory-intent-metadata
        agentic-ai-lab-session-memory-intent-handoff
        agentic-ai-lab-session-memory-intent-handoff-bundle/rev
        agentic-ai-lab-session-memory-intent-handoff-bundle
        agentic-ai-lab-session-memory-intent-count)

;; Boundary: memory-intent accessors and handoff rows are pure projections.
;; The declaration constructor stays in transform.ss where metadata validation lives.
(def (agentic-ai-lab-session-memory-intent-ref intent key default)
  (if (object? intent)
    (.ref intent key)
    (agentic-ai-lab-session-alist-ref intent key default)))

(def (agentic-ai-lab-session-memory-intent? value)
  (or (and (object? value)
           (eq? (.ref value 'kind) 'agentic-ai-lab.session.memory-intent))
      (and (list? value)
           (eq? (agentic-ai-lab-session-alist-ref value 'kind #f)
                'agentic-ai-lab.session.memory-intent))))

(def (agentic-ai-lab-session-memory-intent-name intent)
  (agentic-ai-lab-session-memory-intent-ref intent 'intent-name #f))

(def (agentic-ai-lab-session-memory-intent-store-ref intent)
  (agentic-ai-lab-session-memory-intent-ref intent 'store-ref #f))

(def (agentic-ai-lab-session-memory-intent-scope intent)
  (agentic-ai-lab-session-memory-intent-ref intent 'scope #f))

(def (agentic-ai-lab-session-memory-intent-recall intent)
  (agentic-ai-lab-session-memory-intent-ref intent 'recall '()))

(def (agentic-ai-lab-session-memory-intent-commit-policy intent)
  (agentic-ai-lab-session-memory-intent-ref intent 'commit-policy #f))

(def (agentic-ai-lab-session-memory-intent-runtime-owner intent)
  (agentic-ai-lab-session-memory-intent-ref intent 'runtime-owner "marlin-agent-core"))

(def (agentic-ai-lab-session-memory-intent-metadata intent)
  (agentic-ai-lab-session-memory-intent-ref intent 'metadata '()))

(def (agentic-ai-lab-session-memory-intent-handoff intent)
  (list
   (cons 'kind 'agentic-ai-lab.session.memory-intent.handoff)
   (cons 'schema 'agentic-ai-lab.modules.session.memory-intent.handoff.v1)
   (cons 'intent-name (agentic-ai-lab-session-memory-intent-name intent))
   (cons 'store-ref (agentic-ai-lab-session-memory-intent-store-ref intent))
   (cons 'scope (agentic-ai-lab-session-memory-intent-scope intent))
   (cons 'recall (agentic-ai-lab-session-memory-intent-recall intent))
   (cons 'commit-policy
         (agentic-ai-lab-session-memory-intent-commit-policy intent))
   (cons 'runtime-owner
         (agentic-ai-lab-session-memory-intent-runtime-owner intent))
   (cons 'handoff-required #t)
   (cons 'descriptor-realized? #f)
   (cons 'runtime-executed #f)))

(def (agentic-ai-lab-session-memory-intent-handoff-bundle/rev memory-intents
                                                        rows-rev
                                                        count)
  (if (null? memory-intents)
    (cons rows-rev count)
    (agentic-ai-lab-session-memory-intent-handoff-bundle/rev
     (cdr memory-intents)
     (cons (agentic-ai-lab-session-memory-intent-handoff (car memory-intents))
           rows-rev)
     (fx+ count 1))))

(def (agentic-ai-lab-session-memory-intent-handoff-bundle memory-intents)
  (let (bundle
        (agentic-ai-lab-session-memory-intent-handoff-bundle/rev
         memory-intents
         '()
         0))
    (cons (reverse (car bundle)) (cdr bundle))))

(def (agentic-ai-lab-session-memory-intent-count memory-intents)
  (length memory-intents))
