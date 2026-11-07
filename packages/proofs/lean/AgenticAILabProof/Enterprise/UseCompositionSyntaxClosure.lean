-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.UseCompositionSyntaxClosure

/-!
RFC45-07 requires more than generic profile-composition closure.  The public
surface is the single `use-composition` macro, its module header and body are
parsed fail closed, and aliases are hygienic lexical bindings rather than
semantic module identities.  This file models that exact boundary.
-/

abbrev ModuleIdentity := Nat
abbrev ProfileIdentity := Nat
abbrev StageIdentity := Nat
abbrev ScopeIdentity := Nat

structure HygienicIdentifier where
  spelling : String
  scope : ScopeIdentity
deriving DecidableEq, Repr

inductive RawModuleClause where
  | useModuleAs (moduleIdentity : ModuleIdentity) (alias : HygienicIdentifier)
  | malformed
deriving DecidableEq, Repr

inductive RawBodyClause where
  | compose (profiles : List ProfileIdentity)
  | stage (stageIdentity : StageIdentity) (dependencies : List StageIdentity)
  | unsupported
deriving DecidableEq, Repr

inductive CanonicalBodyClause where
  | compose (profiles : List ProfileIdentity)
  | stage (stageIdentity : StageIdentity) (dependencies : List StageIdentity)
deriving DecidableEq, Repr

inductive RawCompositionSurface where
  | useComposition
      (compositionName : HygienicIdentifier)
      (moduleClause : RawModuleClause)
      (body : List RawBodyClause)
  | userComposition
      (compositionName : HygienicIdentifier)
      (moduleClause : RawModuleClause)
      (body : List RawBodyClause)
  | nestedUseComposition (compositionName : HygienicIdentifier)
  | initial (profiles : List ProfileIdentity)
  | mixModule (moduleIdentity : ModuleIdentity)
deriving DecidableEq, Repr

inductive ParseError where
  | nonCanonicalOuterForm
  | invalidModuleHeader
  | invalidBodyClause
  | missingProfileOperand
  | duplicateStage
deriving DecidableEq, Repr

structure CanonicalCompositionPlan where
  compositionName : HygienicIdentifier
  moduleIdentity : ModuleIdentity
  alias : HygienicIdentifier
  body : List CanonicalBodyClause
deriving DecidableEq, Repr

def lowerBodyClause : RawBodyClause → Option CanonicalBodyClause
  | .compose profiles => some (.compose profiles)
  | .stage stageIdentity dependencies =>
      some (.stage stageIdentity dependencies)
  | .unsupported => none

def lowerBody : List RawBodyClause → Option (List CanonicalBodyClause)
  | [] => some []
  | clause :: rest => do
      let loweredClause ← lowerBodyClause clause
      let loweredRest ← lowerBody rest
      pure (loweredClause :: loweredRest)

def stageIdentities : List CanonicalBodyClause → List StageIdentity
  | [] => []
  | .compose _ :: rest => stageIdentities rest
  | .stage stageIdentity _ :: rest => stageIdentity :: stageIdentities rest

def containsProfileOperand : List CanonicalBodyClause → Bool
  | [] => false
  | .compose [] :: rest => containsProfileOperand rest
  | .compose (_ :: _) :: _ => true
  | .stage _ _ :: rest => containsProfileOperand rest

def parse : RawCompositionSurface → Except ParseError CanonicalCompositionPlan
  | .useComposition compositionName moduleClause body =>
      match moduleClause with
      | .malformed => .error .invalidModuleHeader
      | .useModuleAs moduleIdentity alias =>
          match lowerBody body with
          | none => .error .invalidBodyClause
          | some loweredBody =>
              if containsProfileOperand loweredBody then
                if (stageIdentities loweredBody).Nodup then
                  .ok {
                    compositionName
                    moduleIdentity
                    alias
                    body := loweredBody
                  }
                else
                  .error .duplicateStage
              else
                .error .missingProfileOperand
  | .userComposition _ _ _ => .error .nonCanonicalOuterForm
  | .nestedUseComposition _ => .error .nonCanonicalOuterForm
  | .initial _ => .error .nonCanonicalOuterForm
  | .mixModule _ => .error .nonCanonicalOuterForm

