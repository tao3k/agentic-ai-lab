;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/workflow/qualification/release-version-matrix)


(def release-version-matrix-test
  (test-suite "AC-11 release version matrix"
    (poo-flow-test-case "current qualified owners bind without freezing ABI v1"
      (let* ((matrix (poo-flow-ac11-current-release-version-matrix))
             (receipt (poo-flow-ac11-release-version-matrix-verify matrix)))
        (check (poo-flow-release-version-matrix? matrix) => #t)
        (check (.ref receipt 'accepted?) => #t)
        (check (.ref receipt 'abi-v1-frozen?) => #f)
        (check (.ref receipt 'decision-required?) => #t)))
    (poo-flow-test-case "version drift fails closed"
      (let* ((current (poo-flow-ac11-current-release-version-matrix))
             (changed
              (poo-flow-release-version-matrix
               'poo-flow.organization-bundle.v1
               (poo-flow-release-version-matrix-runtime-abi current)
               (poo-flow-release-version-matrix-proof-vector current)
               (poo-flow-release-version-matrix-assurance-schema current)
               (poo-flow-release-version-matrix-owner-artifacts current)
               #f))
             (receipt (poo-flow-ac11-release-version-matrix-verify changed)))
        (check (.ref receipt 'accepted?) => #f)
        (check (.ref receipt 'diagnostics)
               => '(release-version-owner-drift))))
    (poo-flow-test-case "implicit ABI v1 freeze fails closed"
      (let* ((current (poo-flow-ac11-current-release-version-matrix))
             (frozen
              (poo-flow-release-version-matrix
               (poo-flow-release-version-matrix-bundle-schema current)
               (poo-flow-release-version-matrix-runtime-abi current)
               (poo-flow-release-version-matrix-proof-vector current)
               (poo-flow-release-version-matrix-assurance-schema current)
               (poo-flow-release-version-matrix-owner-artifacts current)
               #t))
             (receipt (poo-flow-ac11-release-version-matrix-verify frozen)))
        (check (.ref receipt 'accepted?) => #f)
        (check (.ref receipt 'abi-v1-frozen?) => #f)))))
