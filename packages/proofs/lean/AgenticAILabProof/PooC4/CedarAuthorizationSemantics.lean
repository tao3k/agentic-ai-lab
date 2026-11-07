-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Cedar.Thm.Authorization

namespace AgenticAILabProof.PooC4.CedarAuthorizationSemantics

/-!
An exact local owner for the pinned Cedar definitional authorization semantics.

This module deliberately retains `Cedar.Spec.Response` without projecting it
into the runtime arbitration envelope.  Cedar's response owns a decision plus
determining and erroring policy sets; runtime timeout/crash diagnostics are a
separate Agentic AI Lab evidence layer.
-/

structure CedarAuthorizationInput where
  request : Cedar.Spec.Request
  entities : Cedar.Spec.Entities
  policies : Cedar.Spec.Policies

def authorize (input : CedarAuthorizationInput) : Cedar.Spec.Response :=
  Cedar.Spec.isAuthorized input.request input.entities input.policies

theorem authorization_is_deterministic
    (input : CedarAuthorizationInput) :
    authorize input = authorize input := by
  rfl

theorem response_retains_decision
    (input : CedarAuthorizationInput) :
    (authorize input).decision =
      (Cedar.Spec.isAuthorized
        input.request input.entities input.policies).decision := by
  rfl

theorem response_retains_determining_policies
    (input : CedarAuthorizationInput) :
    (authorize input).determiningPolicies =
      (Cedar.Spec.isAuthorized
        input.request input.entities input.policies).determiningPolicies := by
  rfl

theorem response_retains_erroring_policies
    (input : CedarAuthorizationInput) :
    (authorize input).erroringPolicies =
      (Cedar.Spec.isAuthorized
        input.request input.entities input.policies).erroringPolicies := by
  rfl

theorem forbid_forces_deny
    (input : CedarAuthorizationInput)
    (forbidden :
      Cedar.Thm.IsExplicitlyForbidden
        input.request input.entities input.policies) :
    (authorize input).decision = Cedar.Spec.Decision.deny := by
  exact Cedar.Thm.forbid_trumps_permit
    input.request input.entities input.policies forbidden

theorem absence_of_permit_forces_deny
    (input : CedarAuthorizationInput)
    (notPermitted :
      ¬Cedar.Thm.IsExplicitlyPermitted
        input.request input.entities input.policies) :
    (authorize input).decision = Cedar.Spec.Decision.deny := by
  exact Cedar.Thm.default_deny
    input.request input.entities input.policies notPermitted

theorem allow_requires_explicit_permit
    (input : CedarAuthorizationInput)
    (allowed :
      (authorize input).decision = Cedar.Spec.Decision.allow) :
    Cedar.Thm.IsExplicitlyPermitted
      input.request input.entities input.policies := by
  exact Cedar.Thm.allowed_only_if_explicitly_permitted
    input.request input.entities input.policies allowed

theorem allow_iff_permitted_and_not_forbidden
    (input : CedarAuthorizationInput) :
    Cedar.Thm.IsExplicitlyPermitted
        input.request input.entities input.policies ∧
      ¬Cedar.Thm.IsExplicitlyForbidden
        input.request input.entities input.policies ↔
      (authorize input).decision = Cedar.Spec.Decision.allow := by
  exact Cedar.Thm.allowed_iff_explicitly_permitted_and_not_denied
    input.request input.entities input.policies

theorem policy_order_and_duplicates_are_nonsemantic
    (request : Cedar.Spec.Request)
    (entities : Cedar.Spec.Entities)
    (left right : Cedar.Spec.Policies)
    (equivalent : left ≡ right) :
    authorize
        { request := request
          entities := entities
          policies := left } =
      authorize
        { request := request
          entities := entities
          policies := right } := by
  exact Cedar.Thm.order_and_dup_independent
    request entities left right equivalent

theorem unique_policy_ids_separate_determining_and_erroring
    (input : CedarAuthorizationInput)
    (unique : Cedar.Thm.PolicyIdsUnique input.policies) :
    ((authorize input).determiningPolicies ∩
      (authorize input).erroringPolicies).isEmpty = true := by
  exact Cedar.Thm.determining_erroring_disjoint_when_unique_ids
    input.request input.entities input.policies unique

theorem extensionally_equal_policy_evaluation_preserves_response
    {policies : Cedar.Spec.Policies}
    {leftRequest rightRequest : Cedar.Spec.Request}
    {leftEntities rightEntities : Cedar.Spec.Entities}
    (sameEvaluation :
      ∀ policy,
        policy ∈ policies →
          Cedar.Spec.evaluate
              policy.toExpr leftRequest leftEntities =
            Cedar.Spec.evaluate
              policy.toExpr rightRequest rightEntities) :
    authorize
        { request := leftRequest
          entities := leftEntities
          policies := policies } =
      authorize
        { request := rightRequest
          entities := rightEntities
          policies := policies } := by
  exact Cedar.Thm.is_authorized_congr_evaluate sameEvaluation

end AgenticAILabProof.PooC4.CedarAuthorizationSemantics
