# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared text, JSON, and Org renderers."""
import json
from collections.abc import Sequence
from typing import Any
from .common import BenchmarkResult, Report
from .comparison import COMPARISONS

def _json_default(value: Any) -> Any:
    if hasattr(value, '__dataclass_fields__'):
        return {key: _json_default(getattr(value, key)) for key in value.__dataclass_fields__.keys()}
    if isinstance(value, tuple):
        return [_json_default(item) for item in value]
    return value

def render_json(report: Report) -> str:
    return json.dumps(_json_default(report), indent=2, sort_keys=True)

def _org_escape(value: Any) -> str:
    return str(value).replace('|', '\\vert{}').replace('\n', ' ')

def _features(features: Sequence[str]) -> str:
    return ', '.join(features)

def _mean_ms(result: BenchmarkResult) -> float:
    return result.mean_us / 1000.0

def _comparison_rows(
    report: Report,
) -> list[tuple[str, BenchmarkResult, BenchmarkResult, float]]:
    results = {result.name: result for result in report.results}
    rows = []
    for comparison in COMPARISONS:
        native = results.get(comparison.native_case)
        poo = results.get(comparison.agentic_ai_lab_case)
        if native is None or poo is None or poo.mean_us <= 0:
            continue
        rows.append((comparison.label, native, poo, native.mean_us / poo.mean_us))
    return rows

