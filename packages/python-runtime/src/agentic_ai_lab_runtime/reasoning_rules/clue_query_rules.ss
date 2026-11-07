;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;; The caller keeps attested receipts separate from Agent-supplied clues.
;; These rules derive a local view; they neither admit receipts nor select work.
(def clue-input-schema
 (ascent-fragment
  (relation clue ((id string?) (digest string?) (claim string?)
                  (polarity string?) (role string?) (source string?)))
  (relation attested ((id string?) (digest string?) (receipt string?)))
  (relation factor ((id string?) (digest string?) (name string?) (value string?)))
  (relation link ((from string?) (to string?) (label string?)
                  (id string?) (digest string?)))))

;; Schema only: the caller supplies every association and question rule.
(def clue-selection-schema
 (ascent-fragment
  (include clue-input-schema)
  (relation binding ((name string?) (value string?)))))

(def clue-query-fragment
 (ascent-fragment
  (include clue-input-schema)
  (relation question ((claim string?)))
  (relation support ((claim string?) (id string?) (digest string?)
                     (source string?) (receipt string?)))
  (relation counterevidence ((claim string?) (id string?) (digest string?)
                             (source string?) (receipt string?)))
  (relation conditional ((claim string?) (id string?) (digest string?)
                         (polarity string?) (source string?)))
  (relation relevant_factor ((claim string?) (id string?) (digest string?)
                             (name string?) (value string?) (role string?)))
  (relation neighbor ((claim string?) (other string?) (label string?)
                      (id string?) (digest string?) (polarity string?)
                      (receipt string?)))
  (relation has_support ((claim string?)))
  (relation has_counter ((claim string?)))
  (relation conflict ((claim string?)))
  (relation unknown ((claim string?)))
  ((support C I D S R) <-- (question C)
    (clue I D C (lit "support") (lit "observation") S)
    (attested I D R))
  ((counterevidence C I D S R) <-- (question C)
    (clue I D C (lit "counter") (lit "observation") S)
    (attested I D R))
  ((conditional C I D P S) <-- (question C)
    (clue I D C P (lit "hypothesis") S))
  ((relevant_factor C I D N V Role) <-- (question C)
    (clue I D C P Role S) (factor I D N V))
  ((neighbor C Other Label I D P R) <-- (question C)
    (link C Other Label I D) (clue I D C P (lit "observation") S)
    (attested I D R))
  ((has_support C) <-- (support C I D S R))
  ((has_counter C) <-- (counterevidence C I D S R))
  ((conflict C) <-- (has_support C) (has_counter C))
  ((unknown C) <-- (question C) (not (has_support C))
    (not (has_counter C)))))

(define-program (make-clue-query-evidence)
 (sources clue attested factor question link)
 (outputs support counterevidence conditional relevant_factor neighbor conflict unknown)
 (include clue-query-fragment))

;; Logical set deltas are derived here, never by the Python transport.
(define-program (make-clue-slice-evidence)
 (sources clue attested factor question link previous)
 (outputs item added removed retained changed)
 (include clue-query-fragment)
 (relation item (kind claim id digest a b c d))
 (relation previous (kind claim id digest a b c d))
 (relation scoped_previous (kind claim id digest a b c d))
 (relation added (kind claim id digest a b c d))
 (relation removed (kind claim id digest a b c d))
 (relation retained (kind claim id digest a b c d))
 (relation changed (claim))
 ((item (lit "support") C I D S R (lit "") (lit "")) <-- (support C I D S R))
 ((item (lit "counter") C I D S R (lit "") (lit "")) <-- (counterevidence C I D S R))
 ((item (lit "hypothesis") C I D P S (lit "") (lit "")) <-- (conditional C I D P S))
 ((item (lit "factor") C I D N V Role (lit "")) <-- (relevant_factor C I D N V Role))
 ((item (lit "link") C I D Other Label P R) <-- (neighbor C Other Label I D P R))
 ((item (lit "conflict") C (lit "") (lit "") (lit "") (lit "") (lit "") (lit "")) <-- (conflict C))
 ((item (lit "unknown") C (lit "") (lit "") (lit "") (lit "") (lit "") (lit "")) <-- (unknown C))
 ((added K C I D A B X Y) <-- (item K C I D A B X Y) (not (previous K C I D A B X Y)))
 ((scoped_previous K C I D A B X Y) <-- (previous K C I D A B X Y) (question C))
 ((removed K C I D A B X Y) <-- (scoped_previous K C I D A B X Y) (not (item K C I D A B X Y)))
 ((retained K C I D A B X Y) <-- (item K C I D A B X Y) (previous K C I D A B X Y))
 ((changed C) <-- (added _ C _ _ _ _ _ _))
 ((changed C) <-- (removed _ C _ _ _ _ _ _)))

;; Only full displayed families acknowledge details. Scope changes are not
;; retractions: retain other same-source reads without admitting new evidence.
(define-program (make-clue-read-acknowledgement)
 (sources previous item shown previous_relation relation_item shown_relation)
 (outputs acknowledged acknowledged_relation pending_relation retained_relation)
 (relation previous (kind claim id digest a b c d))
 (relation item (kind claim id digest a b c d))
 (relation shown (claim))
 (relation acknowledged (kind claim id digest a b c d))
 (relation previous_relation (selector name digest))
 (relation relation_item (selector name digest))
 (relation shown_relation (selector name digest))
 (relation acknowledged_relation (selector name digest))
 (relation pending_relation (selector name digest))
 (relation retained_relation (selector name digest))
 ((acknowledged K C I D A B X Y) <--
   (previous K C I D A B X Y) (not (shown C)))
 ((acknowledged K C I D A B X Y) <--
   (item K C I D A B X Y) (shown C))
 ((acknowledged_relation S N D) <-- (previous_relation S N D))
 ((acknowledged_relation S N D) <-- (shown_relation S N D))
 ((pending_relation S N D) <-- (relation_item S N D) (not (previous_relation S N D)))
 ((retained_relation S N D) <-- (relation_item S N D) (previous_relation S N D)))
