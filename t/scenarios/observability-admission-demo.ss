;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Run: gerbil env gerbil interactive t/scenarios/observability-admission-demo.ss
;;; A synthetic real Module error; no runtime resources or secrets are involved.
(import (only-in :clan/poo/object .cc .ref)
        (only-in :yuanxu/observability/objects
                 yuanxu-observation-identity
                 yuanxu-observation-context
                 yuanxu-observation-provenance
                 yuanxu-observe-contract-admission
                 yuanxu-observation-explain)
        (only-in :yuanxu/observability/debug
                 yuanxu-observation-debug)
        (only-in :yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        (only-in :yuanxu/module-system/authoring/roles SemanticModuleContract yuanxu-semantic-module))

(export main)

;; : (-> Symbol ObservationIdentity)
(def (demo-id name)
  (yuanxu-observation-identity 'demo name 'v1))

;;; Demonstration boundary: all inputs are synthetic POO values and the only
;;; effect is an explicit diagnostic rendering to the current output port.
;; : (-> Unit Void)
(def (main)
  (let* ((context
          (yuanxu-observation-context
           (demo-id 'admission-event) (demo-id 'sample-module) (demo-id 'generation-1)
           '() (yuanxu-observation-provenance
                (demo-id 'module-admission) (demo-id 'gerbil-poo) 'admission)))
         (module (yuanxu-semantic-module (yuanxu-semantic-identity 'demo 'sample-module)))
         (invalid (.cc module 'imports 'not-an-import-relation))
         (event (yuanxu-observe-contract-admission context SemanticModuleContract invalid))
         (explanation (yuanxu-observation-explain event))
         (first-failure (car (.ref explanation 'failures))))
    ;; Explicit local inspection of a known non-sensitive synthetic path.
    (write (list 'failure-path (.ref first-failure 'path)
                 'cause (.ref first-failure 'code)))
    (newline)
    ;; Both the typed printer and traced render method are upstream-owned.
    (yuanxu-observation-debug event (current-output-port) trace?: #t)
    (void)))
