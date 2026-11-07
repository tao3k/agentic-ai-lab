;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Compatibility floor is distinct from the resolved qualification lock.
(import (only-in :std/text/pregexp pregexp-match))
(export minimum-version supported-version?)
(def minimum-version '(2 34))
(def (supported-version? version)
  (and (string? version)
    (let (parts (pregexp-match "^([0-9]+)[.]([0-9]+)([.][0-9]+)?([+].*)?$" version))
      (and parts
        (let compare ((actual (map string->number (take (cdr parts) 2)))
                      (minimum minimum-version))
          (cond ((null? actual) #t)
                ((> (car actual) (car minimum)) #t)
                ((< (car actual) (car minimum)) #f)
                (else (compare (cdr actual) (cdr minimum)))))))))
