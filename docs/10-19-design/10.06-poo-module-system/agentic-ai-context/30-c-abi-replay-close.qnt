// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module CAbiReplay_close {
  import ContextCAbi(BUG="close",TRACK_OP=true).* from "./30-context-c-abi"
  run toolTest = init.then(attach).then(toolControl).expect(safety)
  run closeTest = init.then(attach).then(enter).then(close).expect(not(safety))
  run retryTest = init.then(attach).then(enter).then(finish).then(retry).expect(safety)
  run revokeTest = init.then(attach).then(enter).then(revoke).then(finish).expect(safety)
  run recoveryTest = init.then(attach).then(enter).then(cancel).then(recover).then(finish).expect(safety)
  run bufferTest = init.then(attach).then(enter).then(finish).then(close).then(release).expect(safety)
}
