// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import {readFile, mkdir, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseArgs} from 'node:util';
import {createHash} from 'node:crypto';
import {connect} from '@openmbee/opensysml';
import {chromium} from 'playwright';
import {compileModel, composeFigure, composeModelView, type FigureInput, type FigureComposer} from '@deterministic-engineering/render';
import {captureOpenSysMLView, projectOpenSysMLView} from '@deterministic-engineering/render/opensysml';
import {exportFigure} from '@deterministic-engineering/render/export';
import {composePresentationTheme, presentationThemeLayers} from '@deterministic-engineering/render/presentation-theme';
import {sessionLabels, composeSession} from './views';
import {composeIllustratedContext} from './illustration';
import {composeEvolution} from './evolution';
import {composeAscentView} from './ascent-view';
import {composeWindowDesign} from './window-design';

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, '../..');
const {values, positionals} = parseArgs({allowPositionals: true, options: {
  view: {type: 'string'}, title: {type: 'string'}, out: {type: 'string'},
  example: {type: 'string'}, help: {type: 'boolean', short: 'h'},
}});
if (values.help) {
  console.log('bun run render.ts --example context|temporal|evolution|window-evolution|session\nbun run render.ts --view Qualified::View [--title text] [--out prefix] model.sysml [more.sysml ...]\nbun run render.ts [--title text] [--out prefix] model.d2');
  process.exit(0);
}
if (values.example && !['context', 'temporal', 'evolution', 'window-evolution', 'session', 'ascent-early', 'ascent-later'].includes(values.example)) throw new Error('Unknown example');
const example = values.example;
const windowDesign = example === 'window-evolution';
const ascentExample = example === 'ascent-early' || example === 'ascent-later';
const illustrated = example === 'context' || example === 'temporal' || example === 'evolution';
const contextSource = path.join(root, 'docs/10-19-design/10.06-poo-module-system/agentic-ai-context');
const files = ascentExample ? [path.join(directory, 'output', example + '.d2')] : windowDesign ? [path.join(contextSource, '32-time-window-context-evolution.sysml'), path.join(directory, 'window-figures.sysml')] : example ? [path.join(contextSource, '01-system-boundary.sysml'),
  path.join(contextSource, '02-lifecycle.sysml'), path.join(directory, 'figures.sysml')] : positionals;
if (!files.length) throw new Error('Supply SysML/D2 source files or --example');
const d2Input = files.length === 1 && path.extname(files[0]!) === '.d2';
const view = values.view ?? (windowDesign ? 'ContextWindowFigures::evolution' : example ? 'ContextFigures::' + (illustrated ? 'context' : example) : undefined);
if (!d2Input && !view) throw new Error('--view is required for SysML');
const prefix = path.resolve(values.out ?? path.join(directory, 'output', example ?? 'figure'));
const sources: Record<string, string> = {};
async function capture(filename: string): Promise<string> {
  const absolute = path.resolve(filename), relative = path.relative(root, absolute).split(path.sep).join('/');
  if (relative.startsWith('../') || path.isAbsolute(relative)) throw new Error('Source must be inside this repository: ' + filename);
  sources[relative] = await readFile(absolute, 'utf8');
  return relative;
}
const models = await Promise.all(files.map(capture));
for (const name of ['render.ts', 'views.ts', 'illustration.ts', 'evolution.ts', 'ascent-view.ts', 'build-experiment-art.ts', 'window-design.ts', 'package.json', 'bun.lock']) await capture(path.join(directory, name));
if (ascentExample || windowDesign) {
  for (const name of windowDesign ? ['init.ss', 'design.ss'] : ['init.ss', 'drive.ss', 'context-evolution-example.ss']) await capture(path.join(directory, name));
  for await (const name of new Bun.Glob('**/*.ss').scan({cwd: path.join(root, 'modules/d2')}))
    await capture(path.join(root, 'modules/d2', name));
}
if (windowDesign) await capture(path.join(contextSource, '32-time-window-context-evolution.org'));
if (illustrated) {
  await capture(path.join(contextSource, '03-information-to-recall.sysml'));
  await capture(path.join(contextSource, '32-time-window-context-evolution.org'));
  await capture(path.join(root, 'core/module-system/design/context-temporal-lifecycle-policy-system-design.org'));
}
const question = {ref: 'selected-view', text: values.title ?? (ascentExample
  ? example === 'ascent-early' ? 'Earlier: one result supports a proposed method' : 'Later: a counterexample keeps both explanations open'
  : windowDesign ? 'How time changes Context without prescribing the next action'
  : illustrated
  ? example === 'evolution' ? 'Event-driven Context evolution' : 'Context, time windows and reusable knowledge'
  : example === 'session' ? 'Closing a Session takes more than a stop request.' : view ?? models[0]!), focusRefs: ['model']};
