// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module BoundedScheduling_burst {
  import BoundedScheduling(BUG = "burst", TRACK_OP = true).* from "./27-bounded-scheduling"
  run capacityReplayTest = init.then(offerData).then(dispatch).then(offerData).then(offerData).expect(safety)
  run priorityReplayTest = init.then(offerData).then(offerControl).then(dispatch).expect(safety)
  run closeReplayTest = init.then(offerControl).then(dispatch).then(drain).then(close).expect(safety)
  run drainReplayTest = init.then(offerData).then(drain).then(offerData).then(dispatch).then(complete).then(close).expect(safety)
  run burstReplayTest = init.then(offerData).then(offerControl).then(dispatch).then(complete).then(offerControl).then(dispatch).then(complete).then(offerControl).then(dispatch).expect(not(safety))
}
