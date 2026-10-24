-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import Lean

open Lean

namespace AgenticAILabProof.Export.DeclarationClosure

private def schemaId := "agentic-ai-lab.lean-declaration-closure.v1"
private def performanceSchemaId := "agentic-ai-lab.lean-export-phase.v1"

private def emitPerformancePhase
    (phase : String)
    (startedMs : Nat)
    (fields : List (String × Json) := []) :
    IO Unit := do
  let elapsedMs := (← IO.monoMsNow) - startedMs
  IO.eprintln <|
    (Json.mkObj <|
      [
        ("elapsed_ms", toJson elapsedMs),
        ("phase", .str phase),
        ("schema_id", .str performanceSchemaId),
        ("state", .str "completed")
      ] ++ fields).compress

structure Config where
  rootModule : Name := .anonymous
  rootDeclarations : Array Name := #[]
  batchRoots : Array (Name × Name) := #[]
  baseImports : Array Name := #[`Init]
  proofBaseImports : Array Name := #[]
  output : Option System.FilePath := none

structure Declaration where
  name : Name
  kind : String
  ownerModule : Name
  localDependencies : Array Name

structure RangedDeclaration where
  declaration : Declaration
  sourceRange : DeclarationRange

structure ClosureState where
  visiting : Std.HashSet Name := {}
  emitted : Std.HashSet Name := {}
  proofBaseDependencies : Std.HashSet Name := {}
  declarations : Array Declaration := #[]

structure ProofBaseInterfaceState where
  visiting : Std.HashSet Name := {}
  emitted : Std.HashSet Name := {}
  declarations : Array Name := #[]

structure ProofBaseInterfaceDeclaration where
  name : Name
  declarationRole : String
  levelParams : Array Name
  typeSource : String
  valueSource : Option String

private def usage :=
  "usage: lake env lean --run AgenticAILabProof/Export/DeclarationClosure.lean -- " ++
  "(--root-module <module> --root-declaration <name>... | " ++
  "--batch-root <module> <declaration>...) " ++
  "[--base-import <module>]... [--proof-base-import <module>]... " ++
  "[--output <path>]"

private partial def parseArgs (args : List String) (config : Config := {}) :
    Except String Config :=
  match args with
  | [] =>
      if !config.batchRoots.isEmpty then
        if !config.rootModule.isAnonymous ||
            !config.rootDeclarations.isEmpty then
          throw "single-root and batch-root options cannot be mixed"
        else
          return config
      else if config.rootModule.isAnonymous then
        throw "missing --root-module"
      else if config.rootDeclarations.isEmpty then
        throw "missing --root-declaration"
      else
        return config
  | "--root-module" :: value :: rest =>
      if !config.rootModule.isAnonymous then
        throw "duplicate --root-module"
      else
        parseArgs rest { config with rootModule := value.toName }
  | "--root-declaration" :: value :: rest =>
      parseArgs rest {
        config with
        rootDeclarations := config.rootDeclarations.push value.toName
      }
  | "--batch-root" :: moduleName :: declarationName :: rest =>
      parseArgs rest {
        config with
        batchRoots :=
          config.batchRoots.push
            (moduleName.toName, declarationName.toName)
      }
  | "--base-import" :: value :: rest =>
      parseArgs rest {
        config with
        baseImports := config.baseImports.push value.toName
      }
  | "--proof-base-import" :: value :: rest =>
      parseArgs rest {
        config with
        proofBaseImports := config.proofBaseImports.push value.toName
      }
  | "--output" :: value :: rest =>
      if config.output.isSome then
        throw "duplicate --output"
      else
        parseArgs rest { config with output := some value }
  | option :: _ =>
      throw s!"unknown or incomplete option: {option}"

private def declarationKind : ConstantInfo → String
  | .axiomInfo _ => "axiom"
  | .defnInfo _ => "definition"
  | .thmInfo _ => "theorem"
  | .opaqueInfo _ => "opaque"
  | .quotInfo _ => "quotient"
  | .inductInfo _ => "inductive"
  | .ctorInfo _ => "constructor"
  | .recInfo _ => "recursor"

private def terminalNameFragment : Name → String
  | .anonymous => ""
  | .str _ value => value
  | .num _ value => toString value

