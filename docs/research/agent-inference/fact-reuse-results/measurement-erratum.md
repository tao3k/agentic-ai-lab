# Annotation judge correction

The original frozen annotation judge incorrectly selected the first need row when checking a ready atom. Its initial annotation statistics are invalidated and retained in initial-report.json, annotation-ledger.json and raw.tar.gz. The search feasibility judge and optimum enumeration use the requested fragment correctly; all solver costs, six truncations, depth zero and seed quality remain unchanged.

The live consumer now selects the requested fragment ID. Every ready atom in both tasks was checked against raw-source reachability and Scheme. Existing raw annotation responses were revalidated offline using the unchanged rubric, exact spans, support and order constraints. There were zero additional model calls or tokens. The corrected implementation and labels are recorded in annotation-correction.json. This is a post-freeze measurement correction, not a passing frozen measurement result. Rejected labels and incomplete coverage remain explicit.

No repeated-thinking, exploration-depth or quality benefit is established: all six trajectories stopped before their first expansion. Zero observed repeats are not evidence of no repeated thinking. The next experiment requires a separately frozen interaction protocol that makes individual branch decisions complete before the single-response cap; current tasks were not modified or rerun to obtain a pass.
