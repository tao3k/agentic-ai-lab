# Evidence Review API

`ascent_engine.review.EvidenceReview` composes the existing `EvidenceChain`.
Python validates table shape and transports observations; Scheme computes all
closure, negation, prerequisite and denial relations. It does not contain a
second relational evaluator or any Gambit-, package-, PR- or machine-specific
success rule.

```python
from ascent_engine import Engine
from ascent_engine.review import EvidenceReview

with Engine(library) as engine, EvidenceReview(engine, facts) as review:
    first = review.review()
    repeated = review.review()  # reusable completed Scheme components
    review.replace(new_facts)  # old references and materialized results withdrawn
    current = review.review()
```

Input relations and column order are declared in `review.ARITIES`. All columns
are nonempty symbols. Candidate and failure identifiers and current input keys
are single-valued. `Passed(receipt, qualified_claim)` is a host-authenticated
observation, not an instruction to trust arbitrary user JSON. Every reusable
receipt needs input bindings matching `CurrentInput`, and its transitive receipt
dependencies must be present, current and noncyclic. `ClaimDepends` expresses
prerequisites separately from receipt dependencies. `Cause` is a host-reviewed
causal link, not a free-text prediction.

Results expose `KnownFailure`, `Established`, `Reusable`, `Missing`, and their
supporting dependency/rejection relations. They are bounded by the supplied
snapshot and declared assumptions. The host owns provenance, scope matching,
requirement completeness and observation authenticity; this API cannot infer
missing facts about an external system. Claim names should include evidence
scope so a finite-model result cannot masquerade as native correctness.

Only `DENY` and `REVIEW_REQUIRED` are produced. `executionAuthorized` is always
false. Changed binaries and expected-success prose never confer execution
permission. An incomplete/failed engine request propagates an error without a
successful receipt. Application runners must enforce their own admission.

Run `engine_tests/test_review.py` with `ASCENT_ENGINE_LIBRARY` selecting a real
built library. Seven tests exercise real Scheme queries/validation; one additional
fault-injection test checks that engine failure is propagated. No native runtime
correctness or broad performance conclusion follows from these interface tests.
