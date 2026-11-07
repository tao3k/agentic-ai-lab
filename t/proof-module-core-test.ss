;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .cc .o .ref)
        :agentic-ai-lab/modules/proof/interface)

(export proof-module-core-test)

(def proof-module-core-test
  (test-suite
   "POO Proof Module core"
   (yuanxu-test-case "admits exact artifact receipts and refinement bindings"
     (let* ((quint
             (agentic-ai-lab-proof-artifact
              "test/quint" 'quint 'quint "test/model.qnt"
              (agentic-ai-lab-proof-digest 'quint-source)
              '(SafetyInvariant) (.o)))
            (lean
             (agentic-ai-lab-proof-artifact
              "test/lean" 'lean 'lean "test/Refinement.lean"
              (agentic-ai-lab-proof-digest 'lean-source)
              '(safetyRefinement) (.o)))
            (receipt
             (agentic-ai-lab-proof-receipt
              "test/lean/receipt" lean 'lean '(safetyRefinement)
              (agentic-ai-lab-proof-digest 'lean-build-receipt) #t))
            (impact
             (agentic-ai-lab-proof-impact-binding
              "test/quint-to-lean" quint lean
              (.o SafetyInvariant: '(safetyRefinement))))
            (refinement
             (agentic-ai-lab-proof-refinement-binding
              "test/refinement" quint lean receipt impact))
            (assurance
             ((.ref AgenticAILabProofModule. '.admit-assurance)
              "test/assurance" (list quint lean) (list receipt)
              (list refinement))))
       (check (agentic-ai-lab-proof-module? AgenticAILabProofModule.) => #t)
       (check (.ref AgenticAILabProofModule. 'required-slots)
              => '(artifacts receipts refinements))
       (check (agentic-ai-lab-proof-assurance? assurance) => #t)
       (check (.ref assurance 'current?) => #t)
       (check (.ref assurance 'admitted?) => #t)
       (check (hash-get (.ref assurance 'artifact-index) "test/quint")
              => quint)))
   (yuanxu-test-case "changed upstream digest invalidates the exact refinement"
     (let* ((quint
             (agentic-ai-lab-proof-artifact
              "test/quint" 'quint 'quint "test/model.qnt"
              (agentic-ai-lab-proof-digest 'quint-source)
              '(SafetyInvariant) (.o)))
            (lean
             (agentic-ai-lab-proof-artifact
              "test/lean" 'lean 'lean "test/Refinement.lean"
              (agentic-ai-lab-proof-digest 'lean-source)
              '(safetyRefinement) (.o)))
            (receipt
             (agentic-ai-lab-proof-receipt
              "test/lean/receipt" lean 'lean '(safetyRefinement)
              (agentic-ai-lab-proof-digest 'lean-build-receipt) #t))
            (impact
             (agentic-ai-lab-proof-impact-binding
              "test/quint-to-lean" quint lean
              (.o SafetyInvariant: '(safetyRefinement))))
            (refinement
             (agentic-ai-lab-proof-refinement-binding
              "test/refinement" quint lean receipt impact))
            (changed-quint
             (.cc quint 'content-digest
                  (agentic-ai-lab-proof-digest 'changed-quint-source)))
            (assurance
             (agentic-ai-lab-proof-assurance
              "test/stale" (list changed-quint lean) (list receipt)
              (list refinement))))
       (check (.ref assurance 'current?) => #f)
       (check (.ref assurance 'admitted?) => #f)))))
