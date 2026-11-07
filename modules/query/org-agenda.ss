;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (only-in :std/list/list find filter-map)
        :orgize/languages/org/modules/org-elements/source-interface
        "semantic/orgize-interface.ss")
(export org-agenda-occurrences)

(def (field record key) (org-source-element-field record key))
(def (part record key)
  (let (values (field record key))
    (and (pair? values) (null? (cdr values)) (string->number (car values)))))

;; Orgize owns parsing. Convert its single local timestamp with the host's
;; admitted offset. Ambiguous, recurring and date-only entries stay unarmed.
(def (due timestamp offset)
  (let ((year (part timestamp "year")) (month (part timestamp "month"))
        (day (part timestamp "day")) (hour (part timestamp "hour"))
        (minute (part timestamp "minute")))
    (def (leaps y) (- (+ (quotient y 4) (quotient y 400)) (quotient y 100)))
    (and (not (field timestamp "repeater")) (not (field timestamp "range-separator"))
         (not (field timestamp "time-range-separator")) (not (field timestamp "delay"))
         (andmap exact-integer? (list year month day hour minute))
         (<= 1970 year 9999) (<= 1 month 12) (<= 0 hour 23) (<= 0 minute 59)
         (let* ((lengths (list 31 (+ 28 (- (leaps year) (leaps (- year 1))))
                               31 30 31 30 31 31 30 31 30 31))
                (before-month (let loop ((left (- month 1)) (days lengths) (sum 0))
                                (if (zero? left) sum
                                  (loop (- left 1) (cdr days) (+ sum (car days)))))))
           (and (<= 1 day (list-ref lengths (- month 1)))
                (- (+ (* 86400 (+ (* (- year 1970) 365)
                                   (- (leaps (- year 1)) (leaps 1969)) before-month (- day 1)))
                      (* 3600 hour) (* 60 minute))
                   (* 60 offset)))))))

(def (org-agenda-occurrences source offset)
  (let* ((graph (org-source-element-graph source))
         (context (make-org-element-query-context graph))
         (headlines (org-element-select (make-org-element-query "headline") context 0 '(0)))
         (plans (org-element-select (make-org-element-query "planning") context 0 '(0)))
         (timestamps (org-element-select (make-org-element-query "timestamp") context 0 '(0)))
         (ids (make-hash-table)))
    (for-each (lambda (row)
      (let (id (field row "property:ID"))
        (when id
          (when (hash-get ids id) (error "Duplicate Org agenda ID" id))
          (hash-put! ids id #t)))) headlines)
    (filter-map
     (lambda (plan)
       (let* ((row (find (lambda (headline) (equal? (.ref headline 'id) (.ref plan 'parent))) headlines))
              (id (and row (field row "property:ID")))
              (children (list-sort (lambda (a b) (< (.ref a 'start) (.ref b 'start)))
                          (filter (lambda (x) (equal? (.ref x 'parent) (.ref plan 'id))) timestamps)))
              (keys (or (field plan "key") '()))
              (at (and (= (length keys) (length children))
                       (let loop ((keys keys) (children children))
                         (and (pair? keys)
                              (if (string-ci=? (car keys) "SCHEDULED") (due (car children) offset)
                                (loop (cdr keys) (cdr children))))))))
         (and id (equal? (org-element-property context row "todo-type") "todo") at
              (.o identity: id due: at))))
     plans)))
