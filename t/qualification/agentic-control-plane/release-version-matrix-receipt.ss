;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Qualification owner: render one release-version assurance receipt and
;;; reflect its acceptance decision in the process status.

(import :gerbil/runtime/gambit
        (only-in :clan/poo/object .ref)
        (only-in :std/list/walist walist)
        (only-in :std/encoding/json json->string)
        :agentic-ai-lab/modules/workflow/qualification/release-version-matrix)

(export main)

;;; Command boundary: argument validation, receipt construction, rendering,
;;; and the process exit decision are owned by one explicit entrypoint.
;; : (-> [String] Void)
(def (main . args)
  (unless (= (length args) 1)
    (displayln "usage: gxi t/qualification/agentic-control-plane/release-version-matrix-receipt.ss SOURCE_REVISION")
    (exit 64))
  (let* ((matrix (agentic-ai-lab-ac11-current-release-version-matrix))
         (receipt (agentic-ai-lab-ac11-release-version-matrix-verify matrix))
         (runtime-abi (agentic-ai-lab-release-version-matrix-runtime-abi matrix))
         (proof-vector (agentic-ai-lab-release-version-matrix-proof-vector matrix)))
    (display
     (json->string
      (walist
       (list
        (cons "schema" "agentic-ai-lab.release-version-matrix.v1")
        (cons "schemaVersion" 1)
        (cons "sourceRevision" (car args))
        (cons "bundleSchema"
              (symbol->string
               (agentic-ai-lab-release-version-matrix-bundle-schema matrix)))
        (cons "runtimeAbi"
              (walist
               (list (cons "major" (.ref runtime-abi 'major))
                     (cons "minor" (.ref runtime-abi 'minor)))))
        (cons "proofVector"
              (walist
               (list
                (cons "version" (.ref proof-vector 'version))
                (cons "schemaFingerprint"
                      (.ref proof-vector 'schema-fingerprint))
                (cons "vectorDomain" (.ref proof-vector 'vector-domain))
                (cons "theoremSetDomain"
                      (.ref proof-vector 'theorem-set-domain)))))
        (cons "evidenceAssurance"
              (symbol->string
               (agentic-ai-lab-release-version-matrix-assurance-schema matrix)))
        (cons "ownerArtifacts"
              (map symbol->string
                   (agentic-ai-lab-release-version-matrix-owner-artifacts matrix)))
        (cons "abiV1Frozen" (.ref receipt 'abi-v1-frozen?))
        (cons "decisionRequired" (.ref receipt 'decision-required?))
        (cons "accepted" (.ref receipt 'accepted?))))))
    (newline)
    (exit (if (.ref receipt 'accepted?) 0 1))))
