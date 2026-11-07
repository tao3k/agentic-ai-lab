-- SPDX-FileCopyrightText: 2026 tao3k team and Contributors
--
-- SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import AgenticAILabProof.PooC4.FactContract.Session
import AgenticAILabProof.PooC4.FactContract.UserInterface

namespace AgenticAILabProof.PooC4.FactContract

def allFactKeyContracts : List FactKeyContract :=
  sessionHandoffFactKeyContracts ++ uiScenarioFactKeyContracts

def allSchemeFactKeys : List SchemeFactKey :=
  sessionHandoffSchemeFactKeys ++ uiScenarioSchemeFactKeys

def allSchemeFactExternalNames : List String :=
  allSchemeFactKeys.map SchemeFactKey.externalName

theorem all_contract_keys_exact :
    factKeyContractKeys allFactKeyContracts = allSchemeFactKeys := by
  unfold allFactKeyContracts allSchemeFactKeys factKeyContractKeys
  rw [List.map_append]
  rfl

theorem all_scheme_fact_keys_nodup :
    allSchemeFactKeys.Nodup := by
  native_decide

theorem all_scheme_fact_external_names_nodup :
    allSchemeFactExternalNames.Nodup := by
  native_decide

theorem all_contracts_well_typed :
    ∀ contract,
      contract ∈ allFactKeyContracts ->
      contract.wellTyped := by
  intro contract member
  simp [allFactKeyContracts] at member
  rcases member with member | member
  · exact session_handoff_contracts_well_typed contract member
  · exact ui_scenario_contracts_well_typed contract member

theorem all_contracts_exactly_typed :
    ∀ contract,
      contract ∈ allFactKeyContracts ->
      contract.exactlyTyped := by
  intro contract member
  simp [allFactKeyContracts] at member
  rcases member with member | member
  · exact session_handoff_contracts_exactly_typed contract member
  · exact ui_scenario_contracts_exactly_typed contract member

end AgenticAILabProof.PooC4.FactContract
