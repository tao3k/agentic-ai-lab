;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: reusable workloads for native Type/Contract performance gates.
;;; Invariant: workloads measure Scheme contract operations, not gxi startup,
;;; package loading, Lean execution, or Marlin runtime work.

(import (only-in "./performance.ss"
                 agentic-ai-lab-performance-build-list)
        (only-in :yuanxu/module-system/schema/slot-contracts
                 yuanxu-contract-check-slot!
                 yuanxu-contract-slot
                 yuanxu-contract-value-type
                 yuanxu-object-contract
                 yuanxu-object-contract->alist
                 yuanxu-object-contract-slots)
        (only-in :yuanxu/type-facts/objects
                 yuanxu-object-contract->type-facts
                 yuanxu-object-contract->lean-fact-contracts)
        (only-in :agentic-ai-lab/modules/session/policy
                 AgenticAILabSessionPolicyContract
                 AgenticAILabSessionToolGrantContract
                 agentic-ai-lab-session-policy-require-slots!
                 agentic-ai-lab-session-tool-grant-require-slots!))

(export type-contract-performance-slot-name
        type-contract-performance-slot-contract
        type-contract-performance-object-contract
        type-contract-performance-values
        type-contract-performance-check-slots-once
        type-contract-performance-check-slots-rounds
        type-contract-performance-object-family-check-count
        type-contract-performance-object-contract-alist-rounds
        type-contract-performance-type-facts-rounds
        type-contract-performance-lean-facts-rounds
        type-contract-performance-cached-type-facts-rounds
        type-contract-performance-session-policy-projection-rounds
        type-contract-performance-session-tool-grant-projection-rounds
        type-contract-performance-session-policy-require-rounds
        type-contract-performance-session-tool-grant-require-rounds)

;; : (-> Integer Symbol)
(def (type-contract-performance-slot-name index)
  (string->symbol
   (string-append "contract-slot-" (number->string index))))

