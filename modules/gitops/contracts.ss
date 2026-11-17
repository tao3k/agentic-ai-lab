;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Library-owned semantic predicates. Execution facts come from the consumer's
;;; Provider contract; evaluating a predicate neither authenticates nor executes.
(import "types.ss" (only-in :clan/poo/object .o))
(export GitOpsCreateContract gitops-create-source-current?
        gitops-create-semantic-admit? gitops-create-retain-current?)

(def (gitops-create-source-current? project worktree path bytes head)
  (and project worktree path bytes head))
(def (gitops-create-semantic-admit? authorized fence-current source policy receipt-source receipt-policy
                                   anchor fresh-request request custody executed provider applied binding)
  (and authorized fence-current source policy receipt-source receipt-policy anchor fresh-request
       request custody executed provider applied binding))
(def (gitops-create-retain-current? accepted active-policy active-request active-provider
                                   authorized fence-current source policy)
  (and accepted active-policy active-request active-provider authorized fence-current source policy))

(def GitOpsCreateContract
  (.o identity: 'agentic-ai-lab.gitops.create
      revision: 4
      operations: '(create)
      provider-extension: 'poo-policy-and-availability
      source: '(project worktree path text git-head anchor policy-revision)
      effects-owner: 'downstream-provider
      policy-lifecycle:
      (.o derivation: 'intersect-parent-capabilities-and-inherit-selector
          replacement: 'explicit-policy-value-and-definition-revision
          current-use: 'exact-active-policy-and-current-observations
          historical-evidence: 'retain-without-automatic-readoption)
      inputs:
      (.o source: GitOpsSourceCut
          parent-policy: GitOpsWorkingCopyPolicyType
          current: GitOpsCurrentFacts
          receipt: GitOpsReceipt
          evidence: GitOpsEvidenceState)
      predicates:
      (.o source-current?: gitops-create-source-current?
          semantic-admit?: gitops-create-semantic-admit?
          retain-current?: gitops-create-retain-current?)
      obligations: '(source-current policy-current grant-current receipt-custody
                     selected-provider actual-binding once-only retained-evidence)))