def render_org(report: Report) -> str:
    lines: list[str] = []
    lines.append('#+title: LangChain/LangGraph/CrewAI vs Agentic AI Lab Benchmark Report')
    lines.append('#+startup: overview')
    lines.append('')
    lines.append('* Scope')
    lines.append('This benchmark compares native LangChain/LangGraph/CrewAI orchestration with semantically aligned Agentic AI Lab executor surfaces.')
    lines.append('')
    lines.append('It does not measure real LLM latency, network tools, or durable storage IO. The deterministic actions model control-plane costs for policy routing, graph edges, dynamic handoff, reducers, checkpoint interrupt/resume, long graph scale, and stream/event consumption.')
    lines.append('')
    lines.append('* Local Clone Inputs')
    lines.append('- LangChain: =../../.data/langchain/libs/core=')
    lines.append('- LangGraph: =../../.data/langgraph/libs/langgraph=')
    lines.append('- CrewAI: =../../.data/crewai/lib/crewai=')
    lines.append('- Agentic AI Lab runtime: current =packages/python-runtime= workspace')
    lines.append('')
    lines.append('* Command')
    lines.append('#+begin_src sh')
    lines.append('uv run \\')
    lines.append('  --with-editable ../../.data/langgraph/libs/langgraph \\')
    lines.append('  --with-editable ../../.data/langchain/libs/core \\')
    lines.append('  --with-editable ../../.data/crewai/lib/crewai \\')
    lines.append('  python -m agentic_ai_lab_benchmarks \\')
    lines.append('  --iterations 2000 \\')
    lines.append('  --warmup 200 \\')
    lines.append('  --progress \\')
    lines.append('  --format org \\')
    lines.append('  --report-org benchmarks/README.org')
    lines.append('#+end_src')
    lines.append('')
    lines.append('* Run Metadata')
    lines.append(f'- Generated at: ={report.generated_at}=')
    lines.append(f'- Command: ={_org_escape(report.command)}=')
    lines.append(f'- Python: ={_org_escape(report.python)}=')
    lines.append(f'- Platform: ={_org_escape(report.platform)}=')
    lines.append(f'- Iterations: ={report.iterations}=')
    lines.append(f'- Warmup: ={report.warmup}=')
    lines.append(f'- Per-case caps: ={str(report.case_caps_enabled).lower()}=')
    lines.append(f'- GC during measurement: ={str(report.gc_enabled_during_measurement).lower()}=')
    lines.append('')
    comparison_rows = _comparison_rows(report)
    lines.append('* Summary')
    if comparison_rows:
        langchain_speedups = [speedup for _, native, _, speedup in comparison_rows if native.family == 'langchain-native']
        langgraph_speedups = [speedup for _, native, _, speedup in comparison_rows if native.family == 'langgraph-native']
        crewai_speedups = [speedup for _, native, _, speedup in comparison_rows if native.family == 'crewai-native']
        if langchain_speedups:
            lines.append('- Agentic AI Lab runtime surfaces are {min_speedup:.2f}x to {max_speedup:.2f}x faster than the measured LangChain native orchestration cases in this run.'.format(min_speedup=min(langchain_speedups), max_speedup=max(langchain_speedups)))
        if langgraph_speedups:
            lines.append('- Agentic AI Lab runtime surfaces are {min_speedup:.2f}x to {max_speedup:.2f}x faster than the measured LangGraph native orchestration cases in this run.'.format(min_speedup=min(langgraph_speedups), max_speedup=max(langgraph_speedups)))
        if crewai_speedups:
            lines.append('- Agentic AI Lab runtime surfaces are {min_speedup:.2f}x to {max_speedup:.2f}x faster than the measured CrewAI native orchestration cases in this run.'.format(min_speedup=min(crewai_speedups), max_speedup=max(crewai_speedups)))
        lines.append('- All comparison rows report deterministic control-plane latency only; they do not include LLM, network, or durable storage IO.')
        lines.append('')
        lines.append('| comparison | native mean ms | agentic-ai-lab mean ms | speedup |')
        lines.append('|-')
        for label, native, poo, speedup in comparison_rows:
            lines.append('| {label} | {native_ms:.4f} | {poo_ms:.4f} | {speedup:.2f}x |'.format(label=_org_escape(label), native_ms=_mean_ms(native), poo_ms=_mean_ms(poo), speedup=speedup))
    else:
        lines.append('- Native LangChain/LangGraph/CrewAI comparison rows were not available in this run. Check the Failures section before reading the Agentic AI Lab numbers as a framework comparison.')
    lines.append('')
    lines.append('* Benchmark Results')
    lines.append('| name | family | features | mean ms | p50 ms | p95 ms | min ms | max ms | checksum |')
    lines.append('|-')
    for result in sorted(report.results, key=lambda item: (item.family, item.name)):
        lines.append('| {name} | {family} | {features} | {mean:.4f} | {p50:.4f} | {p95:.4f} | {min:.4f} | {max:.4f} | {checksum} |'.format(name=_org_escape(result.name), family=_org_escape(result.family), features=_org_escape(_features(result.features)), mean=result.mean_us / 1000.0, p50=result.p50_us / 1000.0, p95=result.p95_us / 1000.0, min=result.min_us / 1000.0, max=result.max_us / 1000.0, checksum=result.checksum))
    if not report.results:
        lines.append('| none | none | none | 0 | 0 | 0 | 0 | 0 | 0 |')
    lines.append('')
    lines.append('* Retired Graph ABI')
    lines.append('The legacy graph-specific C ABI rows and validation gates are intentionally absent. Agentic AI Lab runtime-v0 C ABI performance is qualified by the separate runtime ABI benchmark; it is not presented as graph orchestration equivalence.')
    lines.append('')
    lines.append('| name | status | features | error | receipt summary |')
    lines.append('|-')
    for gate in report.gates:
        receipt_summary = ' '.join((item for item in gate.receipt.splitlines() if item.startswith(('kind=', 'nodes=', 'edges=', 'conditional-routes=', 'state-reducers=', 'plan-digest='))))
        error = f'{gate.error_type}: {gate.error}' if gate.error else ''
        lines.append('| {name} | {status} | {features} | {error} | {receipt} |'.format(name=_org_escape(gate.name), status=_org_escape(gate.status), features=_org_escape(_features(gate.features)), error=_org_escape(error), receipt=_org_escape(receipt_summary)))
    lines.append('')
    lines.append('* Failures')
    lines.append('| name | family | phase | features | error |')
    lines.append('|-')
    for failure in report.failures:
        lines.append('| {name} | {family} | {phase} | {features} | {error_type}: {error} |'.format(name=_org_escape(failure.name), family=_org_escape(failure.family), phase=_org_escape(failure.phase), features=_org_escape(_features(failure.features)), error_type=_org_escape(failure.error_type), error=_org_escape(failure.error)))
    if not report.failures:
        lines.append('| none | none | none | none | none |')
    lines.append('')
    lines.append('* Interpretation')
    lines.append('- LangChain cases cover runnable composition, prompt/parser cost, branch routing, and tool/handoff selection.')
    lines.append('- LangGraph cases cover the production graph controls we need to compare against: conditional edges, dynamic Send fanout, reducer aggregation, checkpoint-backed interrupt/resume.')
    lines.append('- CrewAI cases cover sequential crew kickoff with agents, task context, and deterministic local LLM execution so the runtime-language boundary is tested without network or model latency.')
    lines.append('- Long graph cases use a fixed 32-node linear graph to expose scale cost without introducing LLM or IO latency.')
    lines.append('- Stream cases consume framework/runtime stream outputs so the benchmark is not limited to invoke-only happy paths.')
    lines.append('- POO executor cases measure the current Python runtime graph semantics.')
    lines.append('- The removed graph ABI is not reconstructed as a compatibility layer; runtime-v0 C ABI measurements remain in their dedicated benchmark record.')
    lines.append('')
    lines.append('* Current Gaps Exposed')
    lines.append('- The next benchmark expansion should add durable checkpoint persistence, larger graph-size sweeps, generated Scheme receipt -> Lean fact alignment, and a stable JSON artifact for CI trend comparison.')
    lines.append('')
    return '\n'.join(lines)

def render_text(report: Report) -> str:
    lines = [f'generated_at={report.generated_at}', f'iterations={report.iterations} warmup={report.warmup} keep_gc={report.gc_enabled_during_measurement}', '', 'BENCHMARKS']
    for result in sorted(report.results, key=lambda item: (item.family, item.name)):
        lines.append(f"{result.name}: mean={result.mean_us / 1000.0:.4f}ms p50={result.p50_us / 1000.0:.4f}ms p95={result.p95_us / 1000.0:.4f}ms features={','.join(result.features)}")
    lines.append('')
    for gate in report.gates:
        suffix = f' {gate.error_type}: {gate.error}' if gate.error else ''
        lines.append(f'{gate.name}: {gate.status}{suffix}')
    if report.failures:
        lines.append('')
        lines.append('FAILURES')
        for failure in report.failures:
            lines.append(f'{failure.name}: phase={failure.phase} {failure.error_type}: {failure.error}')
    return '\n'.join(lines)