;; : (-> Integer YuanxuSlotContract)
(def (type-contract-performance-slot-contract index)
  (let (slot-name (type-contract-performance-slot-name index))
    (yuanxu-contract-slot
     (string->symbol
      (string-append "type-contract.performance/"
                     (number->string index)))
     slot-name
     (yuanxu-contract-value-type 'Symbol symbol? 'Symbol 'symbol?)
     #t
     (list (cons 'scenario 'type-contract-performance)
           (cons 'slot-index index)))))

;; : (-> Integer YuanxuObjectTypeContract)
(def (type-contract-performance-object-contract slot-count)
  (yuanxu-object-contract
   'type-contract/performance
   'type-contract-performance
   'AgenticAILabTypeContractPerformanceObject
   (lambda (_candidate) #t)
   (agentic-ai-lab-performance-build-list
    slot-count
    type-contract-performance-slot-contract)
   '((projection . performance))))

;; : (-> Integer [Symbol])
(def (type-contract-performance-values slot-count)
  (agentic-ai-lab-performance-build-list
   slot-count
   type-contract-performance-slot-name))

;; type-contract-performance-check-slots-once
;;   : (-> YuanxuObjectTypeContract [Symbol] Integer)
;;   | doc m%
;;       Checks each slot contract against the matching symbol value once and
;;       returns the number of validated slots for the benchmark receipt.
;;
;;       # Examples
;;       ```scheme
;;       (type-contract-performance-check-slots-once
;;        (type-contract-performance-object-contract 1)
;;        (type-contract-performance-values 1))
;;       ;; => 1
;;       ```
;;     %
(def (type-contract-performance-check-slots-once object-contract values)
  (for-each yuanxu-contract-check-slot!
            (yuanxu-object-contract-slots object-contract)
            values)
  (length values))

;; type-contract-performance-repeat
;;   : (-> Integer (-> Integer) Integer)
;;   | doc m%
;;       Executes a benchmark workload exactly `rounds` times and folds the
;;       numeric results without hiding the workload side effects.
;;
;;       # Examples
;;       ```scheme
;;       (type-contract-performance-repeat 3 (lambda () 1))
;;       ;; => 3
;;       ```
;;     %
(def (type-contract-performance-repeat rounds workload)
  (if (<= rounds 0)
    0
    (fold (lambda (_round total)
            (+ total (workload)))
          0
          (iota rounds))))

;; : (-> Integer Integer Integer)
(def (type-contract-performance-check-slots-rounds slot-count rounds)
  (let ((object-contract
         (type-contract-performance-object-contract slot-count))
        (values
         (type-contract-performance-values slot-count)))
    (type-contract-performance-repeat
     rounds
     (lambda ()
       (type-contract-performance-check-slots-once object-contract values)))))

;; : (-> Integer Integer Integer)
(def (type-contract-performance-object-family-check-count object-count
                                                          slot-count)
  (let ((object-contract
         (type-contract-performance-object-contract slot-count))
        (values
         (type-contract-performance-values slot-count)))
    (type-contract-performance-repeat
     object-count
     (lambda ()
       (type-contract-performance-check-slots-once object-contract values)))))

;; : (-> Integer Integer Integer)
(def (type-contract-performance-object-contract-alist-rounds slot-count rounds)
  (let (object-contract
        (type-contract-performance-object-contract slot-count))
    (type-contract-performance-repeat
     rounds
     (lambda ()
       (length
        (cdr (assoc 'slots
                    (yuanxu-object-contract->alist
                     object-contract))))))))

;; : (-> Integer Integer Integer)
(def (type-contract-performance-type-facts-rounds slot-count rounds)
  (let (object-contract
        (type-contract-performance-object-contract slot-count))
    (type-contract-performance-repeat
     rounds
     (lambda ()
       (length
        (yuanxu-object-contract->type-facts object-contract))))))

;; : (-> Integer Integer Integer)
(def (type-contract-performance-lean-facts-rounds slot-count rounds)
  (let (object-contract
        (type-contract-performance-object-contract slot-count))
    (type-contract-performance-repeat
     rounds
     (lambda ()
       (length
        (yuanxu-object-contract->lean-fact-contracts
         object-contract))))))

;;; Boundary: cached projections model agent-loop hot paths. Contract facts are
;;; immutable declaration data and should be projected once before repeated
;;; reads by doctor, observability, or runtime-handoff presentation code.
;; : (-> Integer Integer Integer)
(def (type-contract-performance-cached-type-facts-rounds slot-count rounds)
  (let (facts
        (yuanxu-object-contract->type-facts
         (type-contract-performance-object-contract slot-count)))
    (type-contract-performance-repeat
     rounds
     (lambda ()
       (length facts)))))

;; : (-> Integer Integer)
(def (type-contract-performance-session-policy-projection-rounds rounds)
  (type-contract-performance-repeat
   rounds
   (lambda ()
     (length
      (yuanxu-object-contract->alist
       AgenticAILabSessionPolicyContract)))))

;; : (-> Integer Integer)
(def (type-contract-performance-session-tool-grant-projection-rounds rounds)
  (type-contract-performance-repeat
   rounds
   (lambda ()
     (length
      (yuanxu-object-contract->alist
       AgenticAILabSessionToolGrantContract)))))

;; : (-> Integer Integer)
(def (type-contract-performance-session-policy-require-rounds rounds)
  (type-contract-performance-repeat
   rounds
   (lambda ()
     (agentic-ai-lab-session-policy-require-slots!
      'agentic-ai-lab.session.policy
      'agentic-ai-lab.modules.session.policy.tool-permission.v1
      'agent-tool-permission
      'policy/performance-tools
      'session/performance
      'deny
      '((tool-grants . ())
        (denied-tool-refs . (write-workspace-file)))
      '((fixture . type-contract-performance))
      "marlin-agent-core"
      #f)
     1)))

;; : (-> Integer Integer)
(def (type-contract-performance-session-tool-grant-require-rounds rounds)
  (type-contract-performance-repeat
   rounds
   (lambda ()
     (agentic-ai-lab-session-tool-grant-require-slots!
      'agentic-ai-lab.session.tool-grant
      'agentic-ai-lab.modules.session.tool-grant.v1
      'grant/performance-read
      'read-workspace-file
      '(read)
      '(project-workspace)
      '(agent-turn)
      '((fixture . type-contract-performance))
      #f)
     1)))
