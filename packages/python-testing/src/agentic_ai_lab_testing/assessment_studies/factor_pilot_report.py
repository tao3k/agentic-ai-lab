# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Descriptive accounting only. Read grades emitted by the Scheme oracle."""
import json,hashlib,statistics
from pathlib import Path
ROOT=Path.cwd();BASE=ROOT/'.cache/ascent/factor-pilot';DOC=ROOT/'.cache/ascent/research-reports/agent-inference'
DOC.mkdir(parents=True, exist_ok=True)

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def aggregate(rows):
 calls=[x for r in rows for x in r['calls']];tools=[x for r in rows for x in r['tools']];factors=[t for t in tools if t['name']=='factor' and 'factorReceipt' in t];usage=[c['usage'] for c in calls if isinstance(c.get('usage'),dict)]
 valid=[r['grade'] for r in rows if r['grade']['valid']]
 return {'phases':len(rows),'submitted':sum(r['submitted'] for r in rows),'valid':len(valid),'optimal':sum(r['grade']['optimal'] for r in rows),'failures':[r['failure'] for r in rows if r['failure']], 'meanAbsoluteGapValidOnly':statistics.mean(g['gap'] for g in valid) if valid else None,
 'cachedInputTokensObserved':sum((u.get('input_tokens_details') or {}).get('cached_tokens',0) for u in usage),'inputTokensObserved':sum(u.get('input_tokens',0) for u in usage),'outputTokensObserved':sum(u.get('output_tokens',0) for u in usage),'reasoningTokensObserved':sum((u.get('output_tokens_details') or {}).get('reasoning_tokens',0) for u in usage),'usageMissingCalls':len(calls)-len(usage),'providerSeconds':sum(c['seconds'] for c in calls),'toolSeconds':sum(t['totalToolSeconds'] for t in tools),'nativeStartupAndInitSeconds':sum(r['nativeStartupAndInitSeconds'] for r in rows),'cardsReadSeconds':sum(r['cardsReadSeconds'] for r in rows),'factorRequests':len(factors),'repeatFactorRequests':sum(t['repeatRequest'] for t in factors),'freshNativeSolves':sum(t['factorReceipt']['freshNativeSolve'] for t in factors),'reusedFactorReplies':sum(t['factorReceipt']['reused'] for t in factors),'proofStoreBytesWritten':sum(t.get('proofStoreBytes',0) for t in factors),
 'uniqueFeasibleCandidatesByPhase':[len({tuple(t['arguments']['order']) for t in r['tools'] if t['name'] in ('evaluate','submit') and t['result'].get('valid')}) for r in rows],
 'uniqueValidPrefixesByPhase':[len({tuple(t['arguments']['prefix']) for t in r['tools'] if t['name']=='explore' and t['result'].get('validPrefix')}) for r in rows],
 'maximumVerifiedPrefixDepthByPhase':[max((t['result']['depth'] for t in r['tools'] if t['name']=='explore' and t['result'].get('validPrefix')),default=0) for r in rows]}
