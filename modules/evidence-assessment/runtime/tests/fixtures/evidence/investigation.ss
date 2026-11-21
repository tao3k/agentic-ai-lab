;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(def investigation-contract-operator
  (relational-op-fragment
   (relational-op-project (relational-op-source 'contracts 3 []) '(0 1))
   'contract_dependencies))

(define-program (make-investigation)
   (sources inventory observation process field control_reference
     (contracts (relational-export investigation-contract-operator 'contracts)))
   (outputs inventory_count observation_count failed missing fields_per_observation
     most_fields ancestry recorded_control
     (contract_dependencies
       (relational-export investigation-contract-operator 'contract_dependencies)))
   (explain
    (lambda (program result query scope)
      (hash ("status" "recorded-only")
            ("query" query) ("scope" scope)
            ("dependencies" (.ref program 'rules))
            ("gap" "Source rows and declaration dependencies are not a per-row proof or host authorization"))))
   (relation inventory ((id string?) (kind string?) (status string?)))
   (relation observation ((id string?) (kind string?) (status string?) (receipt string?) (scope string?)))
   (relation process ((id string?) (exit exact-integer?) (timeout boolean?) (accepted boolean?)))
   (relation field ((id string?) (name string?) (receipt string?) (pointer string?) (encoded string?)))
   (relation control_reference ((id string?) (kind string?) (mode string?) (receipt string?)))
   (relation present (id name))
   (relation required (id name))
   (relation missing (id name))
   (relation failed (id kind receipt))
   (relation recorded_control (id receipt))
   (relation metadata_complete (id))
   (relation fields_per_observation (id count))
   (lattice most_fields (id count) [] max)
   (relation observation_count (count))
   (relation inventory_count (count))
   ((present id name) <-- (field id name receipt pointer encoded))
   ((required id (lit "original-budget")) <-- (observation id kind status receipt scope))
   ((required id (lit "runtime-tree")) <-- (observation id kind status receipt scope))
   ((required id (lit "producer")) <-- (observation id kind status receipt scope))
   ((required id (lit "teardown")) <-- (observation id kind status receipt scope))
   ((required id (lit "fixture-sha")) <-- (observation id kind status receipt (lit "fixture")))
   ((missing id name) <-- (required id name) (not (present id name)))
   ((failed id kind receipt) <-- (observation id kind status receipt scope)
     (process id exit timeout (lit #f)) (if (exit timeout) (or timeout (not (= exit 0)))))
   ((recorded_control id receipt) <-- (control_reference id kind mode receipt))
   ((metadata_complete id) <-- (observation id kind status receipt scope) (not (missing id _)))
   ((fields_per_observation id count) <-- (observation id kind status receipt scope)
     (aggregate count gerbil-ascent-count () (field id name digest pointer encoded)))
   ((most_fields id count) <-- (fields_per_observation id count))
   ((observation_count count) <--
     (aggregate count gerbil-ascent-count () (observation id kind status receipt scope)))
   ((inventory_count count) <--
     (aggregate count gerbil-ascent-count () (inventory id kind status)))
   (include (make-dependency-relations))
   (include investigation-contract-operator)
   ;; The runtime operator's private handles require a native relational bridge.
   (include
    (gerbil-ascent-fragment []
     (list (native-copy-rule
            (relational-export investigation-contract-operator 'contract_dependencies)
            'dependency)))))
