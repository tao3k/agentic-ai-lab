;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Pure admission/selection contract. Effects and payload queues belong to
;;; the explicit Actor adapter; this module acquires no runtime resources.
(import (only-in :clan/poo/object .o .ref)
        "private/scheduling-kernel.ss")
(export context-scheduling-contract context-scheduling-state
        context-scheduling-event context-scheduling-step)

(def (positive? n) (and (exact-integer? n) (> n 0)))

(def (context-scheduling-contract data-value control-value burst-value)
  (unless (and (positive? data-value) (positive? control-value)
               (positive? burst-value))
    (error "Scheduling capacities and burst must be positive exact integers"))
  (.o kind: 'context.scheduling-contract.v1
      identity: 'context-bounded-scheduling semantic-revision: 1
      data-capacity: data-value control-capacity: control-value
      control-burst: burst-value))

;; Construction is centralized so every transition returns an ordinary POO
;; value. Active work retains its credit until completion, not dispatch.
(def (state contract-value data-value controls-value active-value burst-value phase-value)
  (.o kind: 'context.scheduling-state.v1 contract: contract-value
      queued-data: data-value queued-controls: controls-value active: active-value
      consecutive-controls: burst-value phase: phase-value))

(def (context-scheduling-state contract)
  (unless (eq? (.ref contract 'kind) 'context.scheduling-contract.v1)
    (error "Expected Context scheduling contract"))
  (state contract 0 0 'idle 0 'open))

(def (context-scheduling-event operation-value)
  (unless (memq operation-value '(offer-data offer-control dispatch complete drain close idle))
    (error "Unknown scheduling operation" operation-value))
  (.o kind: 'context.scheduling-event.v1 operation: operation-value))

(def (context-scheduling-step current event)
  (unless (and (eq? (.ref current 'kind) 'context.scheduling-state.v1)
               (eq? (.ref event 'kind) 'context.scheduling-event.v1))
    (error "Expected native scheduling state and event"))
  (let* ((contract (.ref current 'contract))
         (frame (make-scheduling-frame
                  (.ref contract 'data-capacity) (.ref contract 'control-capacity)
                  (.ref contract 'control-burst) (.ref current 'queued-data)
                  (.ref current 'queued-controls) (.ref current 'active)
                  (.ref current 'consecutive-controls) (.ref current 'phase))))
    ;; Public extension fields are read before projection, so the facade never
    ;; hides a stale cached frame behind a refined POO state or contract.
    (let-values (((next accepted-value selection-value)
                  (scheduling-transition frame (.ref event 'operation))))
      (let (next-value
             (if (eq? next frame) current
               (state contract (scheduling-frame-data next) (scheduling-frame-controls next)
                 (scheduling-frame-active next) (scheduling-frame-burst next)
                 (scheduling-frame-phase next))))
        (.o kind: 'context.scheduling-decision.v1 state: next-value
            accepted?: accepted-value selected: selection-value)))))
