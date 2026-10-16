;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Run: gerbil env gerbil interactive t/scenarios/observability-admission-demo.ss
;;; A synthetic real Module error; no runtime resources or secrets are involved.
(import (only-in :clan/poo/object .cc .ref)
        (only-in :core/observability/objects
                 poo-flow-observation-identity
                 poo-flow-observation-context
                 poo-flow-observation-provenance
                 poo-flow-observe-contract-admission
                 poo-flow-observation-explain)
        (only-in :core/observability/debug
                 poo-flow-observation-debug)
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        (only-in :core/module-system/authoring/roles SemanticModuleContract poo-flow-semantic-module))

(export main)

;; : (-> Symbol ObservationIdentity)
(def (demo-id name)
  (poo-flow-observation-identity 'demo name 'v1))

;;; Demonstration boundary: all inputs are synthetic POO values and the only
;;; effect is an explicit diagnostic rendering to the current output port.
;; : (-> Unit Void)
(def (main)
  (let* ((context
          (poo-flow-observation-context
           (demo-id 'admission-event) (demo-id 'sample-module) (demo-id 'generation-1)
           '() (poo-flow-observation-provenance
                (demo-id 'module-admission) (demo-id 'gerbil-poo) 'admission)))
         (module (poo-flow-semantic-module (poo-flow-semantic-identity 'demo 'sample-module)))
         (invalid (.cc module 'imports 'not-an-import-relation))
         (event (poo-flow-observe-contract-admission context SemanticModuleContract invalid))
         (explanation (poo-flow-observation-explain event))
         (first-failure (car (.ref explanation 'failures))))
    ;; Explicit local inspection of a known non-sensitive synthetic path.
    (write (list 'failure-path (.ref first-failure 'path)
                 'cause (.ref first-failure 'code)))
    (newline)
    ;; Both the typed printer and traced render method are upstream-owned.
    (poo-flow-observation-debug event (current-output-port) trace?: #t)
    (void)))