private def proofBaseDeclarationRole
    (name : Name)
    (info : ConstantInfo)
    (hasValueSource : Bool) :
    String :=
  let fragment := terminalNameFragment name
  if fragment.startsWith "inst" || fragment.endsWith "_inst" then
    "instance"
  else if !hasValueSource then
    "axiom"
  else
    match info with
    | .defnInfo definitionInfo =>
        match definitionInfo.hints with
        | .abbrev => "abbrev"
        | _ => "definition"
    | _ => "axiom"

private def nameLess (left right : Name) : Bool :=
  left.toString (escape := false) < right.toString (escape := false)

private def uniqueSortedNames (names : Array Name) : Array Name :=
  let names := names.foldl (init := ({} : Std.HashSet Name)) fun seen name =>
    seen.insert name
  names.toArray.qsort nameLess

private partial def returnsSort : Expr → Bool
  | .forallE _ _ body _ => returnsSort body
  | .sort _ => true
  | _ => false

private def directDependencies
    (env : Environment)
    (info : ConstantInfo) :
    Array Name :=
  let fromType := info.type.getUsedConstants
  let fromValue :=
    match info.value? (allowOpaque := true) with
    | none => #[]
    | some value => value.getUsedConstants
  let fromConstructorTypes :=
    match info with
    | .inductInfo inductiveInfo =>
        inductiveInfo.ctors.foldl
          (init := #[])
          fun dependencies constructorName =>
            match env.find? constructorName with
            | none => dependencies
            | some constructor =>
                dependencies ++ constructor.type.getUsedConstants
    | _ =>
        #[]
  uniqueSortedNames (fromType ++ fromValue ++ fromConstructorTypes)

private def ownerModule (env : Environment) (name : Name) : Except String Name := do
  let some moduleIdx := env.getModuleIdxFor? name
    | throw s!"declaration-owner-missing: {name}"
  let some moduleName := env.header.moduleNames[moduleIdx]?
    | throw s!"declaration-owner-index-invalid: {name}: {moduleIdx}"
  return moduleName

private partial def visitModuleClosure
    (env : Environment)
    (moduleName : Name)
    (modules : Std.HashSet Name) :
    Except String (Std.HashSet Name) := do
  if modules.contains moduleName then
    return modules
  let some moduleIdx := env.getModuleIdx? moduleName
    | throw s!"module-closure-owner-missing: {moduleName}"
  let some moduleData := env.header.moduleData[moduleIdx]?
    | throw s!"module-closure-data-missing: {moduleName}"
  let mut modules := modules.insert moduleName
  for importedModule in moduleData.imports do
    modules ← visitModuleClosure env importedModule.module modules
  return modules

private def moduleClosure
    (env : Environment)
    (rootModules : Array Name) :
    Except String (Std.HashSet Name) := do
  let mut modules : Std.HashSet Name := {}
  for rootModule in rootModules do
    modules ← visitModuleClosure env rootModule modules
  return modules

private def declarationOwnedByModules
    (env : Environment)
    (modules : Std.HashSet Name)
    (name : Name) :
    Bool :=
  match env.getModuleIdxFor? name with
  | none => false
  | some moduleIdx =>
      match env.header.modules[moduleIdx]? with
      | none => false
      | some importedModule => modules.contains importedModule.module

private def isProofBaseDeclaration
    (env : Environment)
    (trustedModules proofBaseModules : Std.HashSet Name)
    (name : Name) :
    Bool :=
  declarationOwnedByModules env proofBaseModules name &&
    !declarationOwnedByModules env trustedModules name

private partial def visitDeclaration
    (trustedModules proofBaseModules : Std.HashSet Name)
    (fullEnv : Environment)
    (name : Name)
    (state : ClosureState) :
    Except String ClosureState := do
  if declarationOwnedByModules fullEnv trustedModules name then
    return state
  if isProofBaseDeclaration fullEnv trustedModules proofBaseModules name then
    return {
      state with
      proofBaseDependencies := state.proofBaseDependencies.insert name
    }
  if state.emitted.contains name then
    return state
  if state.visiting.contains name then
    throw s!"declaration-cycle: {name}"
  let some info := fullEnv.find? name
    | throw s!"declaration-missing: {name}"
  let sourceFamily :=
    match info with
    | .inductInfo inductiveInfo =>
        inductiveInfo.all.foldl
          (init := ({} : Std.HashSet Name))
          fun (family : Std.HashSet Name) member => family.insert member
    | _ =>
        ({} : Std.HashSet Name)
  let rawDependencies := directDependencies fullEnv info
  let proofBaseDependencies := rawDependencies.filter fun dependency =>
    isProofBaseDeclaration
      fullEnv
      trustedModules
      proofBaseModules
      dependency
  let dependencies := rawDependencies.filter fun dependency =>
    fullEnv.contains dependency &&
      !declarationOwnedByModules fullEnv trustedModules dependency &&
      !isProofBaseDeclaration
        fullEnv
        trustedModules
        proofBaseModules
        dependency &&
      !sourceFamily.contains dependency
  let mut state := {
    state with
    visiting := state.visiting.insert name
    proofBaseDependencies :=
      proofBaseDependencies.foldl
        (init := state.proofBaseDependencies)
        fun dependencies dependency => dependencies.insert dependency
  }
  for dependency in dependencies do
    state ←
      visitDeclaration
        trustedModules
        proofBaseModules
        fullEnv
        dependency
        state
  let moduleName ← ownerModule fullEnv name
  return {
    visiting := state.visiting.erase name
    emitted := state.emitted.insert name
    proofBaseDependencies := state.proofBaseDependencies
    declarations := state.declarations.push {
      name
      kind := declarationKind info
      ownerModule := moduleName
      localDependencies := dependencies
    }
  }

private partial def visitProofBaseInterface
    (env : Environment)
    (trustedModules proofBaseModules : Std.HashSet Name)
    (name : Name)
    (state : ProofBaseInterfaceState) :
    Except String ProofBaseInterfaceState := do
  if declarationOwnedByModules env trustedModules name then
    return state
  if state.emitted.contains name then
    return state
  if state.visiting.contains name then
    throw s!"proof-base-interface-cycle: {name}"
  let some info := env.find? name
    | throw s!"proof-base-declaration-missing: {name}"
  let valueDependencies :=
    match returnsSort info.type, info.value? (allowOpaque := false) with
    | true, some value =>
        match value with
        | .lam _ _ _ _ => #[]
        | _ => value.getUsedConstants
    | _, _ => #[]
  let dependencies :=
    uniqueSortedNames
      (info.type.getUsedConstants ++ valueDependencies)
    |>.filter fun dependency =>
      isProofBaseDeclaration
        env
        trustedModules
        proofBaseModules
        dependency
  let mut state := {
    state with
    visiting := state.visiting.insert name
  }
  for dependency in dependencies do
    state ←
      visitProofBaseInterface
        env
        trustedModules
        proofBaseModules
        dependency
        state
  return {
    visiting := state.visiting.erase name
    emitted := state.emitted.insert name
    declarations := state.declarations.push name
  }

private def collectProofBaseInterfaceNames
    (env : Environment)
    (trustedModules proofBaseModules : Std.HashSet Name)
    (dependencies : Std.HashSet Name) :
    Except String (Array Name) := do
  let mut state : ProofBaseInterfaceState := {}
  for name in uniqueSortedNames dependencies.toArray do
    state ←
      visitProofBaseInterface
        env
        trustedModules
        proofBaseModules
        name
        state
  return state.declarations

private def renderProofBaseInterface
    (env : Environment)
    (names : Array Name) :
    IO (Except String (Array ProofBaseInterfaceDeclaration)) := do
  let action : Core.CoreM
      (Except String (Array ProofBaseInterfaceDeclaration)) := do
    let mut result : Array ProofBaseInterfaceDeclaration := #[]
    for name in names do
      let some info := env.find? name
        | return .error s!"proof-base-declaration-missing: {name}"
      let declarationIndex := result.size
      let renamedLevelParams :=
        info.levelParams.toArray.mapIdx fun levelIndex _ =>
          Name.mkSimple s!"agentic_ai_lab_u_{declarationIndex}_{levelIndex}"
      let renamedLevels :=
        renamedLevelParams.toList.map Level.param
      let renamedType :=
        info.type.instantiateLevelParams info.levelParams renamedLevels
      let renderedType ← Meta.MetaM.run' do
        withOptions
          (fun options =>
            options
              |>.setBool `pp.fullNames true
              |>.setBool `pp.universes true)
          (Meta.ppExpr renamedType)
      let renderedValue ←
        match returnsSort info.type, info.value? (allowOpaque := false) with
        | true, some value =>
            match value with
            | .lam _ _ _ _ =>
                pure none
            | _ =>
                let renamedValue :=
                  value.instantiateLevelParams
                    info.levelParams
                    renamedLevels
                let rendered ← Meta.MetaM.run' do
                  withOptions
                    (fun options =>
                      options
                        |>.setBool `pp.fullNames true
                        |>.setBool `pp.universes true)
                    (Meta.ppExpr renamedValue)
                pure (some rendered.pretty)
        | _, _ =>
            pure none
      result := result.push {
        name
        declarationRole :=
          proofBaseDeclarationRole name info renderedValue.isSome
        levelParams := renamedLevelParams
        typeSource := renderedType.pretty
        valueSource := renderedValue
      }
    return .ok result
  let context : Core.Context := {
    fileName := "<proof-base-interface-export>"
    fileMap := FileMap.ofString ""
  }
  let state : Core.State := { env }
  match ← EIO.toIO' ((action.run context) state) with
  | .error _ =>
      return .error "proof-base-interface-render-failed"
  | .ok (result, _) =>
      return result

private def nameJson (name : Name) : Json :=
  .str (name.toString (escape := false))

private def namesJson (names : Array Name) : Json :=
  .arr (names.map nameJson)

private def sourceRangeJson (sourceRange : DeclarationRange) : Json :=
  .mkObj [
    ("start_line", toJson sourceRange.pos.line),
    ("start_column", toJson sourceRange.pos.column),
    ("start_char_utf16", toJson sourceRange.charUtf16),
    ("end_line", toJson sourceRange.endPos.line),
    ("end_column", toJson sourceRange.endPos.column),
    ("end_char_utf16", toJson sourceRange.endCharUtf16)
  ]

private def declarationJson (ranged : RangedDeclaration) : Json :=
  let declaration := ranged.declaration
  .mkObj [
    ("kind", .str declaration.kind),
    ("local_dependencies", namesJson declaration.localDependencies),
    ("name", nameJson declaration.name),
    ("owner_module", nameJson declaration.ownerModule),
    ("source_range", sourceRangeJson ranged.sourceRange)
  ]

private def proofBaseInterfaceDeclarationJson
    (declaration : ProofBaseInterfaceDeclaration) :
    Json :=
  .mkObj [
    ("declaration_role", .str declaration.declarationRole),
    ("level_params", namesJson declaration.levelParams),
    ("name", nameJson declaration.name),
    ("type_source", .str declaration.typeSource),
    (
      "value_source",
      match declaration.valueSource with
      | none => .null
      | some value => .str value
    )
  ]

private def collectDeclarationRanges
    (env : Environment)
    (declarations : Array Declaration) :
    IO (Except String (Array RangedDeclaration)) := do
  let action : Core.CoreM (Except String (Array RangedDeclaration)) := do
    let mut result : Array RangedDeclaration := #[]
    for declaration in declarations do
      if let some ranges ← findDeclarationRanges? declaration.name then
        result := result.push {
          declaration
          sourceRange := ranges.range
        }
    let rangedNames :=
      result.foldl
        (init := ({} : Std.HashSet Name))
        fun names ranged => names.insert ranged.declaration.name
    return .ok (result.map fun ranged => {
      ranged with
      declaration := {
        ranged.declaration with
        localDependencies :=
          ranged.declaration.localDependencies.filter rangedNames.contains
      }
    })
  let context : Core.Context := {
    fileName := "<declaration-closure-export>"
    fileMap := FileMap.ofString ""
  }
  let state : Core.State := { env }
  match ← EIO.toIO' ((action.run context) state) with
  | .error _ =>
      return .error "declaration-source-range-failed"
  | .ok (result, _) =>
      return result

private def collectInductiveCompanionProofBaseDependencies
    (fullEnv : Environment)
    (trustedModules proofBaseModules : Std.HashSet Name)
    (declarations : Array RangedDeclaration)
    (dependencies : Std.HashSet Name) :
    IO (Except String (Std.HashSet Name)) := do
  let action : Core.CoreM (Std.HashSet Name) := do
    let selectedOwnerModules :=
      declarations.foldl
        (init := ({} : Std.HashSet Name))
        fun modules ranged =>
          modules.insert ranged.declaration.ownerModule
    let selectedNameFragments :=
      declarations.foldl
        (init := ({} : Std.HashSet String))
        fun fragments ranged =>
          if ranged.declaration.kind == "inductive" then
            fragments.insert
              (terminalNameFragment ranged.declaration.name)
          else
            fragments
    if selectedNameFragments.isEmpty then
      return dependencies
    let selectedNameFragments := selectedNameFragments.toArray
    let mut result := dependencies
    for moduleIndex in [:fullEnv.header.modules.size] do
      let some importedModule := fullEnv.header.modules[moduleIndex]?
        | continue
      let moduleName := importedModule.module
      if !selectedOwnerModules.contains moduleName then
        continue
      let some moduleData := fullEnv.header.moduleData[moduleIndex]?
        | continue
      for name in moduleData.constNames do
        let renderedName := name.toString (escape := false)
        if !selectedNameFragments.any fun fragment =>
            renderedName.contains fragment then
          continue
        let some info := fullEnv.find? name
          | continue
        for dependency in directDependencies fullEnv info do
          if isProofBaseDeclaration
              fullEnv
              trustedModules
              proofBaseModules
              dependency then
            result := result.insert dependency
    return result
  let context : Core.Context := {
    fileName := "<declaration-companion-dependency-export>"
    fileMap := FileMap.ofString ""
  }
  let state : Core.State := { env := fullEnv }
  match ← EIO.toIO' ((action.run context) state) with
  | .error _ =>
      return .error "declaration-companion-dependency-failed"
  | .ok (result, _) =>
      return .ok result

private def receiptJson
    (config : Config)
    (declarations : Array RangedDeclaration)
    (proofBaseInterface : Array ProofBaseInterfaceDeclaration) :
    Json :=
  let ownerModules :=
    uniqueSortedNames (declarations.map (·.declaration.ownerModule))
  .mkObj [
    ("base_imports", namesJson config.baseImports),
    ("declarations", .arr (declarations.map declarationJson)),
    ("lean_version", .str versionString),
    ("owner_modules", namesJson ownerModules),
    (
      "proof_base_imports",
      namesJson config.proofBaseImports
    ),
    (
      "proof_base_interface",
      .arr (proofBaseInterface.map proofBaseInterfaceDeclarationJson)
    ),
    ("root_declarations", namesJson config.rootDeclarations),
    ("root_module", nameJson config.rootModule),
    ("schema_id", .str schemaId)
  ]

private def rootPerformanceFields
    (config : Config)
    (fields : List (String × Json)) :
    List (String × Json) :=
  ("root_module", nameJson config.rootModule) :: fields

private def runClosure
    (config : Config)
    (fullEnv : Environment)
    (trustedModules proofBaseModules : Std.HashSet Name) :
    IO (Except String Json) := do
  let phaseStarted ← IO.monoMsNow
  let mut state : ClosureState := {}
  for rootDeclaration in config.rootDeclarations do
    state ←
      match
        visitDeclaration
          trustedModules
          proofBaseModules
          fullEnv
          rootDeclaration
          state
      with
      | .ok nextState => pure nextState
      | .error error => return .error error
  emitPerformancePhase
    "declaration-closure"
    phaseStarted
    (rootPerformanceFields config
      [("declaration_count", toJson state.declarations.size)])
  let phaseStarted ← IO.monoMsNow
  match ← collectDeclarationRanges fullEnv state.declarations with
  | .error error => return .error error
  | .ok declarations =>
      emitPerformancePhase
        "source-range-projection"
        phaseStarted
        (rootPerformanceFields config
          [("declaration_count", toJson declarations.size)])
      let rangedNames :=
        declarations.foldl
          (init := ({} : Std.HashSet Name))
          fun names ranged => names.insert ranged.declaration.name
      match config.rootDeclarations.find? fun root =>
        !rangedNames.contains root with
      | some root =>
          return .error s!"root-source-range-missing: {root}"
      | none =>
          let phaseStarted ← IO.monoMsNow
          let proofBaseDependencies ←
            match ←
              collectInductiveCompanionProofBaseDependencies
                fullEnv
                trustedModules
                proofBaseModules
                declarations
                state.proofBaseDependencies
            with
            | .ok dependencies => pure dependencies
            | .error error => return .error error
          emitPerformancePhase
            "inductive-companion-projection"
            phaseStarted
            (rootPerformanceFields config
              [("dependency_count", toJson proofBaseDependencies.size)])
          let phaseStarted ← IO.monoMsNow
          let interfaceNames ←
            match
              collectProofBaseInterfaceNames
                fullEnv
                trustedModules
                proofBaseModules
                proofBaseDependencies
            with
            | .ok names => pure names
            | .error error => return .error error
          emitPerformancePhase
            "proof-base-closure"
            phaseStarted
            (rootPerformanceFields config
              [("declaration_count", toJson interfaceNames.size)])
          let phaseStarted ← IO.monoMsNow
          match ← renderProofBaseInterface fullEnv interfaceNames with
          | .error error => return .error error
          | .ok proofBaseInterface =>
              emitPerformancePhase
                "proof-base-render"
                phaseStarted
                (rootPerformanceFields config
                  [("declaration_count", toJson proofBaseInterface.size)])
              let phaseStarted ← IO.monoMsNow
              let receipt :=
                receiptJson config declarations proofBaseInterface
              emitPerformancePhase
                "receipt-serialization"
                phaseStarted
                (rootPerformanceFields config
                  [("declaration_count", toJson declarations.size)])
              return .ok receipt

private def run (config : Config) : IO (Except String Json) := do
  try
    let rootModules :=
      if config.batchRoots.isEmpty then
        #[config.rootModule]
      else
        config.batchRoots.map (·.1)
    let phaseStarted ← IO.monoMsNow
    Lean.initSearchPath (← Lean.findSysroot)
    emitPerformancePhase
      "search-path-initialization"
      phaseStarted
      [("root_count", toJson rootModules.size)]
    let requestedModules :=
      uniqueSortedNames
        (rootModules ++ config.baseImports ++ config.proofBaseImports)
    let phaseStarted ← IO.monoMsNow
    let fullEnv ←
      importModules
        (requestedModules.map fun moduleName => { module := moduleName })
        {}
    emitPerformancePhase
      "environment-import"
      phaseStarted
      [
        ("module_count", toJson fullEnv.header.modules.size),
        ("requested_module_count", toJson requestedModules.size),
        ("root_count", toJson rootModules.size)
      ]
    let phaseStarted ← IO.monoMsNow
    let trustedModules ← IO.ofExcept (moduleClosure fullEnv config.baseImports)
    let proofBaseModules ←
      IO.ofExcept (moduleClosure fullEnv config.proofBaseImports)
    emitPerformancePhase
      "module-partition"
      phaseStarted
      [
        ("proof_base_module_count", toJson proofBaseModules.size),
        ("trusted_module_count", toJson trustedModules.size)
      ]
    if config.batchRoots.isEmpty then
      runClosure config fullEnv trustedModules proofBaseModules
    else
      let mut receipts : Array Json := #[]
      for (rootModule, rootDeclaration) in config.batchRoots do
        let requestConfig := {
          config with
          rootModule
          rootDeclarations := #[rootDeclaration]
          batchRoots := #[]
        }
        match ←
            runClosure
              requestConfig
              fullEnv
              trustedModules
              proofBaseModules with
        | .error error => return .error error
        | .ok receipt => receipts := receipts.push receipt
      return .ok (.arr receipts)
  catch error =>
    return .error s!"lean-environment-import-failed: {error}"

end AgenticAILabProof.Export.DeclarationClosure

def main (args : List String) : IO UInt32 := do
  match AgenticAILabProof.Export.DeclarationClosure.parseArgs args with
  | .error error =>
      IO.eprintln s!"{error}\n{AgenticAILabProof.Export.DeclarationClosure.usage}"
      return 2
  | .ok config =>
      match ← AgenticAILabProof.Export.DeclarationClosure.run config with
      | .error error =>
          IO.eprintln error
          return 1
      | .ok receipt =>
          let output := receipt.compress ++ "\n"
          match config.output with
          | none => IO.print output
          | some path => IO.FS.writeFile path output
          return 0
