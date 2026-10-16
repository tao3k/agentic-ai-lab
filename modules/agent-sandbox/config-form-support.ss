;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user-facing agent sandbox profile declarations.
;;; Invariant: profiles are inert data until a runtime bridge consumes them.

(import (only-in :clan/poo/object .o .ref object<-alist)
        (only-in :clan/poo/mop element?)
        :poo-flow/modules/agent-sandbox/profile
        :poo-flow/modules/agent-sandbox/profile-native-contract
        :poo-flow/modules/agent-sandbox/projection-syntax
        :poo-flow/modules/sandbox-core/profile-support/policy
        :core/utilities/final-projection-syntax)

(export #t)

;;; The presentation kind names the shallow, non-executing view used by agents
;;; and CLI tooling before any backend descriptor is realized.
;; : PooFlowSandboxProfilesPresentationKindId
;; | PooFlowSandboxProfilesPresentationKindId = String
(def poo-flow-sandbox-profiles-presentation-kind
  "poo-flow.agent-sandbox.user-profiles.presentation.v1")

;;; Form lookup stays textual and inert: unknown rows are ignored here because
;;; runtime/profile validation happens after projection to the sandbox contract.
;; : (-> Symbol [SandboxProfileForm] SandboxProfileForm SandboxProfileForm)
(def (poo-flow-sandbox-profile-form key forms default-value)
  (cond
   ((null? forms) default-value)
   ((and (pair? (car forms))
         (eq? (caar forms) key))
    (car forms))
   (else
    (poo-flow-sandbox-profile-form key (cdr forms) default-value))))

;;; Tail extraction keeps malformed optional rows harmless: non-pairs project
;;; to an empty payload and leave stricter checks to descriptor validation.
;; : (-> MaybeSandboxProfileForm [SandboxProfileForm])
(def (poo-flow-sandbox-profile-tail form)
  (if (and form (pair? form)) (cdr form) '()))

;;; A one-symbol backend row such as `(backend nono)` means both backend kind
;;; and backend ref are `nono`; explicit refs let cubeSandbox name a profile.
;; : (-> [SandboxProfileForm] (Values Symbol Symbol))
(def (poo-flow-sandbox-profile-backend-values forms)
  (let* ((backend-form
          (poo-flow-sandbox-profile-form 'backend
                                         forms
                                         '(backend nono nono-sandbox)))
         (backend-payload (poo-flow-sandbox-profile-tail backend-form))
         (backend-kind (if (null? backend-payload)
                         'nono
                         (car backend-payload)))
         (backend-ref (if (or (null? backend-payload)
                              (null? (cdr backend-payload)))
                        backend-kind
                        (cadr backend-payload))))
    (values backend-kind backend-ref)))

;;; List-form projection preserves user order and avoids inventing defaults
;;; for rows that should remain owned by upstream sandbox policy.
;; : (-> Symbol [SandboxProfileForm] [Value] [Value])
(def (poo-flow-sandbox-profile-list-form key forms default-value)
  (let (form (poo-flow-sandbox-profile-form key forms #f))
    (if form
      (poo-flow-sandbox-profile-tail form)
      default-value)))

;;; Profile config construction keeps parsing shallow: it only projects rows
;;; into POO slots and leaves descriptor validation to the bridge boundary.
;; : (-> Symbol [SandboxProfileForm] POOObject)
(def (poo-flow-sandbox-profile-config name-value forms)
  (call-with-values
    (lambda () (poo-flow-sandbox-profile-backend-values forms))
    (lambda (backend-kind-value backend-ref-value)
      (.o kind: poo-flow-sandbox-profile-kind
          name: name-value
          backend-kind: backend-kind-value
          backend-ref: backend-ref-value
          network-policy: (poo-flow-sandbox-profile-list-form
                           'network
                           forms
                           '(deny-by-default))
          capabilities: (poo-flow-sandbox-profile-list-form
                         'capabilities
                         forms
                         '(process filesystem tmpdir))
          resource-policy: (poo-flow-sandbox-profile-list-form
                            'resources
                            forms
                            '())
          metadata: (agent-sandbox-field-rows/tail
                     (poo-flow-sandbox-profile-list-form
                      'metadata
                      forms
                      '())
                     (declared-by 'poo-flow-user-interface)
                     (runtime-executed #f))))))
