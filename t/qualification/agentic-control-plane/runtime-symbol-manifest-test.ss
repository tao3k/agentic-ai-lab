;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/workflow/qualification/runtime-symbol-manifest)


(def (read-manifest json)
  (poo-flow-runtime-symbol-manifest-read (open-input-string json)))

(def valid-json
  "{\"schema\":\"poo-flow.runtime-symbol-manifest.v1\",\"schemaVersion\":1,\"abi\":\"runtime-v0.1\",\"requiredSymbols\":[\"poo_flow_runtime_v0_open\"],\"forbiddenFragments\":[\"graph\",\"compat\",\"legacy\"],\"owners\":[\"runtime_v0.h\"]}")

(def runtime-symbol-manifest-test
  (test-suite "AC-11 runtime symbol JSON manifest"
    (poo-flow-test-case "valid manifest and exact symbols pass"
      (let (receipt
            (poo-flow-runtime-symbol-manifest-verify
             (read-manifest valid-json)
             '("poo_flow_runtime_v0_open")))
        (check (.ref receipt 'accepted?) => #t)
        (check (.ref receipt 'diagnostics) => '())))
    (poo-flow-test-case "symbol drift fails closed"
      (let (receipt
            (poo-flow-runtime-symbol-manifest-verify
             (read-manifest valid-json)
             '("poo_flow_runtime_v0_open" "poo_flow_runtime_v0_extra")))
        (check (.ref receipt 'accepted?) => #f)
        (check (.ref receipt 'diagnostics) => '(exported-symbol-drift))))
    (poo-flow-test-case "unknown schema version fails closed"
      (let (receipt
            (poo-flow-runtime-symbol-manifest-verify
             (read-manifest
              "{\"schema\":\"poo-flow.runtime-symbol-manifest.v1\",\"schemaVersion\":2,\"abi\":\"runtime-v0.1\",\"requiredSymbols\":[],\"forbiddenFragments\":[],\"owners\":[]}")
             '()))
        (check (.ref receipt 'accepted?) => #f)
        (check (.ref receipt 'diagnostics)
               => '(invalid-or-unknown-manifest))))
    (poo-flow-test-case "malformed manifest shape fails closed"
      (let (receipt
            (poo-flow-runtime-symbol-manifest-verify
             (read-manifest
              "{\"schema\":\"poo-flow.runtime-symbol-manifest.v1\",\"schemaVersion\":1}")
             '()))
        (check (.ref receipt 'accepted?) => #f)
        (check (.ref receipt 'diagnostics)
               => '(invalid-or-unknown-manifest))))
    (poo-flow-test-case "malformed JSON fails closed"
      (let (receipt
            (poo-flow-runtime-symbol-manifest-verify
             (read-manifest "{\"schema\":") '()))
        (check (.ref receipt 'accepted?) => #f)
        (check (.ref receipt 'diagnostics)
               => '(invalid-or-unknown-manifest))))))
