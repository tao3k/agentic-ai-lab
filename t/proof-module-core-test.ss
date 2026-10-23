;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .cc .o .ref)
        :poo-flow/modules/proof/interface)

(export proof-module-core-test)

(def proof-module-core-test
  (test-suite
   "POO Proof Module core"
   (yuanxu-test-case "admits exact artifact receipts and refinement bindings"
     (let* ((quint
             (poo-flow-proof-artifact
              "test/quint" 'quint 'quint "test/model.qnt"
              (poo-flow-proof-digest 'quint-source)
              '(SafetyInvariant) (.o)))
            (lean
             (poo-flow-proof-artifact
              "test/lean" 'lean 'lean "test/Refinement.lean"
              (poo-flow-proof-digest 'lean-source)
              '(safetyRefinement) (.o)))
            (receipt
             (poo-flow-proof-receipt
              "test/lean/receipt" lean 'lean '(safetyRefinement)
              (poo-flow-proof-digest 'lean-build-receipt) #t))
            (impact
             (poo-flow-proof-impact-binding
              "test/quint-to-lean" quint lean
              (.o SafetyInvariant: '(safetyRefinement))))
            (refinement
             (poo-flow-proof-refinement-binding
              "test/refinement" quint lean receipt impact))
            (assurance
             ((.ref PooFlowProofModule. '.admit-assurance)
              "test/assurance" (list quint lean) (list receipt)
              (list refinement))))
       (check (poo-flow-proof-module? PooFlowProofModule.) => #t)
       (check (.ref PooFlowProofModule. 'required-slots)
              => '(artifacts receipts refinements))
       (check (poo-flow-proof-assurance? assurance) => #t)
       (check (.ref assurance 'current?) => #t)
       (check (.ref assurance 'admitted?) => #t)
       (check (hash-get (.ref assurance 'artifact-index) "test/quint")
              => quint)))
   (yuanxu-test-case "changed upstream digest invalidates the exact refinement"
     (let* ((quint
             (poo-flow-proof-artifact
              "test/quint" 'quint 'quint "test/model.qnt"
              (poo-flow-proof-digest 'quint-source)
              '(SafetyInvariant) (.o)))
            (lean
             (poo-flow-proof-artifact
              "test/lean" 'lean 'lean "test/Refinement.lean"
              (poo-flow-proof-digest 'lean-source)
              '(safetyRefinement) (.o)))
            (receipt
             (poo-flow-proof-receipt
              "test/lean/receipt" lean 'lean '(safetyRefinement)
              (poo-flow-proof-digest 'lean-build-receipt) #t))
            (impact
             (poo-flow-proof-impact-binding
              "test/quint-to-lean" quint lean
              (.o SafetyInvariant: '(safetyRefinement))))
            (refinement
             (poo-flow-proof-refinement-binding
              "test/refinement" quint lean receipt impact))
            (changed-quint
             (.cc quint 'content-digest
                  (poo-flow-proof-digest 'changed-quint-source)))
            (assurance
             (poo-flow-proof-assurance
              "test/stale" (list changed-quint lean) (list receipt)
              (list refinement))))
       (check (.ref assurance 'current?) => #f)
       (check (.ref assurance 'admitted?) => #f)))))
