;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native Proof artifacts, receipts and exact digest bindings.
(import (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/mop validate)
        "types.ss")

(export agentic-ai-lab-proof-artifact
        agentic-ai-lab-proof-receipt
        agentic-ai-lab-proof-impact-binding
        agentic-ai-lab-proof-refinement-binding)

(def (agentic-ai-lab-proof-artifact identity-value engine-value language-value
                              path-value content-digest-value
                              declaration-values metadata-value)
  (validate
   AgenticAILabProofArtifact
   (.o kind: +agentic-ai-lab-proof-artifact-kind+
       identity: identity-value
       engine: engine-value
       language: language-value
       path: path-value
       content-digest: content-digest-value
       declarations: declaration-values
       metadata: metadata-value
       runtime-executed?: #f)))

(def (agentic-ai-lab-proof-receipt identity-value artifact-value engine-value
                             certification-values evidence-digest-value
                             admitted-value)
  (validate
   AgenticAILabProofReceipt
   (.o kind: +agentic-ai-lab-proof-receipt-kind+
       identity: identity-value
       artifact-identity: (.ref artifact-value 'identity)
       artifact-content-digest: (.ref artifact-value 'content-digest)
       engine: engine-value
       certifications: certification-values
       evidence-digest: evidence-digest-value
       admitted?: (if admitted-value #t #f)
       runtime-executed?: #f)))

(def (agentic-ai-lab-proof-impact-binding
      identity-value upstream-artifact-value downstream-artifact-value
      impact-map-value)
  (validate
   AgenticAILabProofImpactBinding
   (.o kind: +agentic-ai-lab-proof-impact-binding-kind+
       identity: identity-value
       upstream-artifact-identity: (.ref upstream-artifact-value 'identity)
       upstream-content-digest:
       (.ref upstream-artifact-value 'content-digest)
       downstream-artifact-identity:
       (.ref downstream-artifact-value 'identity)
       downstream-content-digest:
       (.ref downstream-artifact-value 'content-digest)
       impact-map: impact-map-value
       stale-downstream-policy: 'reject
       runtime-executed?: #f)))

(def (agentic-ai-lab-proof-refinement-binding
      identity-value upstream-artifact-value downstream-artifact-value
      receipt-value impact-binding-value)
  (validate
   AgenticAILabProofRefinementBinding
   (.o kind: +agentic-ai-lab-proof-refinement-binding-kind+
       identity: identity-value
       upstream-artifact-identity: (.ref upstream-artifact-value 'identity)
       upstream-content-digest:
       (.ref upstream-artifact-value 'content-digest)
       downstream-artifact-identity:
       (.ref downstream-artifact-value 'identity)
       downstream-content-digest:
       (.ref downstream-artifact-value 'content-digest)
       receipt-identity: (.ref receipt-value 'identity)
       impact-binding: impact-binding-value
       admitted?: (.ref receipt-value 'admitted?)
       runtime-executed?: #f)))
