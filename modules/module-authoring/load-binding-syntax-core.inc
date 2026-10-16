;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Include-only compile-time helpers for load!/use-profile binding names.

(def (poo-flow-load-binding-string-prefix? prefix value)
  (let ((prefix-length (string-length prefix))
        (value-length (string-length value)))
    (and (>= value-length prefix-length)
         (string=? (substring value 0 prefix-length) prefix))))

(def (poo-flow-load-binding-path-segments value)
  (let ((length (string-length value)))
    (let loop ((index 0) (start 0) (segments '()))
      (cond
       ((= index length)
        (reverse (cons (substring value start index) segments)))
       ((char=? (string-ref value index) #\/)
        (loop (+ index 1)
              (+ index 1)
              (cons (substring value start index) segments)))
       (else
        (loop (+ index 1) start segments))))))

(def (poo-flow-load-binding-member-tail needle values)
  (let loop ((rest values))
    (cond
     ((null? rest) #f)
     ((equal? (car rest) needle) rest)
     (else (loop (cdr rest))))))

(def (poo-flow-load-binding-module-context-source-path)
  (let* ((context-id
          (expander-context-id (current-expander-context)))
         (context-name
          (and (symbol? context-id)
               (symbol->string context-id)))
         (package-prefix "poo-flow/"))
    (and context-name
         (let (relative-context-name
               (if (poo-flow-load-binding-string-prefix? package-prefix
                                                         context-name)
                 (substring context-name
                            (string-length package-prefix)
                            (string-length context-name))
                 context-name))
           (string-append relative-context-name ".ss")))))

(def (poo-flow-load-binding-current-custom-module-name)
  (let* ((context-source-path
          (poo-flow-load-binding-module-context-source-path))
         (source-segments
          (if context-source-path
            (poo-flow-load-binding-path-segments context-source-path)
            []))
         (custom-tail
          (poo-flow-load-binding-member-tail "custom" source-segments)))
    (if (and custom-tail (pair? (cdr custom-tail)))
      (cadr custom-tail)
      "module")))

(def (poo-flow-load-binding-fragment-name custom-module-name
                                          load-name
                                          case-fragment?)
  (string->symbol
   (string-append "poo-flow-custom-"
                  custom-module-name
                  "-"
                  load-name
                  (if case-fragment? "-case" "-module"))))

(def (poo-flow-load-binding-profile-module-syntax ctx profile-name)
  (let (profile-key (syntax->datum profile-name))
    (unless (symbol? profile-key)
      (error "profile binding expects a symbolic profile fragment name"
             profile-name))
    (datum->syntax
     ctx
     (poo-flow-load-binding-fragment-name
      (poo-flow-load-binding-current-custom-module-name)
      (symbol->string profile-key)
      #f))))
