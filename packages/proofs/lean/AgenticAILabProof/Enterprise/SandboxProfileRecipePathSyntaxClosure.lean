-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.Enterprise.SandboxProfileRecipePathSyntaxModel
import AgenticAILabProof.Enterprise.SandboxProfileRecipePortabilityClosure

namespace AgenticAILabProof.Enterprise.SandboxProfileRecipePathSyntaxClosure

open AgenticAILabProof.Enterprise.SandboxProfileRecipePathSyntaxModel
open AgenticAILabProof.Enterprise.SandboxProfileRecipePortabilityClosure

theorem syntaxAndMaterializationOwnershipCompose
    (fields : List RecipeField)
    (syntaxPortable : PortableRecipeSyntax fields)
    (recipe : PortableRecipe)
    (policy : BackendMaterializationPolicy) :
    PortableRecipeSyntax fields ∧
      receiptClosesRecipe recipe (materialize recipe policy) ∧
      (materialize recipe policy).runtimeTarget =
        policy.targetFor recipe.backendIdentity recipe.resourceRole := by
  exact
    ⟨syntaxPortable,
      everyBackendMaterializationClosesThePortableRecipe recipe policy,
      (runtimeTargetIsOwnedOnlyByTheMaterializationReceipt recipe policy).1⟩

theorem portableDeclarationCannotEmbedRuntimeTarget
    (path : RecipePath) :
    ¬ PortableRecipeSyntax [.runtimeTarget path] := by
  simp [PortableRecipeSyntax, portableRecipeField]

end AgenticAILabProof.Enterprise.SandboxProfileRecipePathSyntaxClosure
