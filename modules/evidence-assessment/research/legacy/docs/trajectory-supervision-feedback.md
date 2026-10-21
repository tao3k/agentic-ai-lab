# Trajectory Supervision Feedback

Status: architecture review and change-admission contract, not a new runtime,
an automatic Agent controller, or demonstrated reasoning-quality improvement.

## Reuse The Existing Architecture

The governing protocol remains [Trajectory Exploration](features/trajectory-exploration.org)
and [Clue Exchange](features/clue-exchange.org). This record clarifies ownership;
it does not introduce another search language, history store, Navigator, or API.

The failure to avoid is experiment-driven Python growth: every investigation
adds a topic recognizer, special query, retry policy, result interpretation, or
case-specific command. Moving those branches into a configuration file without
removing their procedural semantics would not solve the problem.

The normal extension unit is a declarative Evidence relation or Scheme rule.
Python should remain a reusable search service host, not a research script.

| Owner | Responsibility | Must not absorb |
|-------|----------------|-----------------|
| Agent | Form hypotheses, translate a question into logical factors, choose scope and expansion, interpret counterevidence | Treat a returned slice as an exhaustive menu or an execution instruction |
| Downstream Scheme DSL | Declare facts, provenance, applicability, domain associations, and caller-owned query rules | Implement Library internals or require downstream native compilation for a new evidence case |
| ASCENT Library | Evaluate relations, preserve witnesses and polarity, produce source-bound incremental slices and expansion references | Know SMP labels, source filenames, milestone numbers, or prescribe the Agent's next action |
| Python host | Discover registered declarations, load and bind sources, invoke the Library, persist opaque checkpoints, transport results and execution receipts | Reimplement logical matching, causal inference, topic routing, or domain-specific failure classification |

Thus "Python owns search" means it exposes and operates the search service.
The logical meaning of that search remains in Scheme DSL and ASCENT. Generic
source loaders and storage adapters are legitimate Python infrastructure;
recognizing a particular GC failure inside Python is not.

## A New Investigation Without A Python Edit

An Agent can record a source-bound observation, counterexample, failed premise,
or open hypothesis using the existing downstream declarations and submission
contract. Changing a claim or adding a factor should not require a host edit.
Evidence is not made authoritative merely because the Agent wrote a DSL fact:
its receipt, source identity and independent review still determine its status.

The Agent supplies a caller-owned selector and bindings to the existing public
query. Rules associate those bindings with evidence and derive the scoped
result. The Library returns a compact slice with witnesses, support and counter,
unknown associations, and expandable references. Python transports it unchanged.
Continuation passes the returned checkpoint; deliberate replay remains possible.

Keyword lookup can discover vocabulary, and a model can propose semantic
associations. Neither establishes a logical witness. Proposed associations must
remain distinguishable from reviewed facts. Missing associations remain unknown,
not an excuse for Python to guess a synonym or silently enlarge the scope.

## Supervision Is An Evidence Question

Record observable requests, results, declared purpose, source/rule/checkpoint
identities and concrete artifacts. Do not infer or inspect hidden reasoning.
Existing Trajectory comparisons distinguish an unchanged comparable attempt
from changed premises or an unknown comparison; do not replace this with a
keyword similarity score or a universal prohibition on repeats.

Investigate an apparent lack of progress by locating the broken contract:

| Observation | Candidate gap | Evidence needed before a change |
|-------------|---------------|---------------------------------|
| Public API discovered, no query executed | Usability or integration | Actual help read, subsequent calls, availability of a usable declaration |
| Query rejected before Library execution | Tool or host execution | Exact tool result and execution boundary, separate from a query verdict |
| Query executes but misses applicable retained evidence | Projection, association, or scope | Bound query, source/rule identities and missing witness |
| Continuation repeats entire payload | Checkpoint transport, scope changes, or deliberate replay | Passed checkpoint and displayed-unit identities; intent may be unknown |
| Accurate slice but no source repair | Unresolved domain reasoning | Proposed mechanism, discriminator and source/native evidence; not just call counts |

The supervisor's proposed explanation is itself a hypothesis. Preserve contrary
traces. Failure records are reusable evidence under stated conditions, not
global bans on a hypothesis whose premises later change.

## Admit Changes At The Owning Layer

Before editing, record the observed defect, whether it is already explored,
the missing contract, expected benefit and a falsifying acceptance case.
If the benefit is not measured, describe the expected work removed rather than
inventing a percentage or a native speedup.

Prefer an existing declarative extension when a new case needs only facts,
associations, applicability rules or query scope. A Python change needs a
demonstrated generic host defect, such as broken source binding or checkpoint
transport. An ASCENT algorithm change needs a domain-independent failing case.
Do not add switches merely to bypass a failed contract. Do not remove existing
host functionality without checking its callers and retained receipts.

Validate a generic change across unrelated declarations and changed/unknown
premises, then run a real Agent continuation. Existing QNT and Lean laws own
protocol correctness: first-hit guarantees are conditional on registered,
associated, applicable evidence and sufficient capacity for honest references.
They cannot prove that a probabilistic Agent chooses the interface or repairs
native code. Those require observed integration and task outcomes separately.

Success is more useful evidence and better-supported source decisions with
fewer unnecessary host edits. Fewer calls alone, more DSL files, or a green
interface suite does not establish that success.
