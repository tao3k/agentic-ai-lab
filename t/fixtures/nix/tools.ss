;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Producer roles retain their caller-owned source capability.
(import (rename-in (only-in "./worker.ss" main)
                   (main publication-worker))
        (rename-in (only-in "./store-producer.ss" main)
                   (main store-producer))
        (rename-in (only-in "./approved-producer.ss" main)
                   (main approved-producer)))
(export main)
(def (main role . arguments)
    (apply (case (string->symbol role)
             ((store)
              (lambda (workspace)
                (store-producer workspace (list (car (command-line))))))
             ((worker) publication-worker)
             ((approved) approved-producer)
             (else (error "unknown publication qualification role" role)))
           arguments))
