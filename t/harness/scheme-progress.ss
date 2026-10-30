;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Report distinct completed Scheme preparation work.
;;; Installed Scheme still owns resolution and admission.
(def poo-original-load-module load-module)
(def poo-reported-loads (make-hash-table))
(set! load-module
 (lambda (path)
   (let (result (poo-original-load-module path))
     (unless (hash-get poo-reported-loads path)
       (hash-put! poo-reported-loads path #t)
       (displayln "poo-test: module loaded " path)
       (force-output))
     result)))

;;; Metadata expansion is real preparation work before runtime modules load.
;;; Report each completed import once; retain the installed expander callback.
(def poo-original-import (gx#current-expander-module-import))
(def poo-reported-imports (make-hash-table))
(gx#current-expander-module-import
 (lambda (path reload?)
   (let ((context (poo-original-import path reload?))
         (identity (gx#stx-e path)))
     (unless (hash-get poo-reported-imports identity)
       (hash-put! poo-reported-imports identity #t)
       (displayln "poo-test: import completed " identity)
       (force-output))
     context)))
