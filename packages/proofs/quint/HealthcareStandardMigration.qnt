// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module HealthcareStandardMigration {
  var phase: str
  var parserBound: bool
  var mappingComplete: bool
  var conformanceBound: bool
  var humanReviewed: bool
  var cedarPermit: bool
  var cutoverReady: bool
  var aiAuthority: bool
  val Phases = Set("Inventory", "Mapped", "Conformant", "HumanReviewed", "Authorized", "CutoverReady")
  action Init = all { phase' = "Inventory", parserBound' = false, mappingComplete' = false, conformanceBound' = false, humanReviewed' = false, cedarPermit' = false, cutoverReady' = false, aiAuthority' = false }
  action BindParser = all { phase == "Inventory", phase' = "Mapped", parserBound' = true, mappingComplete' = true, conformanceBound' = conformanceBound, humanReviewed' = humanReviewed, cedarPermit' = cedarPermit, cutoverReady' = cutoverReady, aiAuthority' = aiAuthority }
  action BindConformance = all { phase == "Mapped", parserBound, mappingComplete, phase' = "Conformant", conformanceBound' = true, parserBound' = parserBound, mappingComplete' = mappingComplete, humanReviewed' = humanReviewed, cedarPermit' = cedarPermit, cutoverReady' = cutoverReady, aiAuthority' = aiAuthority }
  action RecordHumanReview = all { phase == "Conformant", conformanceBound, phase' = "HumanReviewed", humanReviewed' = true, parserBound' = parserBound, mappingComplete' = mappingComplete, conformanceBound' = conformanceBound, cedarPermit' = cedarPermit, cutoverReady' = cutoverReady, aiAuthority' = aiAuthority }
  action RecordCedarPermit = all { phase == "HumanReviewed", humanReviewed, phase' = "Authorized", cedarPermit' = true, parserBound' = parserBound, mappingComplete' = mappingComplete, conformanceBound' = conformanceBound, humanReviewed' = humanReviewed, cutoverReady' = cutoverReady, aiAuthority' = aiAuthority }
  action AdmitCutover = all { phase == "Authorized", cedarPermit, phase' = "CutoverReady", cutoverReady' = true, parserBound' = parserBound, mappingComplete' = mappingComplete, conformanceBound' = conformanceBound, humanReviewed' = humanReviewed, cedarPermit' = cedarPermit, aiAuthority' = aiAuthority }
  action step = any { BindParser , BindConformance , RecordHumanReview , RecordCedarPermit , AdmitCutover }
  val TypeInvariant = Phases.contains(phase)  and  (parserBound == true or parserBound == false)  and  (mappingComplete == true or mappingComplete == false)  and  (conformanceBound == true or conformanceBound == false)  and  (humanReviewed == true or humanReviewed == false)  and  (cedarPermit == true or cedarPermit == false)  and  (cutoverReady == true or cutoverReady == false)  and  (aiAuthority == true or aiAuthority == false)
  val AINeverGrantsAuthority = not(aiAuthority)
  val ReviewRequiresConformance = humanReviewed  implies  conformanceBound
  val CedarPermitRequiresHumanReview = cedarPermit  implies  humanReviewed
  val CutoverRequiresCedarPermit = cutoverReady  implies  cedarPermit
  val CutoverRequiresCompleteEvidence = cutoverReady  implies  parserBound  and  mappingComplete  and  conformanceBound  and  humanReviewed
  action init = Init
  val safety = and { TypeInvariant, AINeverGrantsAuthority, ReviewRequiresConformance, CedarPermitRequiresHumanReview, CutoverRequiresCedarPermit, CutoverRequiresCompleteEvidence }
}
