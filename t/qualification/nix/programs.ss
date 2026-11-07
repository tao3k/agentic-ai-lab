;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Lab owns its qualification executable; Core issues only candidate libraries.
(import (only-in :clan/poo/object .o .cc)
        (only-in :yuanxu/ops/config Config))
(export nix-publication-programs)
(def (nix-publication-programs root-value)
  (def vm-options
    (string-append "-:max-heap=" (getenv "GERBIL_TEST_MAX_HEAP" "2G") ",debug=q"))
  (def tool (path-expand "bin/build-publication-tools" (gerbil-path)))
  (.o .worker:
      (lambda arguments
        (.cc Config directory: root-value timeout: 300
          command: (append
            (list tool vm-options "worker")
            arguments)))
      .producer:
      (lambda (role . arguments)
        (unless (member role '("approved" "store"))
          (error "unknown publication qualification role" role))
        (.cc Config
          directory: (if (string=? role "store") (path-expand "core" root-value) root-value)
          timeout: 300
          command: (append
            (list tool vm-options role)
            arguments)))))