const selection: FigureInput['view'] = {source: 'dev/d2/render.ts', title: question.text,
  purpose: example === 'session' ? 'workflow' : 'architecture', kind: example === 'session' ? 'state' : 'system', question,
  basis: {captureRef: 'local-sdk-render', modelRefs: models, obligationRefs: [], evidenceRefs: []}};
let model: NonNullable<FigureInput['model']>;
let trace: FigureInput['modelTrace'];
let sdkInfo: unknown;
let windowComposer: FigureComposer | undefined;
type ImageAnchor = {identity: string; text: string; left: number; top: number; right: number; bottom: number};
let publishDesignCapture: ((imageDigest?: string, anchors?: ImageAnchor[]) => Promise<void>) | undefined;
if (d2Input) {
  // The upstream adapter invokes the official D2 TypeScript SDK.
  model = (await compileModel(Object.fromEntries(models.map(name => [name, sources[name]!])), models[0]!)).model;
} else {
  const connection = await connect({version: 'v0.11.0', requireCapabilities: ['render_view']});
  try {
    const parsed = await connection.parseSources(models.map(name => [name, sources[name]!] as const));
    parsed.raiseForErrors();
    const sdkCapture = await captureOpenSysMLView(connection, parsed.hash, view!);
    for (const notice of sdkCapture.rendering.notices) console.warn(notice);
    const projected = projectOpenSysMLView(sdkCapture, {selection, layout: 'reflow'});
    model = projected.model;
    trace = projected.trace;
    sdkInfo = connection.info;
    if (windowDesign) {
      windowComposer = composeWindowDesign(
        await parsed.symbol('AgenticAITimeWindowContext::ObjectRelationGraph'),
        await parsed.symbol('AgenticAITimeWindowContext::ScopedKnowledge'));
      // The SDK supplies all endpoints and source spans. Its renderer omits
      // connection names; recover presentation names from native SDK symbols
      // matched inside those exact spans, never from a second edge catalog.
      const owner = await parsed.symbol('AgenticAITimeWindowContext::ContextEvolution');
      const connections = (await owner.children()).filter(symbol => symbol.kind === 'connectionUsage');
      model = {...model, relations: model.relations.map((edge, index) => {
        const origin = projected.trace.edges[index]!.origin;
        if (!origin || !sources[origin.file]) throw new Error('SysML relation has no captured source span');
        const fragment = sources[origin.file]!.split('\n').slice(origin.startLine - 1, origin.endLine).join(' ').replace(/\s+/g, ' ');
        const matches = connections.filter(symbol => fragment.includes(`connection ${symbol.name} connect `));
        if (matches.length !== 1) throw new Error('Cannot bind the SDK connection name to its source span');
        return {...edge, label: matches[0]!.name};
      })};
      const cut = 'sha256-' + createHash('sha256').update(JSON.stringify([...models, path.relative(root, path.join(contextSource, '32-time-window-context-evolution.org'))].map(name => [name, sources[name]]))).digest('hex');
      const q = (value: string) => JSON.stringify(value); // Scheme string literals in the final POO boundary projection.
      const sym = (value: string) => `(string->symbol ${q(value)})`;
      const perspective = await parsed.symbol('AgenticAITimeWindowContext::BeginnerPerspective');
      const questions = perspective.attributes.map(attribute => {
        if (attribute.value.kind !== 'string') throw new Error('Expected a textual reader question in this perspective');
        return `(.o identity: ${sym(attribute.name)} audience: 'beginner subject: 'context-design text: ${q(attribute.value.value)})`;
      }).join('\n');
      const nodes = model.subjects.map(node => `(.o identity: ${sym(node.id)} kind: ${sym(node.type ?? 'node')} label: ${q(node.label ?? node.id)})`).join('\n');
      const relations = model.relations.map(edge => `(.o from: ${sym(edge.src)} to: ${sym(edge.dst)} role: ${sym(edge.label!)})`).join('\n');
      const assetRef = 'dev/d2/window-design.ts';
      const assetDigest = createHash('sha256').update(sources[assetRef]!).digest('hex');
      publishDesignCapture = async (imageDigest, anchors = []) => {
        const renders = imageDigest ? `(list (.o proposal: 'current-composition asset-sha: ${q(assetDigest)} image-sha: ${q(imageDigest)} image-ref: ${q(path.relative(root, prefix + '.png'))}))` : "'()";
        const anchorValues = anchors.map(anchor => `(.o image-sha: ${q(imageDigest!)} identity: ${q(anchor.identity)} text: ${q(anchor.text)} left: ${anchor.left} top: ${anchor.top} right: ${anchor.right} bottom: ${anchor.bottom})`).join('\n');
        const captureSource = `(import :clan/poo/object)\n(export DesignCapture)\n(def DesignCapture\n (.o view: (.o identity: 'context-design revision: 'design source-cut: ${sym(cut)} audience: 'beginner)\n questions: (list ${questions})\n proposals: (list (.o identity: 'current-composition view: 'context-design revision: 'design source-cut: ${sym(cut)} asset-ref: ${q(assetRef)} asset-sha: ${q(assetDigest)}))\n renders: ${renders}\n diagram: (.o identity: 'context-design revision: ${sym(cut)} roots: '()\n nodes: (list ${nodes})\n relations: (list ${relations}))))\n`;
        await mkdir(path.join(directory, 'output'), {recursive: true});
        await writeFile(path.join(directory, 'output/window-source.ss'), captureSource.replace(' renders:', ` image-anchors: (list ${anchorValues})\n renders:`));
        const driver = Bun.spawn(['just', 'd2-design'], {cwd: root, stdout: 'pipe', stderr: 'pipe'});
        const [code, stdout, stderr] = await Promise.all([driver.exited, new Response(driver.stdout).text(), new Response(driver.stderr).text()]);
        if (code) throw new Error('D2 Module refused the SDK capture: ' + stderr.slice(-3000));
        console.log(stdout.trim());
      };
      await publishDesignCapture();
      for (const name of ['output/window-source.ss', 'output/window-evolution.d2', 'output/window-requests.org']) await capture(path.join(directory, name));
    }
  } finally { await connection.close(); }
}
if (example === 'session') model = sessionLabels(model);
const input: FigureInput = {model, modelTrace: trace, sources, references: {model: models[0]!}, view: selection,
  questions: [question], language: 'en', width: windowDesign ? 1600 : 1440,
  presentation: {options: {'elk.direction': 'RIGHT', 'elk.edgeRouting': 'ORTHOGONAL'}},
  theme: composePresentationTheme(['ocean', 'context'], {...presentationThemeLayers, context: {
    typography: {titleSize: '21px', detailSize: '16px', labelSize: '16px', headingSize: '21px', pageTitleSize: '32px', bodySize: '19px', noteSize: '16px'},
    spacing: {scenePadding: 24, gutter: 28, gap: 14, iconSize: 40},
    stylesheet: '.scene-frame{rx:14;stroke:var(--border)}[data-role="focus"]>.scene-frame{fill:var(--tint);stroke:var(--accent);stroke-width:2}[data-role="knowledge"]>.scene-frame{fill:var(--secondaryTint);stroke:var(--secondary)}[data-role="boundary"]>.scene-frame{fill:none;stroke:var(--border);stroke-width:1.5}.scene-group-title{fill:var(--accent);font-size:var(--type-headingSize)}',
  }}),
};
const figure = composeFigure(input, windowDesign ? windowComposer! : ascentExample ? composeAscentView : example === 'evolution' ? composeEvolution : illustrated ? composeIllustratedContext : example === 'session' ? composeSession : composeModelView);
const browser = await chromium.launch();
try {
  const result = await exportFigure(figure, browser, {scale: 1, minimumTextSize: 12,
    attribution: {copyright: ['2026 tao3k team and Contributors', '2026 hardenedlinux Linux Team and Contributors',
      '2016 The Inter Project Authors (https://github.com/rsms/inter)'],
      license: 'Apache-2.0 AND LGPL-2.1-or-later AND OFL-1.1'}});
  for (const [filename, content] of Object.entries(sources))
    if (await readFile(path.join(root, filename), 'utf8') !== content) throw new Error('Source changed during rendering: ' + filename);
  if (!result.svg.length) throw new Error('No vector scene returned');
  await mkdir(path.dirname(prefix), {recursive: true});
  await writeFile(prefix + '.svg', result.svg[0]!);
  await writeFile(prefix + '.png', result.png);
  await writeFile(prefix + '.html', result.html);
  // Only the export receipt is serialized; no intermediate model/config file.
  await writeFile(prefix + '.receipt.json', JSON.stringify({sdk: sdkInfo, sourceSHA256: figure.sourceSHA256,
    rendering: result.receipt}, null, 2) + '\n');
  // A measured render is an observation, not a favorable semantic verdict.
  // Re-evaluate the Context; the host never forces a model-stage transition.
  if (publishDesignCapture) {
    const imageDigest = createHash('sha256').update(result.png).digest('hex');
    const page = await browser.newPage({viewport: {width: result.receipt.width, height: result.receipt.height}});
    let anchors: ImageAnchor[];
    try {
      await page.setContent(result.html);
      await page.evaluate(() => document.fonts.ready);
      anchors = await page.locator('[data-vector-surface] text').evaluateAll(elements => {
        const counts = new Map<string, number>();
        return elements.flatMap(element => {
          const bounds = element.getBoundingClientRect();
          const root = element.closest('svg')!;
          const svg = root.getBoundingClientRect();
          const {width, height} = root.viewBox.baseVal;
          const style = getComputedStyle(element);
          if (!bounds.width || !bounds.height || style.visibility === 'hidden' || style.display === 'none') return [];
          const owner = element.closest('[data-subject-ref]')?.getAttribute('data-subject-ref') ?? 'figure';
          const index = counts.get(owner) ?? 0; counts.set(owner, index + 1);
          return [{identity: `${owner}/text/${index}`, text: element.textContent ?? '',
            left: (bounds.left - svg.left) * width / svg.width, top: (bounds.top - svg.top) * height / svg.height,
            right: (bounds.right - svg.left) * width / svg.width, bottom: (bounds.bottom - svg.top) * height / svg.height}];
        });
      });
    } finally { await page.close(); }
    await writeFile(prefix + '.anchors.json', JSON.stringify({imageDigest, anchors}, null, 2) + '\n');
    await publishDesignCapture(imageDigest, anchors);
  }
  console.log(JSON.stringify({svg: prefix + '.svg', scenes: result.receipt.scenes,
    readability: result.receipt.readability, width: result.receipt.width, height: result.receipt.height}));
} finally { await browser.close(); }
