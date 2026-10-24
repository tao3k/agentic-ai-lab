;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;;
;;; Return one inert (candidate ...) S-expression, with no prose or fence.
;;; The native tool will call reasoning-attempt on each source snapshot
;;; below, request finite/founded evidence, and return a receipt. If a
;;; receipt is returned, you may submit one corrected candidate.
;;;
;;; Public candidate contract:
;;;   (candidate
;;;     (relation NAME ARITY) ...
;;;     (rule (HEAD ARG ...) (BODY ARG ...) ...)
;;;     (query RELATION ARG ...)
;;;     (limits MAX-INPUT-FACTS MAX-DERIVED-FACTS MAX-OUTPUT-FACTS))
;;; Each limit is a positive integer, at most 1024, 4096, 4096
;;; respectively. (limits 16 64 128) is sufficient for these sources.
;;; BODY terms may include (not (RELATION ...)), (where (even? ?w)),
;;; (compute ?v (+ ?w ?w)), and
;;; (reduce ?n (count) (RELATION ?r ?v)).
;;; Variables start with ?. Rules form a fixed point; lower-stratum
;;; negation filters existing path rows, and count uses distinct rows.
;;; Source relations edge, blocked, weight, and root are already declared
;;; by each snapshot. Declare only the new derived relations in the
;;; candidate; redeclaring a source relation is rejected by admission.
;;; A complete native receipt is bound to its source generation and
;;; candidate. A prior receipt must fail on a changed source.
;;;
;;; Define path as transitive closure of edge. Define allowed as path
;;; excluding blocked pairs. Define weighted (?x ?v) by joining allowed
;;; (?x ?y) with weight (?y ?w), requiring even ?w, then computing
;;; ?v = ?w + ?w. Define summary (?r ?n) by counting the distinct
;;; weighted rows for each root ?r. Query (summary 1 ?n).

(def sources
  '((blocked 1
      ((edge 2 ((1 2) (2 3)))
       (blocked 2 ((1 3)))
       (weight 2 ((2 4) (3 6)))
       (root 1 ((1)))))
    (unblocked 2
      ((edge 2 ((1 2) (2 3)))
       (blocked 2 ())
       (weight 2 ((2 4) (3 6)))
       (root 1 ((1)))))
    (duplicate-edge 3
      ((edge 2 ((1 2) (1 2) (2 3)))
       (blocked 2 ())
       (weight 2 ((2 4) (3 6)))
       (root 1 ((1)))))))
