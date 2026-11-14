-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import SearchReadiness
open POO.Flow.SearchAttempt POO.Flow.SearchReadiness
def scope (stage : Nat) : Scope := ⟨stage, 0, 0, 0, 0⟩
def a : Request := ⟨scope 0, 0⟩
def b : Request := ⟨scope 1, 0⟩
def target : State := ⟨scope 2, 0, none, false⟩
def main : IO Unit := do
  unless decide (Ready target [] []) do throw (IO.userError "root blocked")
  unless decide (Ready target [a,b] [a,b]) do throw (IO.userError "fan-in blocked")
  if decide (Ready target [a,b] [a,a]) then throw (IO.userError "missing parent admitted")
  let fresh := {a with scope := {a.scope with revision := 1}}
  if decide (Ready target [fresh,b] [a,b]) then throw (IO.userError "stale parent admitted")
  let foreign := {target with scope := {target.scope with generation := 1}}
  if decide (Ready foreign [a,b] [a,b]) then throw (IO.userError "foreign generation admitted")
  let otherConfig := {target with scope := {target.scope with configuration := 1}}
  if decide (Ready otherConfig [a,b] [a,b]) then throw (IO.userError "foreign configuration admitted")
  if (issueReady (retire target) [a,b] [a,b]).isSome then
    throw (IO.userError "retired child admitted")
  IO.println "POO-SEARCH-READINESS-OK"
