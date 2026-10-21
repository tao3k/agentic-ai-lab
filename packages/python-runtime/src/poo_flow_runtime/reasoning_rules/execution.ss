;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :gerbil-ascent/rules/interface (only-in :clan/poo/object .ref))
(export make-execution-evidence)

;; Execution observations are facts, not execution permission or source proofs.
(define-program (make-execution-evidence)
  (let (program (ascent
    (relation observed_step ((step string?) (outcome string?) (capability string?)))
    (relation required_step ((step string?)))
    (relation step_dependency ((step string?) (parent string?)))
    (relation source_binding ((binding string?) (workspace string?)))
    (relation workspace_projection ((workspace string?) (source string?)))
    (relation compiled_workspace ((build string?) (binding string?)))
    (relation tested_executable ((test string?) (build string?)))
    (relation control_case ((test string?) (case string?) (negative boolean?)))
    (relation native_process ((step string?) (stage string?) (exit exact-integer?) (timeout boolean?)))
    (relation checked_step ((step string?)))
    (relation missing_step ((step string?)))
    (relation bound_source ((binding string?) (source string?)))
    (relation bound_control ((test string?) (case string?) (negative boolean?) (binding string?)))
    ((checked_step S) <-- (observed_step S (lit "PASS") C))
    ((missing_step S) <-- (required_step S) (not (checked_step S)))
    ((bound_source B S) <-- (source_binding B W) (workspace_projection W S))
    ((bound_control T C N B) <-- (control_case T C N) (tested_executable T X)
                              (compiled_workspace X B) (bound_source B S))
    (bounds 4096 4096 4096)))
    (gerbil-ascent-program (.ref program 'relations) (.ref program 'rules)
      4096 4096 4096
      '(observed_step required_step step_dependency source_binding workspace_projection
        compiled_workspace tested_executable control_case native_process)))
  (lambda (program result query scope)
    (hash ("status" "recorded-only") ("query" query) ("scope" scope)
          ("dependencies" (.ref program 'rules))
          ("gap" "observed process facts do not prove runtime correctness or source refinement"))))
