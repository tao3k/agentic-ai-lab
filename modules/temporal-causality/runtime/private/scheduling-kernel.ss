;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; One pure transition algorithm. POO remains the public contract; this private
;;; positional frame is its explicit runtime projection, never a second DSL.
(export make-scheduling-frame scheduling-frame-data-capacity scheduling-frame-control-capacity
        scheduling-frame-burst-limit scheduling-frame-data scheduling-frame-controls
        scheduling-frame-active scheduling-frame-burst scheduling-frame-phase
        scheduling-transition)

(defstruct scheduling-frame (data-capacity control-capacity burst-limit data controls active burst phase))

(def (next-frame previous data controls active burst phase)
  (make-scheduling-frame (scheduling-frame-data-capacity previous)
    (scheduling-frame-control-capacity previous) (scheduling-frame-burst-limit previous)
    data controls active burst phase))

;; Return the next immutable frame, acceptance, and selected class as native
;; multiple values. No POO object, closure, list or event is built on refusal.
(def (scheduling-transition current operation)
  (let ((data (scheduling-frame-data current))
        (controls (scheduling-frame-controls current))
        (active (scheduling-frame-active current))
        (burst (scheduling-frame-burst current))
        (phase (scheduling-frame-phase current)))
    (case operation
      ((offer-data)
       (if (and (eq? phase 'open)
                (< (+ data (if (eq? active 'data) 1 0))
                   (scheduling-frame-data-capacity current)))
         (values (next-frame current (+ data 1) controls active burst phase) #t 'idle)
         (values current #f 'idle)))
      ((offer-control)
       (if (and (eq? phase 'open)
                (< (+ controls (if (eq? active 'control) 1 0))
                   (scheduling-frame-control-capacity current)))
         (values (next-frame current data (+ controls 1) active burst phase) #t 'idle)
         (values current #f 'idle)))
      ((dispatch)
       (cond
         ((or (eq? phase 'closed) (not (eq? active 'idle))) (values current #f 'idle))
         ((and (> controls 0)
               (or (= data 0) (< burst (scheduling-frame-burst-limit current))))
          (values (next-frame current data (- controls 1) 'control
                    (min (+ burst 1) (scheduling-frame-burst-limit current)) phase) #t 'control))
         ((> data 0)
          (values (next-frame current (- data 1) controls 'data 0 phase) #t 'data))
         (else (values current #f 'idle))))
      ((complete)
       (if (eq? active 'idle) (values current #f 'idle)
         (values (next-frame current data controls 'idle burst phase) #t 'idle)))
      ((drain)
       (if (eq? phase 'open)
         (values (next-frame current data controls active burst 'draining) #t 'idle)
         (values current #f 'idle)))
      ((close)
       (if (and (eq? phase 'draining) (= data 0) (= controls 0) (eq? active 'idle))
         (values (next-frame current 0 0 'idle burst 'closed) #t 'idle)
         (values current #f 'idle)))
      ((idle) (values current #f 'idle))
      (else (error "Unknown private scheduling transition" operation)))))