def ParserAccepted (surface : RawCompositionSurface) : Prop :=
  ∃ plan, parse surface = .ok plan

theorem parserAcceptanceImpliesSingleUseComposition
    {surface : RawCompositionSurface}
    (accepted : ParserAccepted surface) :
    ∃ compositionName moduleClause body,
      surface = .useComposition compositionName moduleClause body := by
  rcases accepted with ⟨plan, parsed⟩
  cases surface with
  | useComposition compositionName moduleClause body =>
      exact ⟨compositionName, moduleClause, body, rfl⟩
  | userComposition compositionName moduleClause body =>
      simp [parse] at parsed
  | nestedUseComposition compositionName =>
      simp [parse] at parsed
  | initial profiles =>
      simp [parse] at parsed
  | mixModule moduleIdentity =>
      simp [parse] at parsed

theorem acceptedPlanContainsProfileOperand
    {surface : RawCompositionSurface}
    {plan : CanonicalCompositionPlan}
    (parsed : parse surface = .ok plan) :
    containsProfileOperand plan.body = true := by
  cases surface with
  | useComposition compositionName moduleClause body =>
      cases moduleClause with
      | malformed =>
          simp [parse] at parsed
      | useModuleAs moduleIdentity alias =>
          cases lowered : lowerBody body with
          | none =>
              simp [parse, lowered] at parsed
          | some loweredBody =>
              simp only [parse, lowered] at parsed
              split at parsed
              next hasProfiles =>
                split at parsed
                next uniqueStages =>
                  cases parsed
                  exact hasProfiles
                next duplicateStages =>
                  contradiction
              next missingProfiles =>
                contradiction
  | userComposition compositionName moduleClause body =>
      simp [parse] at parsed
  | nestedUseComposition compositionName =>
      simp [parse] at parsed
  | initial profiles =>
      simp [parse] at parsed
  | mixModule moduleIdentity =>
      simp [parse] at parsed

theorem malformedModuleHeaderFailsClosed
    (compositionName : HygienicIdentifier)
    (body : List RawBodyClause) :
    parse (.useComposition compositionName .malformed body) =
      .error .invalidModuleHeader := by
  rfl

theorem unsupportedBodyClauseFailsClosed
    (compositionName alias : HygienicIdentifier)
    (moduleIdentity : ModuleIdentity) :
    parse
        (.useComposition compositionName
          (.useModuleAs moduleIdentity alias)
          [.unsupported]) =
      .error .invalidBodyClause := by
  rfl

theorem emptyCompositionFailsClosed
    (compositionName alias : HygienicIdentifier)
    (moduleIdentity : ModuleIdentity) :
    parse
        (.useComposition compositionName
          (.useModuleAs moduleIdentity alias)
          []) =
      .error .missingProfileOperand := by
  rfl

theorem stageOnlyCompositionFailsClosed
    (compositionName alias : HygienicIdentifier)
    (moduleIdentity : ModuleIdentity)
    (stageIdentity : StageIdentity) :
    parse
        (.useComposition compositionName
          (.useModuleAs moduleIdentity alias)
          [.stage stageIdentity []]) =
      .error .missingProfileOperand := by
  rfl

theorem nestedWrapperFailsClosed
    (compositionName : HygienicIdentifier) :
    parse (.nestedUseComposition compositionName) =
      .error .nonCanonicalOuterForm := by
  rfl

def duplicateStageSurface : RawCompositionSurface :=
  .useComposition
    { spelling := "enterprise", scope := 7 }
    (.useModuleAs 11 { spelling := "industry", scope := 8 })
    [
      .stage 3 [],
      .compose [17, 19],
      .stage 3 [3]
    ]

theorem duplicateStageFailsClosed :
    parse duplicateStageSurface = .error .duplicateStage := by
  rfl

def resolvesTo
    (reference binding : HygienicIdentifier) : Prop :=
  reference = binding

