;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; ABI-only inert datum projection. Public semantic owners remain POO-native.
(import (only-in :gerbil/core call-with-output-string)
        (only-in :std/text/pregexp pregexp pregexp-match))
(export scheme-wire-read scheme-wire-write)

(def +wire-number-pattern+ (pregexp "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$"))

;; Validate the lexical subset before invoking Scheme read: no reader extensions,
;; quote, evaluation, shared/cyclic datum labels, comments or interned user symbols.
(def (wire-lexical-check text)
  (let ((size (string-length text)))
    (let loop ((i 0) (depth 0) (quoted #f) (escape #f) (nodes 0))
      (when (> nodes 262144) (error "Scheme datum node bound"))
      (if (= i size)
        (unless (and (= depth 0) (not quoted)) (error "truncated Scheme datum"))
        (let (c (string-ref text i))
          (cond
           (quoted
            (cond
             (escape
              (unless (memv c '(#\n #\r #\t #\" #\\)) (error "unsupported string escape"))
              (loop (+ i 1) depth #t #f nodes))
             ((char=? c #\\) (loop (+ i 1) depth #t #t nodes))
             ((char=? c #\") (loop (+ i 1) depth #f #f nodes))
             ((< (char->integer c) 32) (error "unescaped control"))
             (else (loop (+ i 1) depth #t #f nodes))))
           ((memv c '(#\space #\newline #\return #\tab))
            (loop (+ i 1) depth #f #f nodes))
           ((char=? c #\") (loop (+ i 1) depth #t #f (+ nodes 1)))
           ((char=? c #\()
            (when (>= depth 64) (error "Scheme datum depth bound"))
            (loop (+ i 1) (+ depth 1) #f #f (+ nodes 1)))
           ((char=? c #\))
            (when (<= depth 0) (error "unexpected close"))
            (loop (+ i 1) (- depth 1) #f #f nodes))
           (else
            (let scan ((end i))
              (if (or (= end size)
                      (memv (string-ref text end)
                            '(#\space #\newline #\return #\tab #\( #\))))
                (let* ((atom (substring text i end))
                       (number (and (<= (string-length atom) 64)
                                    (pregexp-match +wire-number-pattern+ atom)
                                    (string->number atom))))
                  (unless (or (member atom '("object" "list" "null" "#t" "#f"))
                              (and number (real? number)
                                   (or (inexact? number) (<= (- (expt 2 127)) number (- (expt 2 127) 1)))
                                   (= number number)
                                   (not (= (abs number) +inf.0))
                                   (let digits ((j 0))
                                     (or (= j (string-length atom))
                                         (and (memv (string-ref atom j)
                                                    '(#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9 #\- #\+ #\. #\e #\E))
                                              (digits (+ j 1)))))))
                    (error "unsupported Scheme atom"))
                  (loop end depth #f #f (+ nodes 1)))
                (scan (+ end 1)))))))))))

(def (wire-decode value depth)
  (when (> depth 64) (error "Scheme datum depth bound"))
  (cond
   ((eq? value 'null) (void))
   ((or (string? value) (boolean? value) (number? value)) value)
   ((and (pair? value) (eq? (car value) 'list))
    (map (lambda (v) (wire-decode v (+ depth 1))) (cdr value)))
   ((and (pair? value) (eq? (car value) 'object))
    (let (result (make-hash-table))
      (for-each
       (lambda (entry)
         (unless (and (list? entry) (= (length entry) 2) (string? (car entry)))
           (error "invalid Scheme object field"))
         (when (hash-key? result (car entry)) (error "duplicate Scheme field"))
         (hash-put! result (car entry) (wire-decode (cadr entry) (+ depth 1))))
       (cdr value))
      result))
   (else (error "invalid Scheme value"))))

(def (scheme-wire-read text)
  (wire-lexical-check text)
  (call-with-input-string text
    (lambda (port)
      (let (value (read port))
        (unless (eof-object? (read port)) (error "trailing Scheme datum"))
        (wire-decode value 0)))))

(def (scheme-wire-write value)
  (call-with-output-string
   (lambda (port)
     (def (emit value)
       (cond
        ((hash-table? value)
         (display "(object" port)
         (let (entries (hash->list value))
           (for-each
            (lambda (entry)
              (display " (" port)
              (write (if (symbol? (car entry)) (symbol->string (car entry)) (car entry)) port)
              (display " " port) (emit (cdr entry)) (display ")" port))
            (list-sort (lambda (a b)
                         (string<? (if (symbol? (car a)) (symbol->string (car a)) (car a))
                                   (if (symbol? (car b)) (symbol->string (car b)) (car b)))) entries)))
         (display ")" port))
        ((list? value)
         (display "(list" port)
         (for-each (lambda (v) (display " " port) (emit v)) value)
         (display ")" port))
        ((void? value) (display "null" port))
        ((or (string? value) (number? value) (boolean? value)) (write value port))
        (else (error "unsupported Scheme wire output"))))
     (emit value))))
