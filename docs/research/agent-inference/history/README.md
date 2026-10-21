# Historical cross-path studies

The numbered studies are frozen experimental records, not product releases,
graph schema versions or supported Python modules. Their protocols differ, so
their results cannot be merged into one improvement claim.

`crosspath-sources.tar.gz` preserves the exact removed research modules and
tests at their original paths, along with helper dependencies and frozen plans.
`crosspath-source-manifest.json` records every source hash and the archive hash.
Existing raw request, response, thinking, cost and failure archives remain in
the parent directory. No report or frozen plan has been rewritten.

Extract into a temporary directory to inspect or replay the historical tests:

```sh
tar -xzf .cache/ascent/archived-runs/docs/research/agent-inference/history/crosspath-sources.tar.gz -C "$temporary_directory"
PYTHONPATH="$temporary_directory/python/src:$PWD/python/src" python3 -m pytest -q "$temporary_directory/python/tests"
```

Historical paid runners bind original repository paths and native artifacts.
Moving their source out of the active package intentionally removes those live
entry points. To reproduce them, reconstruct a separate original layout from
the manifest and retained native snapshot; do not install the archived modules
into the current package or silently edit their bindings.