def nameOnlyResolves
    (reference binding : HygienicIdentifier) : Prop :=
  reference.spelling = binding.spelling

theorem freshScopePreventsAliasCapture
    (spelling : String)
    {outerScope macroScope : ScopeIdentity}
    (fresh : macroScope ≠ outerScope) :
    ¬ resolvesTo
      { spelling, scope := macroScope }
      { spelling, scope := outerScope } := by
  intro captured
  exact fresh (congrArg HygienicIdentifier.scope captured)

def outerArtifact : HygienicIdentifier :=
  { spelling := "artifact", scope := 0 }

def generatedArtifactAlias : HygienicIdentifier :=
  { spelling := "artifact", scope := 1 }

theorem nameOnlyResolutionAdmitsCaptureCounterexample :
    nameOnlyResolves generatedArtifactAlias outerArtifact ∧
      ¬ resolvesTo generatedArtifactAlias outerArtifact := by
  constructor
  · rfl
  · simp [resolvesTo, generatedArtifactAlias, outerArtifact]

def composedProfiles : List CanonicalBodyClause → List ProfileIdentity
  | [] => []
  | .compose profiles :: rest => profiles ++ composedProfiles rest
  | .stage _ _ :: rest => composedProfiles rest

structure SemanticComposition where
  moduleIdentity : ModuleIdentity
  profiles : List ProfileIdentity
  stages : List StageIdentity
deriving DecidableEq, Repr

def semanticProjection
    (plan : CanonicalCompositionPlan) : SemanticComposition :=
  {
    moduleIdentity := plan.moduleIdentity
    profiles := composedProfiles plan.body
    stages := stageIdentities plan.body
  }

def renameAlias
    (plan : CanonicalCompositionPlan)
    (alias : HygienicIdentifier) : CanonicalCompositionPlan :=
  { plan with alias }

theorem aliasIsPresentationNotSemanticIdentity
    (plan : CanonicalCompositionPlan)
    (alias : HygienicIdentifier) :
    semanticProjection (renameAlias plan alias) = semanticProjection plan := by
  rfl

structure GenericCompositionSummary where
  moduleIdentity : ModuleIdentity
  profiles : List ProfileIdentity
deriving DecidableEq, Repr

def rawProfiles : List RawBodyClause → List ProfileIdentity
  | [] => []
  | .compose profiles :: rest => profiles ++ rawProfiles rest
  | _ :: rest => rawProfiles rest

def genericProjection : RawCompositionSurface → Option GenericCompositionSummary
  | .useComposition _ (.useModuleAs moduleIdentity _) body =>
      some { moduleIdentity, profiles := rawProfiles body }
  | .userComposition _ (.useModuleAs moduleIdentity _) body =>
      some { moduleIdentity, profiles := rawProfiles body }
  | _ => none

def canonicalCounterexampleTwin : RawCompositionSurface :=
  .useComposition
    { spelling := "enterprise", scope := 2 }
    (.useModuleAs 5 { spelling := "industry", scope := 3 })
    [.compose [13, 21]]

def nonCanonicalUserCompositionCounterexample : RawCompositionSurface :=
  .userComposition
    { spelling := "enterprise", scope := 2 }
    (.useModuleAs 5 { spelling := "industry", scope := 3 })
    [.compose [13, 21]]

theorem genericCompositionClosureDoesNotEstablishPublicSyntax :
    genericProjection nonCanonicalUserCompositionCounterexample =
        genericProjection canonicalCounterexampleTwin ∧
      parse nonCanonicalUserCompositionCounterexample =
        .error .nonCanonicalOuterForm := by
  constructor <;> rfl

theorem canonicalCounterexampleTwinIsAccepted :
    ParserAccepted canonicalCounterexampleTwin := by
  refine ⟨?_, ?_⟩
  · exact {
      compositionName := { spelling := "enterprise", scope := 2 }
      moduleIdentity := 5
      alias := { spelling := "industry", scope := 3 }
      body := [.compose [13, 21]]
    }
  · rfl

end AgenticAILabProof.Enterprise.UseCompositionSyntaxClosure
