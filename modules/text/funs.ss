;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: WordCount tutorial alignment lives in this module.
;;; Boundary: core provides descriptor, strategy, runner, and adapter protocols.
;;; Import contract: users opt in through the module config/interface exports.
;;; Runtime contract: this module emits WordCount task data only.
;;; Runtime contract: parsing, counting, and formatting stay local and deterministic.
;;; Runtime contract: file IO remains caller/runtime-owned.
;;; Policy evidence: tests should assert parsing, formatting, and task flow result.

(import (only-in :clan/poo/mop Function)
        (only-in :yuanxu/modules/funflow/control-plane/task
                 make-task-family-descriptor task-family-registry-extend
                 default-task-family-registry make-task task-kind
                 task-request-operation task-request-payload)
        (only-in :yuanxu/modules/funflow/control-plane/strategy
                 make-strategy strategy-name strategy-capabilities
                 strategy-cache-policy strategy-failure-policy strategy-planner
                 make-local-eager-strategy)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-adapter make-request-only-adapter)
        (only-in :yuanxu/modules/funflow/control-plane/config make-run-config)
        (only-in :yuanxu/modules/funflow/control-plane/flow
                 default-flow-declaration-registry task-flow)
        :yuanxu/modules/funflow/control-plane/projection-syntax)

(export text-task-family-descriptor
        make-text-task-family-registry
        text-enable-strategy
        make-text-enabled-strategy
        make-text-run-config
        text->words
        word-counts
        word-count-ref
        sort-word-counts-desc
        format-word-counts
        word-count-summary
        make-word-count-task
        task-text-operation
        task-text-payload
        task-text-word-count?
        word-count-flow)

