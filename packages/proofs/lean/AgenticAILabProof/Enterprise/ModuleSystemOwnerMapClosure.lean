-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

namespace AgenticAILabProof.Enterprise.ModuleSystemOwnerMapClosure

inductive RowIdentity
  | mixModuleExpansion
  | g0Decision
  | runtimeContextRecovery
  | observabilitySnapshot
  | lineageCycle
  | gerbilPooConsumption
  | publicComposition
  | parentQualification
  deriving DecidableEq, Repr

inductive ImplementationState
  | declared
  | partiallyImplemented
  | implemented
  deriving DecidableEq, Repr

structure OwnerMapRow where
  identity : RowIdentity
  sourcePath : String
  sourceSymbol : String
  testPath : String
  testSymbol : String
  buildTarget : String
  state : ImplementationState
  parentOwned : Bool
  deriving DecidableEq, Repr

structure OwnerAuthority where
  sourcePath : RowIdentity → String
  sourceSymbol : RowIdentity → String
  testPath : RowIdentity → String
  testSymbol : RowIdentity → String
  buildTarget : RowIdentity → String

structure OwnerMapContract where
  schemaId : String
  schemaVersion : Nat
  rows : List OwnerMapRow
  deriving DecidableEq, Repr

def requiredRowIdentities : List RowIdentity :=
  [ .mixModuleExpansion
  , .g0Decision
  , .runtimeContextRecovery
  , .observabilitySnapshot
  , .lineageCycle
  , .gerbilPooConsumption
  , .publicComposition
  , .parentQualification
  ]

def rowClosed (authority : OwnerAuthority) (row : OwnerMapRow) : Prop :=
  row.state = .implemented ∧
  row.parentOwned = true ∧
  row.sourcePath = authority.sourcePath row.identity ∧
  row.sourceSymbol = authority.sourceSymbol row.identity ∧
  row.testPath = authority.testPath row.identity ∧
  row.testSymbol = authority.testSymbol row.identity ∧
  row.buildTarget = authority.buildTarget row.identity

def contractClosed (authority : OwnerAuthority) (contract : OwnerMapContract) : Prop :=
  contract.schemaId = "agentic-ai-lab.module-system-owner-map" ∧
  contract.schemaVersion = 1 ∧
  contract.rows.map OwnerMapRow.identity = requiredRowIdentities ∧
  ∀ row ∈ contract.rows, rowClosed authority row

def permissiveImplementationAdmission (row : OwnerMapRow) : Prop :=
  row.state = .implemented

def exampleAuthority : OwnerAuthority where
  sourcePath := fun _ => "parent/source.ss"
  sourceSymbol := fun _ => "source-owner"
  testPath := fun _ => "parent/test.ss"
  testSymbol := fun _ => "test-owner"
  buildTarget := fun _ => "//parent:source"

def staleSelectorRow : OwnerMapRow where
  identity := .parentQualification
  sourcePath := "parent/source.ss"
  sourceSymbol := "stale-owner-selector"
  testPath := "parent/test.ss"
  testSymbol := "test-owner"
  buildTarget := "//parent:source"
  state := .implemented
  parentOwned := true

def descendantLifecycleRow : OwnerMapRow where
  identity := .parentQualification
  sourcePath := "packages/lambda-episteme/build.ss"
  sourceSymbol := "child-build"
  testPath := "packages/lambda-episteme/test.ss"
  testSymbol := "child-tests"
  buildTarget := "//packages/lambda-episteme:all"
  state := .implemented
  parentOwned := false

def missingRowsContract : OwnerMapContract where
  schemaId := "agentic-ai-lab.module-system-owner-map"
  schemaVersion := 1
  rows := []

theorem implementedStateAloneAcceptsStaleSelector :
    permissiveImplementationAdmission staleSelectorRow ∧
    ¬ rowClosed exampleAuthority staleSelectorRow := by
  constructor
  · rfl
  · simp [rowClosed, staleSelectorRow, exampleAuthority]

theorem implementedStateAloneAcceptsDescendantLifecycle :
    permissiveImplementationAdmission descendantLifecycleRow ∧
    ¬ rowClosed exampleAuthority descendantLifecycleRow := by
  constructor
  · rfl
  · simp [rowClosed, descendantLifecycleRow, exampleAuthority]

theorem schemaAndVersionAloneAcceptMissingRows :
    missingRowsContract.schemaId = "agentic-ai-lab.module-system-owner-map" ∧
    missingRowsContract.schemaVersion = 1 ∧
    ¬ contractClosed exampleAuthority missingRowsContract := by
  simp [contractClosed, missingRowsContract, requiredRowIdentities]

theorem closedContractClosesEveryMember
    {authority : OwnerAuthority}
    {contract : OwnerMapContract}
    (closed : contractClosed authority contract)
    {row : OwnerMapRow}
    (member : row ∈ contract.rows) :
    rowClosed authority row := by
  exact closed.2.2.2 row member

theorem closedRowRejectsDescendantLifecycle
    {authority : OwnerAuthority}
    {row : OwnerMapRow}
    (closed : rowClosed authority row) :
    row.parentOwned = true := by
  exact closed.2.1

theorem closedRowsReplayTheSameBinding
    {authority : OwnerAuthority}
    {left right : OwnerMapRow}
    (sameIdentity : left.identity = right.identity)
    (leftClosed : rowClosed authority left)
    (rightClosed : rowClosed authority right) :
    left.sourcePath = right.sourcePath ∧
    left.sourceSymbol = right.sourceSymbol ∧
    left.testPath = right.testPath ∧
    left.testSymbol = right.testSymbol ∧
    left.buildTarget = right.buildTarget := by
  rcases leftClosed with ⟨_, _, leftSourcePath, leftSourceSymbol,
    leftTestPath, leftTestSymbol, leftBuildTarget⟩
  rcases rightClosed with ⟨_, _, rightSourcePath, rightSourceSymbol,
    rightTestPath, rightTestSymbol, rightBuildTarget⟩
  constructor
  · exact leftSourcePath.trans
      ((congrArg authority.sourcePath sameIdentity).trans rightSourcePath.symm)
  constructor
  · exact leftSourceSymbol.trans
      ((congrArg authority.sourceSymbol sameIdentity).trans rightSourceSymbol.symm)
  constructor
  · exact leftTestPath.trans
      ((congrArg authority.testPath sameIdentity).trans rightTestPath.symm)
  constructor
  · exact leftTestSymbol.trans
      ((congrArg authority.testSymbol sameIdentity).trans rightTestSymbol.symm)
  · exact leftBuildTarget.trans
      ((congrArg authority.buildTarget sameIdentity).trans rightBuildTarget.symm)

end AgenticAILabProof.Enterprise.ModuleSystemOwnerMapClosure
