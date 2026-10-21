# Library consumer transport qualification

Captured checkout: `7bb4ba0cfe372357d5a30cef644407fb77582a57` with the Library source hashes in report.json. This is local qualification; no remote CI or model benefit is claimed.

Fixed the existing consumer IO: raw-byte framing now applies one absolute deadline to a complete JSON line, retains extra buffered frames, and saves partial or invalid output. Readiness receipts record the actual deadline and command. Failed writes and failed process launch retain diagnostics; already exited processes close their stdin handle. No Library semantics, task, independent judge, annotation rule or model prompt was changed.

Nine transport regressions pass, including a peer that sends half a JSON line and then waits indefinitely. Runtime loading limits remain 20 seconds for the native entry and 60 seconds for dynamic entries; RPC remains 20 seconds and graceful EOF cleanup remains 5 seconds.

An initial current-source admission failed because provenance had changed and proof-frame had been added since the earlier build. This negative result is retained. The Library was recaptured and rebuilt through std/make, translated and linked, and the compiler-reported closure was checked. Old captured builds and experiment results are retained.

Captured native, dynamically reloaded evidence-store, and full gxi entries each pass three starts, two frozen tasks per start, Fact checks against the independent reachability judge, closed proof ancestry, repeated-packet equality and one proof build per task. All nine processes exit through stdin EOF without terminate or kill. Full gxi readiness ranges from 2.097 to 5.379 seconds and cleanup from 1.258 to 1.380 seconds in these three repetitions.

Native and full gxi entries additionally pass 448 existing contract/semantic checks each, including stale receipt rejection and bounded failure remaining a failure. All original checks are enforced.

The prior full-gxi dyld cleanup timeout and stack sample remain in the original fact-reuse-results archive. The current checks do not reproduce it; they do not establish a global Gambit/dyld fix. The first real-model experiment still has six output-truncated failures. No model call was made here, and unused model budget is not reported as savings.

After qualification, concurrent work changed candidate/proof-frame.ss again. The successful checks bind the captured source, not the newly changed live file. Current-source admission is explicitly false; no real-model experiment is started against a stale binary.

raw.tar.gz contains current source/build bindings, consumer/test sources, runtime artifacts, raw native traces and diagnostics, qualification scripts and build receipts. integrity.json binds the archive and report, and identifies the immutable earlier failure archive.