;; : (-> Unit TaskFamilyDescriptor)
(def text-task-family-descriptor
  (make-task-family-descriptor 'text 'text 'local 'gerbil #f))

;;; Boundary:
;;; - Registry module extension is immutable.
;;; - Callers may pass a base registry or use the core default.
;; : (-> [TaskFamilyRegistry] TaskFamilyRegistry)
(def (make-text-task-family-registry . maybe-registry)
  (task-family-registry-extend
   (if (null? maybe-registry) default-task-family-registry (car maybe-registry))
   text-task-family-descriptor))

;;; Invariant:
;;; - Capability lists stay set-like.
;;; - Existing capabilities keep their original order.
;; : (forall (a) (-> [a] [a] [a]))
(def (text-values/tail values tail)
  (foldr cons tail values))

;; : (-> [Symbol] Symbol [Symbol])
(def (capabilities-with capability-set capability)
  (if (memq capability capability-set)
    capability-set
    (text-values/tail capability-set (list capability))))

;;; Boundary:
;;; - Text capability is opt-in at the extension edge.
;;; - Core strategies stay unaware of WordCount parsing.
;; : (-> Strategy Strategy)
(def (text-enable-strategy strategy)
  (make-strategy (strategy-name strategy)
                 (capabilities-with (strategy-capabilities strategy) 'text)
                 (strategy-cache-policy strategy)
                 (strategy-failure-policy strategy)
                 (strategy-planner strategy)))

;;; Boundary:
;;; - Default text strategy starts from core local eager policy.
;;; - Extension capability is added only through =text-enable-strategy=.
;; : (-> Unit Strategy)
(def (make-text-enabled-strategy)
  (text-enable-strategy (make-local-eager-strategy)))

;;; Boundary:
;;; - Text workflows run locally through an opt-in registry.
;;; - File reads and writes stay outside this extension.
;; : (-> [Alist] RunConfig)
(def (make-text-run-config . maybe-options)
  (let (options (if (null? maybe-options) '() (car maybe-options)))
    (make-run-config 'text-local
                     (make-text-enabled-strategy)
                     (make-request-only-adapter)
                     (yuanxu-product-field-rows/tail
                      options
                      (runtime 'gerbil)
                      (extension 'text))
                     (make-text-task-family-registry)
                     default-flow-declaration-registry)))

;;; Boundary:
;;; - This predicate owns the tutorial punctuation set.
;;; - Token scanning decides whether punctuation separates or disappears.
;; : (-> Char Boolean)
(def (punctuation-char? char)
  (or (char=? char #\,)
      (char=? char #\.)
      (char=? char #\?)
      (char=? char #\!)
      (char=? char #\:)
      (char=? char #\;)
      (char=? char #\")
      (char=? char #\')))

;;; Boundary:
;;; - This predicate owns whitespace separation.
;;; - Punctuation handling remains separate.
;; : (-> Char Boolean)
(def (separator-char? char)
  (or (char=? char #\space)
      (char=? char #\newline)
      (char=? char #\tab)
      (char=? char #\return)))

;;; Boundary:
;;; - Character range checks are ASCII-only for tutorial word filtering.
;;; - Unicode token policy is intentionally outside this extension.
;; : (-> Char Char Char Boolean)
(def (char-between? char lower upper)
  (and (char>=? char lower)
       (char<=? char upper)))

;;; Boundary:
;;; - Word-character policy is limited to latin letters and hyphen.
;;; - This matches the notebook regex instead of locale-aware parsing.
;; : (-> Char Boolean)
(def (latin-word-char? char)
  (or (char-between? char #\A #\Z)
      (char-between? char #\a #\z)
      (char=? char #\-)))

;;; Boundary:
;;; - Whole-word validation delegates to character policy.
;;; - Scanner behavior remains separate from validity rules.
;; : (-> String Boolean)
(def (latin-word? word)
  (latin-word-chars? (string->list word)))

;;; Invariant:
;;; - Empty character lists are valid after a word has been built.
;;; - Invalid characters reject the whole candidate word.
;; : (-> [Char] Boolean)
(def (latin-word-chars? chars)
  (cond
   ((null? chars) #t)
   ((latin-word-char? (car chars))
    (latin-word-chars? (cdr chars)))
   (else #f)))

;;; Boundary:
;;; - Tokenization is pure extension logic.
;;; - Flow execution stays in the text task wrapper.
;; : (-> String [String])
(def (text->words text)
  (scan-word-chars (string->list text) '() '()))

;;; Invariant:
;;; - Punctuation is removed rather than used as a separator.
;;; - =WordCount.hs= becomes =WordCounths= before word filtering.
;; : (-> [Char] [Char] [String] [String])
(def (scan-word-chars chars current words)
  (cond
   ((null? chars)
    (reverse (finish-word current words)))
   ((punctuation-char? (car chars))
    (scan-word-chars (cdr chars) current words))
   ((separator-char? (car chars))
    (scan-word-chars (cdr chars) '() (finish-word current words)))
   (else
    (scan-word-chars (cdr chars) (cons (car chars) current) words))))

;;; Invariant:
;;; - Empty current buffers do not create words.
;;; - Non-latin tokens are dropped before counting.
;; : (-> [Char] [String] [String])
(def (finish-word current words)
  (if (null? current)
    words
    (let (word (list->string (reverse current)))
      (if (latin-word? word)
        (cons word words)
        words))))

;;; Boundary:
;;; - Counting is reusable pure text logic.
;;; - =word-count-flow= remains the workflow constructor.
;; : (-> String [TextCount])
(def (word-counts text)
  (count-words (text->words text) '()))

;;; Invariant:
;;; - Counting preserves first-seen entry order for equal frequencies.
;;; - Later sorting only compares counts.
;; : (-> [String] [TextCount] [TextCount])
(def (count-words words counts)
  (if (null? words)
    counts
    (count-words (cdr words)
                 (increment-word-count (car words) counts))))

;; : (-> String Nat TextCount)
(def (text-count-entry word count)
  (cons word count))

;;; Invariant:
;;; - Existing word entries are updated in place in the logical alist.
;;; - New words are appended at the current traversal point.
;; : (-> String [TextCount] [TextCount])
(def (increment-word-count word counts)
  (cond
   ((null? counts) (list (text-count-entry word 1)))
   ((equal? word (caar counts))
    (cons (text-count-entry word (+ 1 (cdar counts)))
          (cdr counts)))
   (else
    (cons (car counts)
          (increment-word-count word (cdr counts))))))

;;; Boundary:
;;; - Count lookup is test-facing read access.
;;; - Missing words return zero instead of raising.
;; : (-> [TextCount] String Nat)
(def (word-count-ref counts word)
  (cond
   ((null? counts) 0)
   ((equal? word (caar counts)) (cdar counts))
   (else (word-count-ref (cdr counts) word))))

;;; Boundary:
;;; - Sorting is count-only presentation policy.
;;; - Counting remains independent from output order.
;; : (-> [TextCount] [TextCount])
(def (sort-word-counts-desc counts)
  (if (null? counts)
    '()
    (insert-word-count-desc (car counts)
                            (sort-word-counts-desc (cdr counts)))))

;;; Invariant:
;;; - Equal-count entries preserve existing order.
;;; - No alphabetical tiebreaker is added beyond the tutorial behavior.
;; : (-> TextCount [TextCount] [TextCount])
(def (insert-word-count-desc entry counts)
  (cond
   ((null? counts) (list entry))
   ((> (cdr entry) (cdar counts))
    (cons entry counts))
   (else
    (cons (car counts)
          (insert-word-count-desc entry (cdr counts))))))

;;; Boundary:
;;; - Formatting is presentation logic for the notebook surface.
;;; - Counting and sorting stay separately testable.
;; : (-> [TextCount] [String] [String])
(def (format-word-counts/rev counts lines-rev)
  (if (null? counts)
    lines-rev
    (format-word-counts/rev
     (cdr counts)
     (cons (string-append (caar counts)
                          ": "
                          (number->string (cdar counts)))
           lines-rev))))

;; : (-> [TextCount] [String])
(def (format-word-counts counts)
  (reverse (format-word-counts/rev (sort-word-counts-desc counts) '())))

;;; Boundary:
;;; - This is the notebook-visible print surface.
;;; - Callers own file IO and persistence of the summary text.
;; : (-> String String)
(def (word-count-summary text)
  (join-lines (format-word-counts (word-counts text))))

;;; Boundary:
;;; - Joining owns only the printable text surface.
;;; - Line construction remains in =format-word-counts=.
;; : (-> [String] String)
(def (join-lines lines)
  (cond
   ((null? lines) "")
   ((null? (cdr lines)) (car lines))
   (else
    (string-append (car lines)
                   "\n"
                   (join-lines (cdr lines))))))

;;; Boundary:
;;; - Operation access is limited to text tasks.
;;; - Non-text tasks project to =#f= for descriptor probes.
;; : (-> Task (U Symbol #f))
(def (task-text-operation task)
  (if (eq? (task-kind task) 'text)
    (task-request-operation task)
    #f))

;;; Boundary:
;;; - Payload access is limited to text tasks.
;;; - Non-text tasks project to =#f= for descriptor probes.
;; : (-> Task (U Payload #f))
(def (task-text-payload task)
  (if (eq? (task-kind task) 'text)
    (task-request-payload task)
    #f))

;;; Boundary:
;;; - WordCount detection is descriptor-level policy.
;;; - Execution still belongs to the text task executor.
;; : (-> Task Boolean)
(def (task-text-word-count? task)
  (eq? (task-text-operation task) 'word-count))

;;; Boundary:
;;; - Text task request data records the WordCount operation.
;;; - The executor stays the pure =word-count-summary= pipeline.
;; : (-> Symbol Contract Contract Task)
(def (make-word-count-task name input-contract output-contract)
  (make-task name
             'text
             (list 'text 'word-count '((format . lines)))
             (Function (list output-contract) (list input-contract))
             word-count-summary))

;;; Boundary:
;;; - Public workflow construction hides the task record shape.
;;; - Descriptor tests can still inspect the underlying task via flow steps.
;; : (-> Symbol Contract Contract Flow)
(def (word-count-flow name input-contract output-contract)
  (task-flow name
             (make-word-count-task name input-contract output-contract)))
