// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module ContextRuntime_owner {
  import ContextRuntime(BUG = "owner").* from "./26-context-runtime"
  run ownerReplayTest = init.then(takeover).then(publishResult(old)).expect(not(safety))
  run cachedReplayTest = init.then(revoke).then(publishResult(old)).expect(safety)
  run revivalReplayTest = init.then(cancel).then(recover).then(publishResult(old)).expect(safety)
  run terminalReplayTest = init.then(publishResult(old)).then(publishResult(old)).expect(safety)
  run ticketReplayTest = init.then(replacePolicy).then(expireOldTicket).expect(safety)
  run lockReplayTest = init.then(takeover).then(staleEvidenceWrite).expect(safety)
  run independentProgressTest = init.then(partition).then(independentProgress).expect(safety and s.cDone and s.cValid)
  run propagationReplayTest = init.then(revoke).then(deliverTo(2)).then(deliverTo(1)).then(deliverTo(2)).then(acknowledge).expect(safety and s.revokeAck and s.cValid)
}