rows=json.loads((BASE/'paid/records.json').read_text());plan=json.loads((BASE/'frozen-plan.json').read_text())
result={'schema':'ascent.factor-reuse-real-pilot-results.v1','planSha256':digest(BASE/'frozen-plan.json'),'recordsSha256':digest(BASE/'paid/records.json'),'sourceManifestSha256':digest(BASE/'source-manifest.json'),'model':plan['model'],'scheduledPhases':16,'completedGradingPhases':len(rows),'arms':{a:aggregate([r for r in rows if r['arm']==a]) for a in 'ABCD'},'byCase':{c:{a:aggregate([r for r in rows if r['arm']==a and r['case']==c]) for a in 'ABCD'} for c in ('fork','diamond')},'transferOnly':{a:aggregate([r for r in rows if r['arm']==a and r['phase']==1]) for a in 'ABCD'},'phaseGrades':[{k:r[k] for k in ('case','arm','phase','submitted','grade','failure')} for r in rows],'priorCensoredPilot':{'path':'censored-2048','phases':16,'tools':0,'outputTokens':32768,'outcome':'Every phase exhausted its 2048 output allowance entirely in reasoning before tool use. Not interpretable as cache efficacy.'},'verdict':{'nativeReuse':'demonstrated for this finite scope','repeatedModelThinking':'not identified; task effects reverse and D changes supplied information','deeperExploration':'not established; more feasible schedules but fewer checked prefixes and lower maximum depth','qualityImprovement':'not identifiable; all revised phases optimal','totalCostReduction':'not established; input offsets output and invoice unknown'},'actualInvoiceUsd':None,'totalTokenBudgetMatched':False,'outputBudgetMatched':True,'inferenceLimitation':'Tiny exploratory sample, one replicate, alias not immutable model; ordered arm rotation cannot eliminate time drift. Hidden reasoning repetition unobserved. Enumerated synthetic scheduling tasks expose source edges to all arms. Output budget includes reasoning; total input cost is measured, not matched. Certificate files are audit exports, not a disk replay cache.'}
result['ledgerSha256']=digest(DOC/'factor-reuse-real-pilot-ledger.json')
result['postRunBindingSha256']=digest(BASE/'post-run-binding-receipt.json')
(DOC/'factor-reuse-real-pilot-report.json').write_text(json.dumps(result,indent=2)+'\n')
text='''# ASCENT checked factor/fragment reuse: real-model pilot

Checked fragment reuse avoided native recomputation, but this pilot did not establish a consistent reduction in model thinking, greater exploration depth or improved quality. All 16 revised phases reached the exact optimum. D used 2 fresh native solves versus A's 26, with 19 retained replies. Its output-token change reversed between the two task instances. These are descriptive observations from one replicate, not a benchmark or causal performance claim.

An initial separately frozen round censored all 16 phases at the 2,048 per-call cap: 32,768 output tokens, all reasoning, no tool action. Its requests, grades, usage and protocol remain under `.cache/ascent/factor-pilot/censored-2048/`. This report describes a second explicitly revised round with a 16,384 per-call cap and the common 24,576 phase allowance. Tasks, grader, model and native artifacts were unchanged. The two rounds are not pooled into success rates.

The repository-side `factor-reuse-real-pilot-ledger.json` preserves both frozen protocols, every terminal usage receipt, tool observation, oracle grade and censored phase. Raw request/SSE files remain in the local experiment directory. Post-run hashes matched all 3,362 bound artifacts and every producer file.

## Frozen implementation and controls

The experiment binds the dirty source snapshot at HEAD `797d6f4f489e03e4b5f4843f230eb2214df5174f`, fresh production compiler artifacts and the native pilot executable. The full build failed on an unrelated unfinished `applications/domain-evidence.ss` expression. The scoped build excluded that module, `interface/engine-api` and the C API. It passed; this is not whole-repository build qualification. Original failures remain in `.cache/ascent/factor-pilot/`.

Scheme owns bounded ASCENT solve, positive DAG checking, finite closure checking, source/candidate identity admission and the retained native objects. Python owns provider IO, opaque Responses history, byte exports and accounting. The independent Scheme oracle enumerates all 720 or 5,040 permutations using direct source edges and exact integer weighted completion cost; it never calls the ASCENT closure evaluator. Three-job hand-computable oracle controls and 16 offline observations passed before paid dispatch.

A recomputes checked atomic factors. B retains unverified native Fact cards (no independent certificate gate). C retains checked atomic receipts. D retains a checked full closure plus its composable finite derivation DAG, allowing a different ground query to consume the same supported fragment. D publishes a bounded DAG on first construction; the resulting input cost is charged. All arms see identical source edges, can check prefixes or schedules, and have the same instructions, 6-call/24-action ceiling and 24,576 output-token allowance per phase. Output allowance includes provider reasoning. Input tokens and elapsed costs are recorded but not budget-matched.

Two frozen DAGs each have a six-job cold phase followed by a seven-job phase with changed objective weights. Conversation history is reset before transfer; only retained factor packets can cross. Cache state resets between trajectories. No exact schedule answer cache is available. Two task instances, four arms, one replicate: 16 graded phases. Native failure, provider failure, incomplete output, missing usage, invalid submission and non-submission remain separate outcomes; no retries.

## Observations

| Arm | Graded | Submitted | Valid | Optimal | Mean gap (valid only) | Input tokens | Output tokens | Fresh solves | Factor reuse |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
'''
for a,x in result['arms'].items():text+=f"| {a} | {x['phases']} | {x['submitted']} | {x['valid']} | {x['optimal']} | {x['meanAbsoluteGapValidOnly']} | {x['inputTokensObserved']} | {x['outputTokensObserved']} | {x['freshNativeSolves']} | {x['reusedFactorReplies']} |\n"
text+='''
### Task-instance differences and evidence boundary

| Task instance (both phases) | A output tokens | B output tokens | C output tokens | D output tokens | D vs A |
|---|---:|---:|---:|---:|---:|
| fork | 23,737 | 23,121 | 24,602 | 16,343 | -31.15% |
| diamond | 18,071 | 15,303 | 20,895 | 22,995 | +27.25% |

D's aggregate output was 39,338 versus A's 41,808 (-5.91%). Reported reasoning tokens were 36,295 versus 39,100 (-7.17%). D's larger input offset most of that: gross input+output was 111,758 versus 112,216 (-0.41%). Cached-input billing rates and actual invoices are unavailable; these are token counts, not monetary savings. The opposite task-instance effects and information-granularity difference prevent a causal claim of reduced repeated thinking.

D checked 22 distinct feasible schedules across the four phases versus A's 19, but it checked 9 distinct valid prefixes versus A's 12 and reached maximum prefix depth 4 versus A's 5. This does not demonstrate greater depth. Every arm reached the optimum in all four phases, so quality improvement is unidentifiable at this ceiling. C retained 4 replies but requested 30 factors versus A's 26, leaving 26 fresh solves in both groups. Atomic reuse alone did not reduce aggregate native recomputation in this sample.

D's observed factor/tool processing total (including certificate byte export and IO) was 0.428 seconds versus A's 2.478 seconds; provider time was 179.54 versus 187.80 seconds. These single-run totals are not stable latency estimates. Both native startup and retained-card reads are separately recorded in JSON. Initial build/qualification preparation is common engineering setup, not included in per-trajectory totals; its failures/logs remain available. No whole-system speed claim follows.

For exploration, the JSON companion records distinct feasible schedules and distinct checked prefixes per phase, plus the maximum checked prefix length. Prefix length alone is not conceptual reasoning depth: completing seven jobs naturally produces a longer prefix than six. A claim of improved exploration requires more distinct checked branches and improved quality within the matched allowance. A cache hit measures avoided native recomputation, not avoided hidden model thinking. Provider usage cannot identify semantic repetition inside reasoning.

Provider requests, SSE events, terminal outputs, per-tool timings, costs, source identities, admitted certificate exports and oracle grades are retained under `.cache/ascent/factor-pilot/paid/`. Complete returned reasoning items were forwarded within each stateless phase; they were not analyzed for repetition. Missing billed usage remains unknown, not zero. No invoice dollar amount is inferred. The model is the provider alias `deepseek-flash`; immutable backend identity and scheduling determinism are unavailable.

D also changes the information supplied to the model (full derived factors and a DAG) compared with atomic replies. This design does not isolate memoization from information enrichment. A future fresh-full-fragment control must expose identical packets to isolate cache state. Provider cached-input usage is reported separately from ASCENT reuse. Gross token counts are not an invoice.

## Feature and formal-model correspondence

| Feature contract | Existing model/reference | Native pilot evidence | Boundary |
|---|---|---|---|
| Exact source/query admission | `packages/proofs/lean/RetainedInference.lean` | C stores receipt + proposal and checks binding before reuse | Abstract identity theorem is not whole native refinement |
| Changed-source rejection | `packages/proofs/quint/RetainedInference.qnt`, Lean retained model | Different identity/generation/content rejects a proof | Fault control, not a deployed update workload |
| Positive fragment composition | Lean `PositiveConsequence.lean`, native `candidate/provenance.ss` | D checked DAG nodes/roots plus finite closure gate; new ground queries share it | Finite positive rules only; no source-authority promotion |
| Cost and retained evidence | BYODS caller-owned finite sources + native proof objects | Cold construction, check, export, lookup, input/output and tool costs recorded | Trusted evidence authority still belongs to host; exports are audit files, not admitted reloads |
| Exploration/quality | Independent Scheme direct-edge oracle | Exact feasibility, integer objective, optimum gap, checked branch counters | Controlled scheduling tasks, no real-repository generalization |

QQN is not resolved to a concrete file in this checkout; no correspondence claim is made for it. The frozen QNT retained model passed typechecking; the frozen Lean retained model passed checking. The native and Quint 32-observation traces are independently compared by the Lean model executable before paid dispatch. No new whole-native refinement theorem is claimed. Future feature composition can add withdrawal/generation changes, unsupported rules, proof export/reload and domain-specific deterministic factors as separately qualified scenarios.

## Research context

[ENGRAM-R](https://arxiv.org/html/2511.12987v3) motivates anchored atomic Fact cards; [AtomMem](https://arxiv.org/html/2606.19847v1) motivates factor-level memory checks; [CounterMem](https://arxiv.org/html/2609.31874v1) motivates retaining failed local alternatives with applicability boundaries. These papers are conceptual inputs, not reproduced baselines. The accompanying `factor-reuse-2026-study.org` documents version dates and the distinctions between model verification and finite native proof replay.
'''
(DOC/'factor-reuse-real-pilot-report.md').write_text(text)
print(json.dumps(result['arms'],indent=2))
