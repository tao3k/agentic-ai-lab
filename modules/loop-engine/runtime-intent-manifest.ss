;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Projects runtime envelopes into command and proof manifests.
;;; Manifests are inert ABI values and never launch the runtime.
(import :poo-flow/modules/workflow/control-plane/runtime-command-descriptor
        "core.ss"
        "proof-abi.ss"
        "runtime-intent-request.ss")

(export poo-flow-user-loop-engine-intent-runtime-command-manifest
        poo-flow-user-loop-engine-runtime-command-manifest/from-envelope
        poo-flow-user-loop-engine-intent-runtime-command-manifest-summary
        poo-flow-user-loop-engine-runtime-command-manifest-summary/from-manifest
        poo-flow-user-loop-engine-intent-proof-manifest
        poo-flow-user-loop-engine-proof-manifest/from-manifest)

(def (poo-flow-user-loop-engine-runtime-command-manifest/from-envelope envelope)
  (runtime-command-fields->manifest
   +poo-flow-user-loop-engine-runtime-command-name+
   +poo-flow-user-loop-engine-runtime-command-executable+
   +poo-flow-user-loop-engine-runtime-command-arguments+
   'stdout-s-expression
   (list
    (cons 'source 'user-config-loop-engine)
    (cons 'contract
          +poo-flow-user-loop-engine-runtime-command-contract+)
    (cons 'runtime-owner "marlin-agent-core")
    (cons 'object-families
          +poo-flow-user-loop-engine-runtime-object-families+)
    (cons 'runtime-executed #f))
   envelope))

(def (poo-flow-user-loop-engine-intent-runtime-command-manifest intent)
  (poo-flow-user-loop-engine-runtime-command-manifest/from-envelope
   (poo-flow-user-loop-engine-intent-runtime-envelope intent)))

(def (poo-flow-user-loop-engine-runtime-command-manifest-summary/from-manifest
      manifest)
  (let* ((request
          (poo-flow-user-loop-engine-intent-ref manifest 'request '()))
         (metadata
          (poo-flow-user-loop-engine-intent-ref manifest 'metadata '())))
    (list
     (cons 'kind 'runtime-command-manifest-summary)
     (cons 'name (poo-flow-user-loop-engine-intent-ref manifest 'name #f))
     (cons 'operation
           (poo-flow-user-loop-engine-intent-ref manifest 'operation #f))
     (cons 'request-id
           (poo-flow-user-loop-engine-intent-ref manifest 'request-id #f))
     (cons 'artifact-handle
           (poo-flow-user-loop-engine-intent-ref
            manifest
            'artifact-handle
            #f))
     (cons 'contract
           (poo-flow-user-loop-engine-intent-ref
            metadata
            'contract
            +poo-flow-user-loop-engine-runtime-command-contract+))
     (cons 'object-families
           (poo-flow-user-loop-engine-intent-ref
            metadata
            'object-families
            +poo-flow-user-loop-engine-runtime-object-families+))
     (cons 'receipt-contracts
           +poo-flow-user-loop-engine-receipt-contracts+)
     (cons 'runtime-packet-contracts
           +poo-flow-user-loop-engine-runtime-packet-contracts+)
     (cons 'runtime-owner
           (poo-flow-user-loop-engine-intent-ref
            request
            'runtime-owner
            "marlin-agent-core"))
     (cons 'runtime-executed #f))))

(def (poo-flow-user-loop-engine-intent-runtime-command-manifest-summary intent)
  (poo-flow-user-loop-engine-runtime-command-manifest-summary/from-manifest
   (poo-flow-user-loop-engine-intent-runtime-command-manifest intent)))

(def (poo-flow-user-loop-engine-proof-manifest/from-manifest manifest)
  (poo-flow-loop-engine-proof-manifest
     (poo-flow-user-loop-engine-intent-ref manifest 'request-id #f)
     (poo-flow-user-loop-engine-intent-ref manifest 'artifact-handle #f)
     +poo-flow-user-loop-engine-runtime-command-contract+
     +poo-flow-user-loop-engine-runtime-object-families+
     +poo-flow-user-loop-engine-receipt-contracts+
     +poo-flow-user-loop-engine-runtime-packet-contracts+))

(def (poo-flow-user-loop-engine-intent-proof-manifest intent)
  (let (use-case-name
        (poo-flow-user-loop-engine-intent-use-case-name intent))
    (poo-flow-loop-engine-proof-manifest
     (poo-flow-user-loop-engine-runtime-id use-case-name "request")
     (poo-flow-user-loop-engine-runtime-id use-case-name "artifact")
     +poo-flow-user-loop-engine-runtime-command-contract+
     +poo-flow-user-loop-engine-runtime-object-families+
     +poo-flow-user-loop-engine-receipt-contracts+
     +poo-flow-user-loop-engine-runtime-packet-contracts+)))
