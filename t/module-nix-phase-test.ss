;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in :agentic-ai-lab/modules/nix/objects NixSource.)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case))
(export module-nix-phase-test)
(def module-nix-phase-test
  (test-suite "Native Nix preparation is candidate-only and receiver-local"
    (yuanxu-test-case "preparation caches derivation, not currentness or authority"
      (let ((instantiations 0) (realizations 0) (current? #t))
        (def source
          (.cc NixSource. 'expression "unused.nix"
            '.instantiate (lambda () (set! instantiations (1+ instantiations)) "/nix/store/test.drv")
            '.realize (lambda (_drv) (set! realizations (1+ realizations)) "/nix/store/test")))
        (def (current!) (unless current? (error "stale phase")))
        (def parent (.call source .prepare current!))
        (check-equal? instantiations 0)
        (check-equal? realizations 0)
        (check-equal? (.get parent derivation) "/nix/store/test.drv")
        (check-equal? (.get parent derivation) "/nix/store/test.drv")
        (check-equal? instantiations 1)
        (check-equal? realizations 0)
        ;; An already-prepared candidate cannot realize after source invalidation.
        (set! current? #f)
        (check-exception ((.get parent admit-current)) error?)
        (check-equal? realizations 0)
        ;; A fresh receiver owns a distinct lazy realization. Never reuse the
        ;; parent's candidate/cache when a later generation is prepared.
        (set! current? #t)
        (let (child (.call source .prepare current!))
          (check-equal? (.get child artifact) "/nix/store/test")
          (check-equal? (.get child artifact) "/nix/store/test")
          (check-equal? instantiations 2)
          (check-equal? realizations 1)
          (check-equal? (.get parent derivation) "/nix/store/test.drv"))
        ;; The standalone eager API still rejects mutation during realization.
        (def mutating (.cc source '.realize
                        (lambda (_drv) (set! current? #f) "/nix/store/test")))
        (check-exception (.call mutating .build current!) error?)))))
