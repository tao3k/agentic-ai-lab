;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; POO program capabilities and ordinary Ops values for the existing Fixtures.
;;; Admission belongs to each build demand; this owner launches no process.
(import (only-in :clan/poo/object .o .cc .get .call)
        (only-in :yuanxu/ops/config Config)
        (only-in :yuanxu/module-system/building/test-projection module-test-source-binding)
        (only-in "../../../build-spec.ss"
          agentic-ai-lab-nix-worker-demand agentic-ai-lab-nix-producer-demand
          agentic-ai-lab-nix-program-consumer))
(export nix-publication-programs)
(def (nix-publication-programs root-value)
  (.o (:: self [])
      worker-demand:
      (let (exports (module-test-source-binding (path-expand "core/init.ss" root-value)
                                               'yuanxu.init.exports))
        (agentic-ai-lab-nix-program-consumer exports (agentic-ai-lab-nix-worker-demand exports root-value)
          (path-expand "core/t/qualification/build-publication/worker.ss" root-value)))
      producer-demand:
      (let (exports (module-test-source-binding (path-expand "init.ss" root-value)
                                               'agentic-ai-lab.init.exports))
        (agentic-ai-lab-nix-program-consumer exports (agentic-ai-lab-nix-producer-demand exports root-value)
          (path-expand "t/qualification/nix/tools.ss" root-value)))
      .worker:
      (lambda arguments
        (.cc Config directory: root-value timeout: 120
          command: (append
            (list (.call (.get self worker-demand build) .program
                    'yuanxu/t/qualification/build-publication/worker)
                  "-:max-heap=2G,debug=q") arguments)))
      .producer:
      (lambda (role . arguments)
        (.cc Config
          directory: (if (string=? role "store") (path-expand "core" root-value) root-value)
          timeout: 120
          command: (append
            (list (.call (.get self producer-demand build) .program
                    'agentic-ai-lab/t/qualification/nix/tools)
                  "-:max-heap=2G,debug=q" role) arguments)))))
