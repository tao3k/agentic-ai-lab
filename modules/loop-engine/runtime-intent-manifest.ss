;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Projects runtime envelopes into command and proof manifests.
;;; Manifests are inert ABI values and never launch the runtime.
(import :yuanxu/modules/funflow/control-plane/runtime-command-descriptor
        "core.ss"
        "proof-abi.ss"
        "runtime-intent-request.ss")

(export agentic-ai-lab-user-loop-engine-intent-runtime-command-manifest
        agentic-ai-lab-user-loop-engine-runtime-command-manifest/from-envelope
        agentic-ai-lab-user-loop-engine-intent-runtime-command-manifest-summary
        agentic-ai-lab-user-loop-engine-runtime-command-manifest-summary/from-manifest
        agentic-ai-lab-user-loop-engine-intent-proof-manifest
        agentic-ai-lab-user-loop-engine-proof-manifest/from-manifest)

(def (agentic-ai-lab-user-loop-engine-runtime-command-manifest/from-envelope envelope)
  (runtime-command-fields->manifest
   +agentic-ai-lab-user-loop-engine-runtime-command-name+
   +agentic-ai-lab-user-loop-engine-runtime-command-executable+
   +agentic-ai-lab-user-loop-engine-runtime-command-arguments+
   'stdout-s-expression
   (list
    (cons 'source 'user-config-loop-engine)
    (cons 'contract
          +agentic-ai-lab-user-loop-engine-runtime-command-contract+)
    (cons 'runtime-owner "marlin-agent-core")
    (cons 'object-families
          +agentic-ai-lab-user-loop-engine-runtime-object-families+)
    (cons 'runtime-executed #f))
   envelope))

(def (agentic-ai-lab-user-loop-engine-intent-runtime-command-manifest intent)
  (agentic-ai-lab-user-loop-engine-runtime-command-manifest/from-envelope
   (agentic-ai-lab-user-loop-engine-intent-runtime-envelope intent)))

(def (agentic-ai-lab-user-loop-engine-runtime-command-manifest-summary/from-manifest
      manifest)
  (let* ((request
          (agentic-ai-lab-user-loop-engine-intent-ref manifest 'request '()))
         (metadata
          (agentic-ai-lab-user-loop-engine-intent-ref manifest 'metadata '())))
    (list
     (cons 'kind 'runtime-command-manifest-summary)
     (cons 'name (agentic-ai-lab-user-loop-engine-intent-ref manifest 'name #f))
     (cons 'operation
           (agentic-ai-lab-user-loop-engine-intent-ref manifest 'operation #f))
     (cons 'request-id
           (agentic-ai-lab-user-loop-engine-intent-ref manifest 'request-id #f))
     (cons 'artifact-handle
           (agentic-ai-lab-user-loop-engine-intent-ref
            manifest
            'artifact-handle
            #f))
     (cons 'contract
           (agentic-ai-lab-user-loop-engine-intent-ref
            metadata
            'contract
            +agentic-ai-lab-user-loop-engine-runtime-command-contract+))
     (cons 'object-families
           (agentic-ai-lab-user-loop-engine-intent-ref
            metadata
            'object-families
            +agentic-ai-lab-user-loop-engine-runtime-object-families+))
     (cons 'receipt-contracts
           +agentic-ai-lab-user-loop-engine-receipt-contracts+)
     (cons 'runtime-packet-contracts
           +agentic-ai-lab-user-loop-engine-runtime-packet-contracts+)
     (cons 'runtime-owner
           (agentic-ai-lab-user-loop-engine-intent-ref
            request
            'runtime-owner
            "marlin-agent-core"))
     (cons 'runtime-executed #f))))

(def (agentic-ai-lab-user-loop-engine-intent-runtime-command-manifest-summary intent)
  (agentic-ai-lab-user-loop-engine-runtime-command-manifest-summary/from-manifest
   (agentic-ai-lab-user-loop-engine-intent-runtime-command-manifest intent)))

(def (agentic-ai-lab-user-loop-engine-proof-manifest/from-manifest manifest)
  (agentic-ai-lab-loop-engine-proof-manifest
     (agentic-ai-lab-user-loop-engine-intent-ref manifest 'request-id #f)
     (agentic-ai-lab-user-loop-engine-intent-ref manifest 'artifact-handle #f)
     +agentic-ai-lab-user-loop-engine-runtime-command-contract+
     +agentic-ai-lab-user-loop-engine-runtime-object-families+
     +agentic-ai-lab-user-loop-engine-receipt-contracts+
     +agentic-ai-lab-user-loop-engine-runtime-packet-contracts+))

(def (agentic-ai-lab-user-loop-engine-intent-proof-manifest intent)
  (let (use-case-name
        (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
    (agentic-ai-lab-loop-engine-proof-manifest
     (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "request")
     (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "artifact")
     +agentic-ai-lab-user-loop-engine-runtime-command-contract+
     +agentic-ai-lab-user-loop-engine-runtime-object-families+
     +agentic-ai-lab-user-loop-engine-receipt-contracts+
     +agentic-ai-lab-user-loop-engine-runtime-packet-contracts+)))
