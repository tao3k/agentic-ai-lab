;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (only-in :yuanxu/object-types/contracts yuanxu-predicate-contract))
(export ProviderBinaryRequestContract ProviderSourceRequestContract)

(def (slots-satisfy? value requirements)
  (and (object? value)
       (every (lambda (row)
                (and (.slot? value (car row)) ((cdr row) (.ref value (car row)))))
              requirements)))

(def ProviderBinaryRequestContract
  (yuanxu-predicate-contract 'opentofu/provider-binary
    (lambda (value)
      (slots-satisfy? value (list (cons 'selection object?) (cons 'path string?))))
    (lambda (_candidate _context) '())))

(def ProviderSourceRequestContract
  (yuanxu-predicate-contract 'opentofu/provider-source
    (lambda (value)
      (slots-satisfy? value
        (list (cons 'selection object?) (cons 'lock object?) (cons 'read procedure?))))
    (lambda (_candidate _context) '())))
