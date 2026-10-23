;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: declarative fixture generator for composition expansion gates.

(import (only-in :clan/poo/object .def)
        :yuanxu/profile-composition/selection-syntax
        :agentic-ai-lab/modules/workflow/scenario/composition-syntax
        (only-in :yuanxu/profile-composition/profile-bundle
                 compose profiles)
        (for-syntax
         (only-in :gerbil/core/expander stx-identifier)))

(export define-composition-expansion-case)

(begin-syntax
  ;; : (-> Syntax String Fixnum [Syntax])
  (def (composition-benchmark-identifiers template prefix count)
    (let loop ((index 0) (out '()))
      (if (= index count)
        (reverse out)
        (loop
         (fx1+ index)
         (cons (stx-identifier template prefix index) out))))))

;;; Emit COUNT real native POO Profile values and one thin user-composition
;;; binding.  The benchmark measures the production value-level path, not the
;;; removed clause parser.
(defsyntax (define-composition-expansion-case stx)
  (syntax-case stx ()
    ((_ binding count)
     (let (profile-count (syntax->datum #'count))
       (unless (and (fixnum? profile-count) (fx> profile-count 0))
         (raise-syntax-error
          #f
          "composition benchmark count must be a positive fixnum"
          #'count))
       (let (profile-identifiers
             (composition-benchmark-identifiers
              #'binding "profile-" profile-count))
         (with-syntax (((profile-name ...) profile-identifiers))
           #'(begin
               (.def profile-name (identity 'profile-name)) ...
               (user-composition binding
                 (compose profiles profile-name ...)))))))))
