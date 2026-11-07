// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module HybridRuntime_terminal {
  import HybridRuntime(BUG="terminal", TRACK_EVENT=false).* from "./28-hybrid-runtime"
  run receiptReplayTest = init.then(startForeign).then(foreignReturn).then(enqueueResult).then(dispatch).then(revoke).then(resultComplete).expect(safety)
  run creditReplayTest = init.then(startForeign).then(waitTimeout).expect(safety)
  run joinReplayTest = init.then(startForeign).then(drain).then(foreignReturn).then(close).expect(safety)
  run terminalReplayTest = init.then(startForeign).then(foreignReturn).then(enqueueResult).then(dispatch).then(resultComplete).then(enqueueResult).then(dispatch).then(resultComplete).expect(not(safety))
  run recoveryReplayTest = init.then(startForeign).then(cancel).then(recover).then(foreignReturn).then(enqueueResult).then(dispatch).then(resultComplete).expect(safety)
  run propagationReplayTest = init.then(startForeign).then(foreignReturn).then(enqueueResult).then(revoke).then(dispatch).then(deliverControlTo(1)).then(retryControl).then(dispatch).then(deliverControlTo(2)).then(acknowledge).then(dispatch).then(resultComplete).expect(safety)
}
