;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .cc)
        (only-in :clan/poo/type Bool Object Type. define-type)
        (only-in :clan/poo/type List OrFalse Record String Symbol))

(export GitOpsScopeContract
        GitOpsSourceCut
        GitOpsWorkingCopyPolicyType
        GitOpsCurrentFacts
        GitOpsReceipt
        GitOpsEvidenceState
        GitOpsAppliedWorkingCopy)

(define-type (NonemptyString @ Type.)
  .element?: (lambda (value)
               (and (string? value) (> (string-length value) 0))))

(define-type (PositiveRevision @ Type.)
  .element?: (lambda (value)
               (and (integer? value) (> value 0))))

(define-type (Callable @ Type.)
  .element?: procedure?)

(def WorkingCopyBinding
  (Record path: [String]
          branch: [(OrFalse String) optional: #t]))

(def GitOpsAppliedWorkingCopy
  (Record [WorkingCopyBinding] path: [NonemptyString]))

(def GitOpsSourceCut
  (.cc (Record project: [NonemptyString]
               worktree: [NonemptyString]
               path: [NonemptyString]
               git-head: [NonemptyString]
               text: [String])
       identity: 'gitops/source-cut))

(def GitOpsWorkingCopyPolicyType
  (.cc (Record select-provider: [Callable]
               preferred: [Symbol]
               allowed: [(List Symbol)])
       identity: 'gitops/working-copy-policy))

(def GitOpsCurrentFacts
  (.cc (Record source: [GitOpsSourceCut]
               request: [NonemptyString]
               policy-revision: [NonemptyString]
               provider: [Symbol]
               authorized?: [Bool]
               fence-current?: [Bool])
       identity: 'gitops/current-facts))

(def GitOpsReceipt
  (.cc (Record source: [GitOpsSourceCut]
               request: [NonemptyString]
               policy-revision: [NonemptyString]
               anchor: [NonemptyString]
               provider: [Symbol]
               outcome: [Symbol]
               custody-valid?: [Bool]
               executed?: [Bool]
               working-copy: [(OrFalse WorkingCopyBinding)])
       identity: 'gitops/receipt))

(def GitOpsEvidenceState
  (.cc (Record receipts: [(List GitOpsReceipt)]
               accepted-requests: [(List NonemptyString)]
               accepted?: [Bool]
               admitted?: [Bool]
               active-policy: [(OrFalse GitOpsWorkingCopyPolicyType)]
               active-request: [(OrFalse NonemptyString)]
               active-provider: [(OrFalse Symbol)]
               binding: [(OrFalse WorkingCopyBinding)])
       identity: 'gitops/evidence-state))

(def CreateContract
  (Record identity: [Symbol]
          effects-owner: [Symbol]
          revision: [PositiveRevision]
          inputs: [Object]
          predicates: [Object]))

(def GitOpsScopeContract
  (.cc (Record create-contract: [CreateContract]
               working-copy-policy: [GitOpsWorkingCopyPolicyType]
               bind-working-copy-policy: [Callable]
               select-working-copy: [Callable]
               working-copy-evidence: [Callable]
               admit-working-copy-receipt: [Callable]
               refresh-working-copy-evidence: [Callable])
       identity: 'gitops/scope))
