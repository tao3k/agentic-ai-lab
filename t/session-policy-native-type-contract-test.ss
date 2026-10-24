;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: session policy and tool grants expose native POO Contracts.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test)

;; : (-> AgenticAILabSessionPolicyExpr AgenticAILabSessionPolicyValue)
(def (session-policy-eval expr)
  (eval expr))

;; : (-> Alist Symbol Object Object)
(def (alist-ref/default entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;; : (-> Alist [Symbol])
(def (contract-slot-names row)
  (map (lambda (slot-row)
         (alist-ref/default slot-row 'slot #f))
       (alist-ref/default row 'slots '())))

(export session-policy-native-type-contract-test)

(def session-policy-native-type-contract-test
  (test-suite "session-policy-native-type-contract-test"
    (yuanxu-test-case "validates the native contract"
      (eval '(import "./modules/session/policy.ss"))
      (eval '(import :clan/poo/mop :clan/poo/object))
      (eval
       '(def (alist-ref/default entries key default-value)
          (let (entry (assoc key entries))
            (if entry (cdr entry) default-value))))
      (let (policy-row
      (session-policy-eval
       '(agentic-ai-lab-session-policy-type-contract->alist)))
  (unless (and (eq? (alist-ref/default policy-row 'object-kind #f)
                    'PooSessionPolicy)
               (equal? (contract-slot-names policy-row)
                       '(kind schema policy-kind policy-name scope-ref
                         default-action policy-slots metadata runtime-owner
                         runtime-executed)))
    (error "session policy contract should expose policy slots")))

(let (grant-row
      (session-policy-eval
       '(agentic-ai-lab-session-tool-grant-type-contract->alist)))
  (unless (and (eq? (alist-ref/default grant-row 'object-kind #f)
                    'PooSessionToolGrant)
               (equal? (contract-slot-names grant-row)
                       '(kind schema grant-id tool-ref actions resource-refs
                         trigger-refs metadata runtime-executed)))
    (error "session tool grant contract should expose grant slots")))

(unless
 (session-policy-eval
  '(and
    (element? Type AgenticAILabSessionPolicyContract)
    (element? Type AgenticAILabSessionToolGrantContract)
    (element?
     AgenticAILabSessionPolicyContract
     (agentic-ai-lab-session-tool-permission-policy
      'policy/native-contract
      'session/native-contract
      '()
      '()
      'deny))
    (element?
     AgenticAILabSessionToolGrantContract
     (agentic-ai-lab-session-tool-grant
      'grant/read
      'read-workspace-file
      '(read)
      '(project-workspace)
      '(agent-turn)))))
 (error "session policy contracts should be native Types and admit valid grants"))

;; Wire projection must not erase a conflicting field before native admission.
(when
 (session-policy-eval
  '(let (grant (agentic-ai-lab-session-tool-grant
                'grant/read 'read-workspace-file '(read) '(project-workspace) '(agent-turn)))
     (or (element? AgenticAILabSessionToolGrantContract
                   (cons '(runtime-executed . #t) grant))
         (element? AgenticAILabSessionToolGrantContract '(malformed-row))
         (element? AgenticAILabSessionToolGrantContract '((kind . agentic-ai-lab.session.tool-grant))))))
 (error "native grant admission must reject duplicate, malformed and incomplete rows"))

(when
 (session-policy-eval
  '(element?
    AgenticAILabSessionToolGrantContract
    '((kind . agentic-ai-lab.session.tool-grant)
      (schema . agentic-ai-lab.modules.session.tool-grant.v1)
      (grant-id . grant/read)
      (tool-ref . read-workspace-file)
      (actions . (read))
      (resource-refs . (project-workspace))
      (trigger-refs . (agent-turn))
      (metadata)
      (runtime-executed . not-a-boolean))))
 (error "native session tool grant contract should reject invalid slots"))

(when
 (session-policy-eval
  '(element?
    AgenticAILabSessionPolicyContract
    (.o kind: 'agentic-ai-lab.session.policy
        schema: 'agentic-ai-lab.modules.session.policy.tool-permission.v1
        policy-kind: 'agent-tool-permission
        policy-name: 'policy/native-contract
        scope-ref: 'session/native-contract
        default-action: 'deny
        policy-slots: '()
        metadata: '()
        runtime-owner: 'marlin-agent-core
        runtime-executed: 'not-a-boolean)))
 (error "native session policy contract should reject invalid slots"))

(unless
 (session-policy-eval
  '(agentic-ai-lab-session-policy-require-slots!
    'agentic-ai-lab.session.policy
    'agentic-ai-lab.modules.session.policy.tool-permission.v1
    'agent-tool-permission
    'policy/test-tools
    'session/test
    'deny
    '((tool-grants . ())
      (denied-tool-refs . (write-workspace-file)))
    '((fixture . session-policy-contract))
    "marlin-agent-core"
    #f))
 (error "session policy slot checks should accept valid values"))

(unless
 (session-policy-eval
  '(agentic-ai-lab-session-tool-grant-require-slots!
    'agentic-ai-lab.session.tool-grant
    'agentic-ai-lab.modules.session.tool-grant.v1
    'grant/read
    'read-workspace-file
    '(read)
    '(project-workspace "reports/")
    '(agent-turn)
    '((fixture . session-policy-contract))
    #f))
 (error "session tool grant slot checks should accept valid values"))

(unless
 (session-policy-eval
  '(let* ((grant
           (agentic-ai-lab-session-tool-grant
            'grant/read
            'read-workspace-file
            '(read)
            '(project-workspace)
            '(agent-turn)))
          (policy
           (agentic-ai-lab-session-tool-permission-policy
            'policy/test-tools
            'session/test
            (list grant)
            '(write-workspace-file)
            'deny))
          (row (agentic-ai-lab-session-policy->alist policy)))
     (and (agentic-ai-lab-session-policy? policy)
          (= (alist-ref/default row 'tool-grant-count 0) 1)
          (not (alist-ref/default row 'runtime-executed #t)))))
 (error "session policy constructor should use valid contract-gated values"))

(when
 (session-policy-eval
  '(with-catch
    (lambda (_failure) #f)
    (lambda ()
      (agentic-ai-lab-session-tool-grant-require-slots!
       'agentic-ai-lab.session.tool-grant
       'agentic-ai-lab.modules.session.tool-grant.v1
       'grant/read
       'read-workspace-file
       '(read)
       '(project-workspace)
       '(agent-turn)
       '()
       'not-a-boolean)
      #t)))
 (error "session tool grant runtime-executed contract should reject invalid values")))))
