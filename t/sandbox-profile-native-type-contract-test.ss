;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: sandbox profile recipes are admitted by one native POO Contract.
;;; This root is self-contained; unrelated test sources are not runfile inputs.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test)

(def (sandbox-profile-contract-eval expression)
  (eval expression))

(def (alist-ref/default entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

(export sandbox-profile-native-type-contract-test)

(def sandbox-profile-native-type-contract-test
  (test-suite "sandbox-profile-native-type-contract-test"
    (yuanxu-test-case "validates the native contract"
      (eval '(import "./modules/agent-sandbox/config.ss"))
      (eval '(import :clan/poo/mop :clan/poo/object))
      (let (contract-row
      (sandbox-profile-contract-eval
       '(agentic-ai-lab-sandbox-profile-type-contract->alist)))
  (unless
   (and
    (eq? (alist-ref/default contract-row 'object-kind #f)
         'PooSandboxProfile)
    (equal?
     (map (lambda (slot-row)
            (alist-ref/default slot-row 'slot #f))
          (alist-ref/default contract-row 'slots '()))
     '(kind name backend-kind backend-ref network-policy capabilities
       resource-policy metadata)))
   (error "sandbox profile native contract should expose the owned slots")))

(unless
 (sandbox-profile-contract-eval
  '(let (profile (agentic-ai-lab-sandbox-profile
                  agent/native
                  (backend nono nono-sandbox)
                  (network deny-by-default)
                  (capabilities process-run filesystem-read)
                  (resources (cpu . 2))
                  (metadata (runtime-executed . #f))))
     (and (element? Type AgenticAILabSandboxProfileContract)
          (agentic-ai-lab-sandbox-profile? profile)
          (agentic-ai-lab-sandbox-profile-contract-admitted? profile)
          (eq? (agentic-ai-lab-sandbox-profile-name
                (agentic-ai-lab-require-sandbox-profile-contract! profile))
               'agent/native))))
 (error "native sandbox profile contract should admit valid POO recipes"))

(when
 (sandbox-profile-contract-eval
  '(agentic-ai-lab-sandbox-profile-contract-admitted?
    (.o kind: agentic-ai-lab-sandbox-profile-kind
        name: 'agent/invalid
        backend-kind: 'nono
        backend-ref: 'nono-sandbox
        network-policy: '(deny-by-default)
        capabilities: "not-a-list"
        resource-policy: '()
        metadata: '())))
 (error "native sandbox profile contract should reject an invalid slot"))

(when
 (sandbox-profile-contract-eval
  '(agentic-ai-lab-sandbox-profile-contract-admitted?
    (.o kind: agentic-ai-lab-sandbox-profile-kind
        name: 'agent/missing
        backend-kind: 'nono
        backend-ref: 'nono-sandbox
        network-policy: '(deny-by-default)
        capabilities: '(process-run)
        resource-policy: '())))
 (error "native sandbox profile contract should reject a missing slot"))

(when
 (sandbox-profile-contract-eval
  '(with-catch
    (lambda (_failure) #f)
    (lambda ()
      (agentic-ai-lab-sandbox-profile->descriptor
       (.o kind: agentic-ai-lab-sandbox-profile-kind
           name: 'agent/invalid-handoff
           backend-kind: 'nono
           backend-ref: 'nono-sandbox
           network-policy: '(deny-by-default)
           capabilities: 'invalid
           resource-policy: '()
           metadata: '()))
      #t)))
 (error "descriptor handoff should fail before projecting an invalid profile")))))
