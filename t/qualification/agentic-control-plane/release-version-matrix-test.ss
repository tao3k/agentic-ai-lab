;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/workflow/qualification/release-version-matrix)


(def release-version-matrix-test
  (test-suite "AC-11 release version matrix"
    (yuanxu-test-case "current qualified owners bind without freezing ABI v1"
      (let* ((matrix (agentic-ai-lab-ac11-current-release-version-matrix))
             (receipt (agentic-ai-lab-ac11-release-version-matrix-verify matrix)))
        (check (agentic-ai-lab-release-version-matrix? matrix) => #t)
        (check (.ref receipt 'accepted?) => #t)
        (check (.ref receipt 'abi-v1-frozen?) => #f)
        (check (.ref receipt 'decision-required?) => #t)))
    (yuanxu-test-case "version drift fails closed"
      (let* ((current (agentic-ai-lab-ac11-current-release-version-matrix))
             (changed
              (agentic-ai-lab-release-version-matrix
               'agentic-ai-lab.organization-bundle.v1
               (agentic-ai-lab-release-version-matrix-runtime-abi current)
               (agentic-ai-lab-release-version-matrix-proof-vector current)
               (agentic-ai-lab-release-version-matrix-assurance-schema current)
               (agentic-ai-lab-release-version-matrix-owner-artifacts current)
               #f))
             (receipt (agentic-ai-lab-ac11-release-version-matrix-verify changed)))
        (check (.ref receipt 'accepted?) => #f)
        (check (.ref receipt 'diagnostics)
               => '(release-version-owner-drift))))
    (yuanxu-test-case "implicit ABI v1 freeze fails closed"
      (let* ((current (agentic-ai-lab-ac11-current-release-version-matrix))
             (frozen
              (agentic-ai-lab-release-version-matrix
               (agentic-ai-lab-release-version-matrix-bundle-schema current)
               (agentic-ai-lab-release-version-matrix-runtime-abi current)
               (agentic-ai-lab-release-version-matrix-proof-vector current)
               (agentic-ai-lab-release-version-matrix-assurance-schema current)
               (agentic-ai-lab-release-version-matrix-owner-artifacts current)
               #t))
             (receipt (agentic-ai-lab-ac11-release-version-matrix-verify frozen)))
        (check (.ref receipt 'accepted?) => #f)
        (check (.ref receipt 'abi-v1-frozen?) => #f)))))
