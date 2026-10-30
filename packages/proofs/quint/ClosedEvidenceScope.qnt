// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Finite model of whole declaration admission and fresh export invocation.
module ClosedEvidenceScope {
  const Mutation: str
  var admitted: bool
  var compatible: bool
  var charged: int
  var calls: int
  var instances: Set[int]
  var refused: bool
  action init = all { admitted' = false, compatible' = false,
    charged' = 0, calls' = 0, instances' = Set(), refused' = false }
  action Load = { nondet complete = Set(false, true).oneOf(); all {
    charged == 0, charged' = 1, compatible' = complete,
    admitted' = (complete or Mutation == "partial"),
    calls' = calls, instances' = instances, refused' = false
  }}
  action Call = all {
    admitted, calls < 3, calls' = calls + 1,
    instances' = instances.union(Set(if (Mutation == "cached") 0 else calls)),
    admitted' = admitted, compatible' = compatible, charged' = charged, refused' = false
  }
  action Refuse = all {
    charged == 1, refused' = true,
    calls' = calls, instances' = if (Mutation == "rejectPublish") instances.union(Set(99)) else instances,
    admitted' = admitted, compatible' = compatible, charged' = charged
  }
  action Idle = all { admitted' = admitted, compatible' = compatible,
    charged' = charged, calls' = calls, instances' = instances, refused' = refused }
  action step = any {Load, Call, Refuse, Idle}
  val WholeScope = not(admitted) or compatible
  val FreshInvocation = instances.size() == calls
  val ChargedOnce = charged <= 1
}
