;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Isolate the original Gambit object loader from suite discovery and POO data.
(import (only-in :gerbil/expander import-module))
(def (main path mode)
  (unless (or (equal? mode "import")
              (and (file-exists? path) (equal? (path-extension path) ".o1")))
    (error "native object probe requires an existing .o1 artifact" path))
  (displayln "NATIVE-OBJECT-LOAD-START " path)
  (force-output)
  (cond
    ((equal? mode "import") (import-module (string->symbol path)))
    ((equal? mode "map")
     ;; Original Gambit mapping returns descriptors without running Scheme
     ;; initializers, so it does not require this module's live dependencies.
     (let (descriptor (##load-object-file path (path-strip-directory path) #t))
       (unless (vector? descriptor) (error "native mapping refused" descriptor))))
    ((equal? mode "load") (load path))
    (else (error "native object probe mode must be map, load, or import" mode)))
  (displayln "NATIVE-OBJECT-LOAD-OK " path)
  (force-output))
