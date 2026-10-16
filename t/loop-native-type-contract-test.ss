;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: loop governor and human audit expose native POO Contracts.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test)

(def (loop-contract-eval expr)
  (eval expr))

(def (alist-ref/default entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

(def (contract-slot-names row)
  (map (lambda (slot-row)
         (alist-ref/default slot-row 'slot #f))
       (alist-ref/default row 'slots '())))

(export loop-native-type-contract-test)

(def loop-native-type-contract-test
  (test-suite "loop-native-type-contract-test"
    (poo-flow-test-case "validates the native contract"
      (eval '(import "./modules/loop-engine/control/descriptor.ss"))
      (eval '(import "./modules/loop-engine/control/strategy.ss"))
      (eval '(import "./modules/loop-engine/control/governor.ss"))
      (eval '(import "./modules/loop-engine/control/human-audit.ss"))
      (eval '(import :clan/poo/mop :clan/poo/object))
      (let (node-row
      (loop-contract-eval '(loop-governor-node-type-contract->alist)))
  (unless (and (eq? (alist-ref/default node-row 'object-kind #f)
                    'LoopGovernorNode)
               (equal? (contract-slot-names node-row)
                       '(name governance-node-kind governance-responsibility
                         human-intervention control-owner execution-owner
                         metadata)))
    (error "native governor node contract should expose governance slots")))

(let (governor-row
      (loop-contract-eval '(loop-governor-type-contract->alist)))
  (unless (and (eq? (alist-ref/default governor-row 'object-kind #f)
                    'LoopGovernor)
               (member 'strategy (contract-slot-names governor-row))
               (member 'agent-judge-nodes (contract-slot-names governor-row)))
    (error "native governor contract should expose governance slots")))

(let (audit-row
      (loop-contract-eval '(loop-human-audit-type-contract->alist)))
  (unless (and (eq? (alist-ref/default audit-row 'object-kind #f)
                    'LoopHumanAudit)
               (member 'governor (contract-slot-names audit-row))
               (member 'state-facts (contract-slot-names audit-row))
               (member 'decisions (contract-slot-names audit-row))
               (member 'decision-owner (contract-slot-names audit-row)))
    (error "native human audit contract should expose review slots")))

(unless
 (loop-contract-eval
  '(let* ((pattern
          (make-loop-pattern-descriptor
           'repair
           "Repair one controlled target."
           '((level . l1) (metadata . ((acting_on . "src/a"))))))
         (strategy
          (make-loop-strategy-plan 'maintenance (list pattern)))
         (governor
          (make-loop-governor 'repo-governor strategy))
         (audit
          (make-loop-human-audit
           'human-review governor '() '((repair . approved)))))
     (and (element? Type +loop-governor-node-type-contract+)
          (element? Type +loop-governor-type-contract+)
          (element? Type +loop-human-audit-type-contract+)
          (element? +loop-governor-type-contract+ governor)
          (element? +loop-human-audit-type-contract+ audit))))
 (error "loop contracts should be native Types and admit valid objects"))

(when
 (loop-contract-eval
  '(with-catch
    (lambda (_failure) #f)
    (lambda ()
      (loop-governor-require-node-slots!
       'judge 'agent 'review 'not-a-boolean 'gerbil 'marlin-agent-core '())
      #t)))
 (error "native governor contract should reject an invalid slot"))

(when
 (loop-contract-eval
  '(with-catch
    (lambda (_failure) #f)
    (lambda ()
      (let* ((pattern
              (make-loop-pattern-descriptor
               'repair "Repair one target." '((level . l1))))
             (strategy
              (make-loop-strategy-plan 'maintenance (list pattern))))
        (loop-governor-require-slots!
         'repo-governor strategy '() '(42) '((field . acting_on))
         '((mode . acting_on)) '((max-actionable . 1))
         '((mode . multi-agent-governance))
         (list (make-loop-governor-agent-node 'repo-auditor 'audit))
         '((target . human-inbox))
         '((target . marlin-agent-core) (transport . scheme-abi))
         'gerbil 'marlin-agent-core '()))
      #t)))
 (error "native governor contract should reject unsupported action keys"))

(when
 (loop-contract-eval
  '(with-catch
    (lambda (_failure) #f)
    (lambda ()
      (let* ((pattern
              (make-loop-pattern-descriptor
               'repair "Repair one target." '((level . l1))))
             (strategy
              (make-loop-strategy-plan 'maintenance (list pattern)))
             (governor
              (make-loop-governor 'repo-governor strategy)))
        (loop-human-audit-require-slots!
         'human-review governor #f '() '((repair . unsupported))
         '((mode . review-loop)) #t 'human #t 'gerbil 'human
         'marlin-agent-core '()))
      #t)))
 (error "native human audit contract should reject invalid decisions")))))
