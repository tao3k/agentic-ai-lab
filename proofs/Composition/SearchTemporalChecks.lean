-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import SearchTemporal
def main : IO Unit := do
  let graph : LeanPoo.C4.Graph := {nodes := [
    {name := "A"}, {name := "B"}, {name := "C", parentOrders := [["A", "B"]]},
    {name := "D", parentOrders := [["C"]]}, {name := "E", parentOrders := [["D"]]}]}
  let .ok impact := POO.Flow.SearchTemporal.certifyImpact graph ["A"]
    | throw (IO.userError "valid stage dependency graph rejected")
  if impact.names != ["A", "C", "D", "E"] then
    throw (IO.userError "changed A must invalidate A/C/D/E and retain B")
  let cycle : LeanPoo.C4.Graph := {nodes := [
    {name := "A", parentOrders := [["B"]]}, {name := "B", parentOrders := [["A"]]}]}
  match POO.Flow.SearchTemporal.certifyImpact cycle ["A"] with
  | .ok _ => throw (IO.userError "cyclic stage projection admitted")
  | .error _ => pure ()
  IO.println "POO-SEARCH-TEMPORAL-CERTIFICATE-OK"
