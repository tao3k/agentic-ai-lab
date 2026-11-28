;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Live regression test for Yuanxu Design 165 on real `agentic-ai-lab/init.ss`:
;;; - Pure `durable` alone loads zero Context/Org code (INV-1)
;;; - `ai-agentic-context` alone keeps directory Feature `features/durable` cold (INV-1 + INV-6)
;;; - `durable` + `ai-agentic-context` auto-bridges `ai-agentic-context/durable` in Band 1
;;;   with auditable `ActivationReceipt` (`band: 'implied-bridge`, `observed-reads`)
;;; - Runtime-stage `.apply-runtime-overlay` triggers `Context`'s POO `.o` dispatch table
;;;   (`durable.detour-state: (.o blocker-active: ...)`) with zero closure expansion (INV-6)

(import :std/test
        (only-in :std/list/list find)
        (only-in :std/source this-source-file)
        (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :tao3k/yuanxu/module-system/interface yuanxu-load-modules))
(export context-durable-c4-auto-bridge-test)

(def lab-root
  (path-expand "../../../.." (path-directory (this-source-file))))
(def lab-init-path
  (path-expand "init.ss" lab-root))

(def context-durable-c4-auto-bridge-test
  (test-suite "Real agentic-ai-lab Design 165 Auto-Bridging & C4 Convergence"

    (test-case "Pure durable alone loads zero Context/Org modules and zero features"
      (let* ((v (yuanxu-load-modules lab-init-path
                  build-selection: (.o modules: '(modules/durable) mounts: '())))
             (g (.ref v 'selected-graph))
             (order (.ref g 'module-order)))
        (check (and (memq 'tao3k/agentic-ai-lab/modules/durable/interface order) #t) => #t)
        (check (memq 'tao3k/agentic-ai-lab/modules/ai-agentic-context/interface order) => #f)
        (check (.ref g 'feature-order) => '())))

    (test-case "ai-agentic-context alone keeps features/durable cold (INV-1 + INV-6)"
      (let* ((v (yuanxu-load-modules lab-init-path
                  build-selection: (.o modules: '(modules/ai-agentic-context) mounts: '())))
             (g (.ref v 'selected-graph))
             (ctx (.ref (.ref (.ref v 'modules) 'modules) 'ai-agentic-context)))
        (check (.ref g 'implied-features) => '())
        (check (.slot? ctx 'durable) => #f)))

    (test-case "durable + ai-agentic-context auto-bridges Band 1 and supports zero-recompile runtime overlay"
      (let* ((v (yuanxu-load-modules lab-init-path
                  build-selection: (.o modules: '(modules/durable modules/ai-agentic-context)
                                       mounts: '())))
             (g (.ref v 'selected-graph))
             (implied (.ref g 'implied-features))
             (receipts (.ref v 'activation-receipts))
             (bridge-r (find (lambda (r)
                               (and (eq? (.ref r 'band) 'implied-bridge)
                                    (eq? (.ref r 'activation) 'implied)))
                             receipts))
             (ctx (.ref (.ref (.ref v 'modules) 'modules) 'ai-agentic-context))
             (conv (.ref v 'convergence))
             (eff-ctx (.ref (.ref conv 'effective-configs)
                            'tao3k/agentic-ai-lab/modules/ai-agentic-context/interface)))
        (check (and (memq 'tao3k/agentic-ai-lab/modules/ai-agentic-context/interface/durable implied) #t) => #t)
        (check (object? bridge-r) => #t)
        (check (.ref bridge-r 'observed-reads)
               => '((tao3k/agentic-ai-lab/modules/durable/interface enabled? #t)))
        (check (.slot? ctx 'durable) => #t)
        (check (.ref conv 'status) => 'ready)
        (check (.ref conv 'diagnostics) => '())
        (check (.ref eff-ctx 'disclosure-mode) => 'progressive)
        ;; Runtime-stage overlay: durable.detour-state = blocker-active -> disclosure-mode = detour-blocker
        (let* ((rt ((.ref v '.apply-runtime-overlay)
                    conv
                    (list (cons 'durable (.o detour-state: 'blocker-active)))))
               (rt-ctx (.ref (.ref rt 'effective-configs)
                             'tao3k/agentic-ai-lab/modules/ai-agentic-context/interface)))
          (check (.ref rt 'status) => 'ready)
          (check (.ref rt 'diagnostics) => '())
          (check (.ref rt 'compiled-closure) => (.ref conv 'compiled-closure))
          (check (.ref rt-ctx 'disclosure-mode) => 'detour-blocker))))))
