;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :poo-flow/modules/workflow/runtime/scheme-wire scheme-wire-read scheme-wire-write))
(export scheme-wire-test)
(def (rejects? text)
  (with-catch (lambda (_) #t) (lambda () (scheme-wire-read text) #f)))
(def scheme-wire-test
  (test-suite "Inert ABI v2 Scheme wire"
    (test-case "roundtrip and reader extension rejection"
      (let* ((text "(object (\"empty\" (list)) (\"flag\" #f) (\"unicode\" \"时态\"))")
             (value (scheme-wire-read text)))
        (check-equal? (hash-get value "empty") [])
        (check-equal? (hash-get value "flag") #f)
        (check-equal? (hash-get value "unicode") "时态")
        (check-equal? (scheme-wire-write value) text))
      (for-each (lambda (text) (check-equal? (rejects? text) #t))
        '("{}" "#.(exit)" "#0=(list #0#)" "(object (\"a\" 1) (\"a\" 2))"
          "(list) (list)" "(list +inf.0)" "(list . (list))" "'hello")))))
