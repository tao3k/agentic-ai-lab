;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :agentic-ai-lab/modules/temporal-causality/candidates/types
                 AgenticAILabCandidateScope AgenticAILabCandidateReceipt
                 AgenticAILabCandidateCheck AgenticAILabCandidateExchange))
(export agentic-ai-lab-candidate-scope-value agentic-ai-lab-candidate-receipt-value
        agentic-ai-lab-candidate-check-value agentic-ai-lab-candidate-exchange-value)

(def (agentic-ai-lab-candidate-scope-value id-value digest-value cut-value
                                     generation-value coverage-value
                                     providers-value)
  (validate AgenticAILabCandidateScope
    (.o kind: 'agentic-ai-lab.temporal-causality.candidate-scope
        identity: id-value semantic-digest: digest-value
        evidence-cut-digest: cut-value generation: generation-value
        source-coverage-digest: coverage-value
        required-providers: providers-value)))

(def (agentic-ai-lab-candidate-receipt-value id-value digest-value candidate-value
                                        scope-value provider-value request-value
                                        source-value result-value count-value
                                        complete-value)
  (validate AgenticAILabCandidateReceipt
    (.o kind: 'agentic-ai-lab.temporal-causality.candidate-receipt
        identity: id-value semantic-digest: digest-value
        candidate-identity: candidate-value scope-digest: scope-value
        provider-identity: provider-value request-digest: request-value
        source-receipt-digest: source-value result-digest: result-value
        result-count: count-value complete?: complete-value)))

(def (agentic-ai-lab-candidate-check-value id-value digest-value receipt-value
                                      receipt-digest-value verifier-value
                                      verdict-value basis-value)
  (validate AgenticAILabCandidateCheck
    (.o kind: 'agentic-ai-lab.temporal-causality.candidate-check
        identity: id-value semantic-digest: digest-value
        receipt-identity: receipt-value receipt-digest: receipt-digest-value
        verifier-identity: verifier-value verdict: verdict-value
        basis-digest: basis-value)))

(def (agentic-ai-lab-candidate-exchange-value id-value digest-value candidate-value
                                         scope-value receipts-value checks-value
                                         missing-value stale-value
                                         incomplete-value unchecked-value
                                         invalid-value contested-value status-value)
  (validate AgenticAILabCandidateExchange
    (.o kind: 'agentic-ai-lab.temporal-causality.candidate-exchange
        identity: id-value semantic-digest: digest-value
        candidate-identity: candidate-value
        scope: scope-value receipts: receipts-value checks: checks-value
        missing-providers: missing-value stale-receipts: stale-value
        incomplete-receipts: incomplete-value
        unchecked-receipts: unchecked-value invalid-receipts: invalid-value
        contested-providers: contested-value status: status-value
        admitted?: #f)))
