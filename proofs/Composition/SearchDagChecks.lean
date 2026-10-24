-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import SearchDag
open POO.Flow.SearchAttempt POO.Flow.SearchDag
def graph : LeanPoo.C4.Graph := {nodes := [
  {name := "A"}, {name := "B"}, {name := "C", parentOrders := [["A", "B"]]},
  {name := "D", parentOrders := [["C"]]}]}
def index (name : String) : Nat :=
  if name = "A" then 0 else if name = "B" then 1 else if name = "C" then 2 else 3
def states (name : String) : State := ⟨⟨index name, 0, 0, 0, 0⟩, 1, none, false⟩
def request (name : String) : Request := ⟨(states name).scope, 0⟩
def allRequests (name : String) : Option Request := some (request name)
def main : IO Unit := do
  if frontier graph states (fun _ => none) (fun _ => none) != ["A", "B"] then
    throw (IO.userError "root frontier differs")
  let parents := fun name => if name = "A" ∨ name = "B" then allRequests name else none
  if frontier graph states parents parents != ["C"] then
    throw (IO.userError "fan-in frontier differs")
  if frontier graph states allRequests allRequests != [] then
    throw (IO.userError "completed nodes reissued")
  let .ok certificate := POO.Flow.SearchTemporal.certifyImpact graph ["A"]
    | throw (IO.userError "stage graph rejected")
  if certificate.names != ["A", "C", "D"] then
    throw (IO.userError "selective impact differs")
  let revisedStates := invalidateStates certificate states 1
  let retained := invalidateRequests certificate allRequests
  if retained "B" != allRequests "B" then throw (IO.userError "independent B lost")
  if frontier graph revisedStates retained retained != ["A"] then
    throw (IO.userError "invalidated descendants admitted before A")
  for name in ["A", "C", "D"] do
    if settle (revisedStates name) (request name) |>.isSome then
      throw (IO.userError s!"invalidated {name} admitted old work")
  let some (_, fresh) := issue (revisedStates "A")
    | throw (IO.userError "revised A cannot issue")
  if fresh.attempt != 1 || fresh.scope.revision != 1 then
    throw (IO.userError "attempt lineage reset")
  let afterA := fun name => if name = "A" then some fresh else retained name
  if frontier graph revisedStates afterA afterA != ["C"] then
    throw (IO.userError "retained B cannot compose with fresh A")
  IO.println "POO-SEARCH-DAG-OK"
