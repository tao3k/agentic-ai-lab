-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Init

namespace AgenticAILabProof.Enterprise.SandboxProfileRecipePathSyntaxModel

inductive RecipePath
  | projectRoot
  | relative (segments : List String)
  | posixAbsolute
  | windowsDriveAbsolute
  | windowsUncAbsolute
  | fileUri
  | traversal
deriving DecidableEq, Repr

inductive RecipeField
  | logicalSource (path : RecipePath)
  | runtimeTarget (path : RecipePath)
  | opaque (value : String)
deriving DecidableEq, Repr

def legacyLeadingSlashGuard : RecipeField → Prop
  | .logicalSource .posixAbsolute => False
  | .runtimeTarget .posixAbsolute => False
  | _ => True

def canonicalRelativeSegments (segments : List String) : Prop :=
  segments ≠ [] ∧
    ∀ segment ∈ segments,
      segment ≠ "" ∧ segment ≠ "." ∧ segment ≠ ".."

def portableLogicalSource : RecipePath → Prop
  | .projectRoot => True
  | .relative segments => canonicalRelativeSegments segments
  | _ => False

def portableRecipeField : RecipeField → Prop
  | .logicalSource path => portableLogicalSource path
  | .runtimeTarget _ => False
  | .opaque _ => True

def PortableRecipeSyntax (fields : List RecipeField) : Prop :=
  ∀ field ∈ fields, portableRecipeField field

theorem leadingSlashGuardAcceptsRelativeRuntimeTarget :
    legacyLeadingSlashGuard
      (.runtimeTarget (.relative ["runtime-owned"])) := by
  trivial

theorem portableSyntaxRejectsRelativeRuntimeTarget :
    ¬ PortableRecipeSyntax
      [.runtimeTarget (.relative ["runtime-owned"])] := by
  simp [PortableRecipeSyntax, portableRecipeField]

theorem leadingSlashGuardAcceptsTraversalSource :
    legacyLeadingSlashGuard (.logicalSource .traversal) := by
  trivial

theorem portableSyntaxRejectsTraversalSource :
    ¬ PortableRecipeSyntax [.logicalSource .traversal] := by
  simp [PortableRecipeSyntax, portableRecipeField, portableLogicalSource]

theorem leadingSlashGuardAcceptsWindowsDriveAbsolute :
    legacyLeadingSlashGuard (.logicalSource .windowsDriveAbsolute) := by
  trivial

theorem leadingSlashGuardAcceptsWindowsUncAbsolute :
    legacyLeadingSlashGuard (.logicalSource .windowsUncAbsolute) := by
  trivial

theorem leadingSlashGuardAcceptsFileUri :
    legacyLeadingSlashGuard (.logicalSource .fileUri) := by
  trivial

theorem portableSyntaxRejectsAlternateAbsoluteForms :
    ¬ PortableRecipeSyntax
        [ .logicalSource .windowsDriveAbsolute,
          .logicalSource .windowsUncAbsolute,
          .logicalSource .fileUri ] := by
  simp [PortableRecipeSyntax, portableRecipeField, portableLogicalSource]

theorem projectRootSourceIsPortable :
    PortableRecipeSyntax [.logicalSource .projectRoot] := by
  simp [PortableRecipeSyntax, portableRecipeField, portableLogicalSource]

theorem canonicalRelativeSourceIsPortable :
    PortableRecipeSyntax
      [.logicalSource (.relative ["src", "module"])] := by
  simp [PortableRecipeSyntax, portableRecipeField, portableLogicalSource,
    canonicalRelativeSegments]

end AgenticAILabProof.Enterprise.SandboxProfileRecipePathSyntaxModel
