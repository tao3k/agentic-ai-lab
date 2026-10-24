;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure partial comparison. Unknown means evidence is declared rather than
;;; observed; incomparable means distinct clock domains without conversion.
(import (only-in :clan/poo/object .ref)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types
                 agentic-ai-lab-temporal-instant? agentic-ai-lab-temporal-interval?))

(export agentic-ai-lab-temporal-compare agentic-ai-lab-temporal-interval-contains?
        agentic-ai-lab-temporal-interval-extent-relation)

(def (agentic-ai-lab-temporal-compare left right)
  (unless (and (agentic-ai-lab-temporal-instant? left)
               (agentic-ai-lab-temporal-instant? right))
    (error "temporal comparison requires two instants"))
  (cond
   ((not (equal? (.ref left 'domain-identity)
                 (.ref right 'domain-identity))) 'incomparable)
   ((not (and (eq? (.ref left 'modality) 'observed)
              (eq? (.ref right 'modality) 'observed))) 'unknown)
   ((< (.ref left 'coordinate) (.ref right 'coordinate)) 'before)
   ((> (.ref left 'coordinate) (.ref right 'coordinate)) 'after)
   (else 'equal)))

(def (agentic-ai-lab-temporal-interval-contains? interval instant)
  (unless (and (agentic-ai-lab-temporal-interval? interval)
               (agentic-ai-lab-temporal-instant? instant))
    (error "interval membership requires an interval and instant"))
  (let ((start (.ref interval 'start)) (end (.ref interval 'end)))
    (cond
     ((not (equal? (.ref start 'domain-identity)
                   (.ref instant 'domain-identity))) 'incomparable)
     ((or (not (eq? (.ref start 'modality) 'observed))
          (not (eq? (.ref end 'modality) 'observed))
          (not (eq? (.ref instant 'modality) 'observed))) 'unknown)
     (else
      (let ((position (.ref instant 'coordinate))
            (lower (.ref start 'coordinate))
            (upper (.ref end 'coordinate)))
        (and (if (.ref interval 'start-closed?)
               (<= lower position) (< lower position))
             (if (.ref interval 'end-closed?)
               (<= position upper) (< position upper))))))))

;;; Allen's thirteen endpoint relations apply only to proper, observed
;;; intervals. Endpoint closure is a separate membership concern. A point or
;;; empty interval has no Allen extent and is reported as 'degenerate.
(def (agentic-ai-lab-temporal-interval-extent-relation left right)
  (unless (and (agentic-ai-lab-temporal-interval? left)
               (agentic-ai-lab-temporal-interval? right))
    (error "interval relation requires two intervals"))
  (let* ((left-start (.ref left 'start))
         (left-end (.ref left 'end))
         (right-start (.ref right 'start))
         (right-end (.ref right 'end)))
    (cond
     ((not (equal? (.ref left-start 'domain-identity)
                   (.ref right-start 'domain-identity))) 'incomparable)
     ((not (and (eq? (.ref left-start 'modality) 'observed)
                (eq? (.ref left-end 'modality) 'observed)
                (eq? (.ref right-start 'modality) 'observed)
                (eq? (.ref right-end 'modality) 'observed))) 'unknown)
     (else
      (let ((a (.ref left-start 'coordinate))
            (b (.ref left-end 'coordinate))
            (c (.ref right-start 'coordinate))
            (d (.ref right-end 'coordinate)))
        (cond
         ((or (= a b) (= c d)) 'degenerate)
         ((< a c)
          (cond ((< b c) 'before)
                ((= b c) 'meets)
                ((< b d) 'overlaps)
                ((= b d) 'finished-by)
                (else 'contains)))
         ((= a c)
          (cond ((< b d) 'starts)
                ((= b d) 'equal)
                (else 'started-by)))
         (else
          (cond ((> a d) 'after)
                ((= a d) 'met-by)
                ((< b d) 'during)
                ((= b d) 'finishes)
                (else 'overlapped-by)))))))))
