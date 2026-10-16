;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: projects semantic organization bundles into Runtime v0 control packets.
;;; Invariant: runtime packets carry validated bundle identity without reinterpreting policy.
(export #t)

(import (only-in :clan/poo/object .o .ref object?)
        :poo-flow/modules/query/semantic/organization-bundle
        :poo-flow/modules/query/semantic/organization-bundle-kernel
        (only-in ./runtime-v0-abi-schema
                 +poo-flow-runtime-v0-abi-schema+))

(def +poo-flow-runtime-v0-control-packet-schema+
  'poo-flow.runtime-v0.control-packet.1)

;; : (-> PooFlowBundleKernelState PooFlowRuntimeV0ControlPacket)
(def (poo-flow-runtime-v0-control-packet state)
  (unless (object? state)
    (error "runtime v0 control packet requires validated Bundle Kernel state"
           state))
  (case (.ref state 'phase)
    ((validated advanced)
     (let ((identity (.ref state 'identity))
           (bundle (.ref state 'bundle)))
       (.o (kind +poo-flow-runtime-v0-control-packet-schema+)
           (abi-major (.ref +poo-flow-runtime-v0-abi-schema+ 'abi-major))
           (abi-minor (.ref +poo-flow-runtime-v0-abi-schema+ 'abi-minor))
           (bundle-schema +poo-flow-organization-bundle-schema+)
           (digest-algorithm (.ref identity 'algorithm))
           (bundle-digest (.ref identity 'digest))
           (bundle-epoch (.ref bundle 'epoch))
           (kernel-epoch (.ref state 'epoch))
           (canonical-packet (.ref state 'canonical-payload))
           (abi-v1-frozen? #f))))
    (else
     (error "runtime v0 control packet requires validated Bundle Kernel state"
            state))))

;; : (-> PooFlowRuntimeV0ControlPacket Alist)
(def (poo-flow-runtime-v0-control-packet->alist packet)
  (map (lambda (slot) (cons slot (.ref packet slot)))
       '(kind
         abi-major
         abi-minor
         bundle-schema
         digest-algorithm
         bundle-digest
         bundle-epoch
         kernel-epoch
         canonical-packet
         abi-v1-frozen?)))
