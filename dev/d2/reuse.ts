// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Generic source/POO/SDK adapter. No diagram names, coordinates or routes.
import {readFile, writeFile, mkdir, rename, unlink} from 'node:fs/promises';
import path from 'node:path';
import {createHash, randomUUID} from 'node:crypto';
import {parseArgs} from 'node:util';
import {connect} from '@openmbee/opensysml';
import {chromium, type Page} from 'playwright';
import {composeFigure, composeModelView, graphFromModel, type FigureInput} from '@deterministic-engineering/render';
import {captureOpenSysMLView, projectOpenSysMLView} from '@deterministic-engineering/render/opensysml';
import {composePresentationTheme, presentationThemeLayers} from '@deterministic-engineering/render/presentation-theme';
import {exportFigure} from '@deterministic-engineering/render/export';
import {composeTeaching} from './teaching-view';

const root = path.resolve(import.meta.dir, '../..'), output = path.join(import.meta.dir, 'output');
const {values} = parseArgs({options: {case: {type: 'string'}, evaluate: {type: 'boolean'}}});
if (!values.case) throw new Error('--case <POO case.ss> is required');
const resolve = (name: string) => {
  const result = path.resolve(root, name);
  if (!result.startsWith(root + path.sep)) throw new Error('Expected a repository source or artifact');
  return result;
};
const relative = (name: string) => path.relative(root, name).split(path.sep).join('/');
const caseFile = resolve(values.case), readingsFile = path.join(path.dirname(caseFile), 'readings.ss');
const sha = (value: string | Uint8Array) => createHash('sha256').update(value).digest('hex');
const q = (value: string) => JSON.stringify(value), sym = (value: string) => `(string->symbol ${q(value)})`;
const sources: Record<string, string> = {};
async function capture(name: string) {const filename = resolve(name); const content = await readFile(filename, 'utf8'); sources[relative(filename)] = content; return content;}
await mkdir(output, {recursive: true});
const caseImport = './' + path.relative(output, caseFile).split(path.sep).join('/');
const readingsImport = './' + path.relative(output, readingsFile).split(path.sep).join('/');
// A reader sees a complete old or new handoff, never a truncated Scheme file.
async function publishSource(filename: string, source: string) {
  const pending = filename + '.pending-' + randomUUID();
  try {await writeFile(pending,source,{flag:'wx'});await rename(pending,filename);}
  finally {await unlink(pending).catch(()=>{});}
}
async function selectCapture(filename?: string) {
  await publishSource(path.join(output, 'reuse-input.ss'), `(import :clan/poo/object\n(only-in ${q(caseImport)} DesignCase)\n(only-in ${q(readingsImport)} DesignReadings)${filename ? `\n(only-in ${q('./' + path.relative(output, filename).split(path.sep).join('/'))} NativeCapture)` : ''})\n(export NativeCapture DesignCase DesignReadings)\n${filename ? '' : '(def NativeCapture (.o))\n'}`);
}
async function evaluate(mode: string): Promise<any> {
  const child = Bun.spawn(['just', 'd2-reuse', mode], {cwd: root, stdout: 'pipe', stderr: 'pipe'});
  const [code, stdout, stderr] = await Promise.all([child.exited, new Response(child.stdout).text(), new Response(child.stderr).text()]);
  if (code) throw new Error('D2 Module adapter refused input: ' + (stderr + stdout).slice(-4000));
  return JSON.parse(stdout); // Final process handoff, never an editable model/config file.
}
await selectCapture();
const config = await evaluate('describe');
if (!/^[a-zA-Z0-9_-]+$/.test(config.identity)) throw new Error('Invalid artifact identity');
const directory = path.join(output, config.identity); await mkdir(directory, {recursive: true});
const captureFile = path.join(directory, 'capture.ss'), prefix = path.join(directory, 'figure');
async function report(data: any) {
  const lines = ['#+TITLE: Current model image reading and ASCENT requests', '', '* Outstanding requests', '',
    ...data.requests.map((row: unknown[]) => JSON.stringify(row)), '', '* Grounded facets', '',
    ...data.grounded.map((row: unknown[]) => JSON.stringify(row)), '', '* Scoped answer bases', '',
    ...data.answers.map((row: unknown[]) => JSON.stringify(row)), '', '* Required mechanism structure', '', ...data.missingLinks.map((r: unknown[])=>JSON.stringify(r)), ...data.missingTraces.map((r: unknown[])=>JSON.stringify(r)), '', '* Explanatory relations', '', ...data.links.map((r: unknown[])=>JSON.stringify(r)), '', '* Inferred composition constraints', '', JSON.stringify(data.composition), '', '* Image choices and reasons', '',
    ...(data.teaching.length ? data.teaching.flatMap((row: string[]) => [
      row[0] + ' / ' + row[1] + ' / ' + row[2], row[3] + ': ' + row[5], row[4],
      row[6].replaceAll('\n', ' / '), row[7], 'Source: ' + row[8], row[9], '',
    ]) : data.nodes.flatMap((row: any[]) => [row[1] + ': ' + row[2].replaceAll('\n', ' / '), row[5], '']))];
  await writeFile(path.join(directory, 'findings.org'), lines.join('\n') + '\n');
  console.log(`Scene ${config.identity}: ${data.nodes.length} selected source occurrences; ${data.requests.length} requests; ${data.answers.length} answer bases`);
}
if (values.evaluate) {
  await selectCapture(captureFile); await report(await evaluate('evaluate')); process.exit(0);
}
await capture(relative(caseFile));
const modelRefs: string[] = config.models;
for (const name of [...modelRefs, config.org, ...config.inputs, 'dev/d2/reuse.ts', 'dev/d2/reuse.ss', 'dev/d2/teaching-view.ts', 'dev/d2/init.ss', 'dev/d2/package.json', 'dev/d2/bun.lock']) await capture(name);
for await (const name of new Bun.Glob('**/*.ss').scan({cwd: path.join(root, 'modules/d2')})) await capture('modules/d2/' + name);
const connection = await connect({version: 'v0.11.0', requireCapabilities: ['render_view']});
let native: ReturnType<typeof projectOpenSysMLView>;
const primaryQuestion = {ref: String(config.primary), text: '', focusRefs: ['model']};
const selection: FigureInput['view'] = {source: relative(caseFile), title: config.title, purpose: 'architecture', kind: 'system',
  question: primaryQuestion, basis: {captureRef: config.identity, modelRefs, obligationRefs: [], evidenceRefs: []}};
try {
  const parsed = await connection.parseSources(modelRefs.map(name => [name, sources[name]!] as const)); parsed.raiseForErrors();
  native = projectOpenSysMLView(await captureOpenSysMLView(connection, parsed.hash, config.view), {selection, layout: 'reflow'});
} finally {await connection.close();}
const sourceById = new Map(native.model.subjects.map(node => [node.id, node]));
function sourcePath(id: string): string {const node = sourceById.get(id)!; return node.parent ? sourcePath(node.parent) + '/' + node.sourceName : node.sourceName!;}
const cut = 'sha256-' + sha(JSON.stringify([...modelRefs, config.org].map(name => [name, sources[name]])));
const nativeNodes = native.model.subjects.map(node => `(.o identity: ${sym(node.id)} source-ref: ${q(sourcePath(node.id))} kind: ${sym(node.type)} label: ${q(node.label ?? node.id)})`).join('\n');
const parents = native.model.subjects.filter(node => node.parent).map(node => `(list ${sym(node.id)} ${sym(node.parent!)})`).join('\n');
// The POO case owns assets. Discover chosen paths through the admitted scene,
// not by searching a domain-specific icon registry or interpreting object kinds.
let assetDigest = sha(sources[relative(caseFile)]!);
let imageRecords = "'()", anchorRecords = "'()", routeRecords = "'()";
async function publish() {
  const hashes = Object.entries(sources).map(([name, content]) => `(list ${q(name)} ${q(sha(content))})`).join('\n');
  const documents = [...modelRefs, config.org].map(name => `(.o identity: ${q(name)} text: ${q(sources[name]!)})`).join('\n');
  await publishSource(captureFile, `(import :clan/poo/object)\n(export NativeCapture)\n(def NativeCapture (.o\n nodes: (list ${nativeNodes})\n parents: (list ${parents})\n documents: (list ${documents})\n source-hashes: (list ${hashes})\n view: (.o identity: ${sym(config.identity)} revision: 'design source-cut: ${sym(cut)} audience: ${sym(config.audience)})\n proposals: (list (.o identity: 'current-scene view: ${sym(config.identity)} revision: 'design source-cut: ${sym(cut)} asset-ref: ${q(relative(caseFile))} asset-sha: ${q(assetDigest)}))\n renders: ${imageRecords}\n image-anchors: ${anchorRecords}\n image-routes: ${routeRecords}))\n`);
  await selectCapture(captureFile); return evaluate('evaluate');
}
let state = await publish();
for (const row of state.nodes) if (row[3]) await capture(row[3]);
for (const row of state.teaching) if (row[4]) {const asset=await capture(row[4]);if(/data-scene-(?:edge|node)|data-explanation-id/.test(asset))throw new Error('Object artwork cannot contain a whole explanatory scene: '+row[4]);}
assetDigest = sha(JSON.stringify(Object.entries(sources))); 
state = await publish(); await report(state);
const chosen = new Set(state.nodes.map((row: any[]) => row[0]));
const annotated = {...native.model,
  subjects: state.nodes.map((row: any[]) => ({...sourceById.get(row[0])!, label: row[2], parent: row[7] || undefined, level: undefined})),
  relations: native.model.relations.filter(edge => chosen.has(edge.src) && chosen.has(edge.dst))};
const roles: Record<string, string> = {}, icons: Record<string, {label: string; svg: string}> = {}, iconSelection: Record<string, string> = {};
for (const row of state.nodes) {
  roles[row[0]] = row[4];
  if (row[3]) {const name = 'choice-' + row[0]; icons[name] = {label: row[5], svg: sources[row[3]]!}; iconSelection[row[0]] = name;}
}
for (const row of state.teaching) if (row[4]) icons[row[0]] = {label: row[7], svg: sources[row[4]]!};
primaryQuestion.text = state.questions.find((row: any[]) => row[0] === config.primary)[1];
// Extend only presentation tokens; the SDK/ELK computes every position and route.
const teachingTheme = composePresentationTheme(['ocean', 'comfortable', 'teaching'], {
  ...presentationThemeLayers,
  teaching: {typography: {titleSize:'22px',detailSize:'20px',labelSize:'20px',headingSize:'24px',pageTitleSize:'36px',pageQuestionSize:'22px',noteSize:'20px',bodySize:'20px',lineHeight:'1.5em'},
    spacing: {iconSize:64,iconGap:16,scenePadding:24}, stylesheet:'[data-scene-group="false"]>.scene-frame{fill:none;stroke:none}.scene-glyph+.scene-copy{transform:translate(80px,18px)}[data-role="pending"] .scene-title{fill:#98703D}[data-role="focal"] .scene-title{fill:#207E70}'} });
const options: Record<string,string> = {...Object.fromEntries(state.composition ? state.composition.options : config.layoutOptions), 'elk.direction':String(state.composition ? state.composition.direction : config.direction).toUpperCase(),'elk.edgeRouting':'ORTHOGONAL'};
const graph = graphFromModel(annotated, options);
// ELK options are local to a compound. Apply the same declared options at
// every visible boundary; this is inheritance of native SDK settings, not a
// per-diagram placement algorithm. The case contains no positions or routes.
const inherit = (node: typeof graph) => {if(node.children){node.layoutOptions={...options,...node.layoutOptions};node.children.forEach(inherit);}};
inherit(graph);
const teaching = state.teaching.length > 0;
const attached = new Map<string,string>(state.attachments);
function sceneOwner(id: string): string {return attached.has(id) ? sceneOwner(attached.get(id)!) : id;}
const visibleLinks = state.links.filter((row: string[]) => sceneOwner(row[1]!) !== sceneOwner(row[2]!));
const regionParents = new Map<string,string>(state.regions.flatMap((g:any)=>g.members.map((id:string)=>[id,g.id])));
const displayModel = teaching ? {
  subjects: [...state.regions.map((g:any)=>({id:g.id,type:'rectangle',label:g.label})),...state.teaching.filter((row:string[])=>!attached.has(row[0]!)).map((row: string[]) => ({id:row[0],type:'rectangle',label:row[5],parent:regionParents.get(row[0]!)}))],
  relations: visibleLinks.map((row: any[]) => ({id:row[0],src:sceneOwner(row[1]),dst:sceneOwner(row[2]),label:row[4],srcArrow:'none' as const,dstArrow:row[5] === 'constraint' ? 'none' as const : 'arrow' as const})),
} : annotated;
const figure = composeFigure({model: displayModel, modelTrace: native.trace, sources, icons, theme: teachingTheme, view: selection,
  language: 'en', width: config.width, references: {model:modelRefs[0]},
  questions: teaching ? state.questions.map((row: string[]) => ({ref:row[0],text:row[1],focusRefs:['model']})) : [primaryQuestion],
  presentation: teaching ? {items:state.teaching,links:visibleLinks,attachments:state.attachments,regions:state.regions,composition:state.composition,intro:config.intro,options} : {roles, icons:iconSelection, options, graph}}, teaching ? composeTeaching : composeModelView);
const browser = await chromium.launch();
async function measure(page: Page) {
  return page.locator('[data-scene-node] [data-text-line], [data-scene-node] .mechanism-art text:not(:has([data-text-line])), [data-scene-node] .scene-group-title, [data-explanation-id] [data-text-line], [data-scene-edge] .scene-label text').evaluateAll(elements=>{
    const counts=new Map<string,number>();return elements.map(element=>{const owner=element.closest('[data-explanation-id], [data-scene-node], [data-scene-edge]')!,id=(owner.getAttribute('data-explanation-id')??owner.getAttribute('data-scene-node')??owner.getAttribute('data-scene-edge'))!,index=counts.get(id)??0;counts.set(id,index+1);const r=element.getBoundingClientRect(),m=(element as SVGGraphicsElement).getScreenCTM();return {identity:`${id}/text/${index}`,owner:id,facet:owner.getAttribute('data-facet'),target:owner.getAttribute('data-source-ref'),text:element.textContent??'',left:r.left,top:r.top,right:r.right,bottom:r.bottom,expression:element.closest('[data-visual-expression]')?.getAttribute('data-visual-expression'),fontSize:parseFloat(getComputedStyle(element).fontSize)*(m?Math.hypot(m.c,m.d):1)};});});
}
async function measureRoutes(page: Page) {
  return page.locator('[data-scene-edge]').evaluateAll(elements=>elements.flatMap(e=>{
    const path=e.querySelector('path');
    // An incomplete/rejected SDK layout has no measurable route. Leave the
    // observation absent so ASCENT requests measurement rather than inventing it.
    if(!path?.getAttribute('d')?.trim())return [];
    const m=path.getScreenCTM(),length=path.getTotalLength();
    if(!m || !Number.isFinite(length) || length<=0)return [];
    const a=path.getPointAtLength(0),b=path.getPointAtLength(length);
    const start=new DOMPoint(a.x,a.y).matrixTransform(m),end=new DOMPoint(b.x,b.y).matrixTransform(m);
    return [{identity:e.getAttribute('data-scene-edge')!,from:e.getAttribute('data-source-id')!,to:e.getAttribute('data-target-id')!,length:length*Math.hypot(m.a,m.b),direct:Math.hypot(start.x-end.x,start.y-end.y)}];
  }));
}
async function observe(png: Uint8Array, anchors: any[], image: string, routes: Awaited<ReturnType<typeof measureRoutes>>) {
  const digest=sha(png);
  imageRecords=`(list (.o proposal: 'current-scene asset-sha: ${q(assetDigest)} image-sha: ${q(digest)} image-ref: ${q(relative(image))}))`;
  anchorRecords=`(list ${anchors.map(a=>`(.o image-sha: ${q(digest)} identity: ${q(a.identity)} text: ${q(a.text)} left: ${a.left} top: ${a.top} right: ${a.right} bottom: ${a.bottom} font-size: ${a.fontSize}${a.expression ? ` expression: ${sym(a.expression)}` : ''}${a.facet && a.target ? ` owner: ${q(a.owner)} facet: ${sym(a.facet)} target: ${q(a.target)}` : ''})`).join('\n')})`;
  routeRecords=`(list ${routes.map(r=>`(.o image-sha: ${q(digest)} identity: ${q(r.identity)} from: ${sym(r.from)} to: ${sym(r.to)} length: ${r.length} direct: ${r.direct})`).join('\n')})`;
  await writeFile(prefix+'.routes.json',JSON.stringify({imageDigest:digest,routes},null,2)+'\n');
  await writeFile(prefix+'.anchors.json',JSON.stringify({sourceCut:cut,imageDigest:digest,image:relative(image),anchors},null,2)+'\n');
  await report(await publish()); return digest;
}
let diagnostic: {png: Uint8Array; html: string; anchors: any[]; routes: Awaited<ReturnType<typeof measureRoutes>>} | undefined;
// Observe the SDK's actual page before it closes, including rejected layouts.
// The original export gate still throws; this never publishes a rejected figure.
const observedBrowser = new Proxy(browser, {get(target, property) {
  if (property === 'newContext') return async (options: Parameters<typeof browser.newContext>[0]) => {
    const context=await browser.newContext(options), close=context.close.bind(context);
    context.close=async options=>{
      for(const page of context.pages()) if(await page.locator('[data-figure]').count())
        diagnostic={png:await page.locator('[data-figure]').screenshot(),html:await page.content(),anchors:await measure(page),routes:await measureRoutes(page)};
      await close(options);
    };return context;
  };
  const value=Reflect.get(target,property,target);return typeof value==='function'?value.bind(target):value;
}});
try {
  let result: Awaited<ReturnType<typeof exportFigure>>;
  try {
    result = await exportFigure(figure, observedBrowser, {scale:1, minimumTextSize:12,
      attribution:{copyright:['2026 tao3k team and Contributors','2026 hardenedlinux Linux Team and Contributors','2016 The Inter Project Authors'],license:'Apache-2.0 AND LGPL-2.1-or-later AND OFL-1.1'}});
  } catch(error) {
    if(diagnostic) {
      const image=prefix+'-rejected.png';await writeFile(image,diagnostic.png);await writeFile(prefix+'-rejected.html',diagnostic.html);
      await observe(diagnostic.png,diagnostic.anchors,image,diagnostic.routes);
      console.error('Rejected layout retained for actual model inspection: '+relative(image));
    }
    throw error;
  }
  for (const [name,content] of Object.entries(sources)) if (await readFile(resolve(name),'utf8') !== content) throw new Error('Source changed during render: '+name);
  await writeFile(prefix+'.png', result.png); await writeFile(prefix+'.svg',result.svg[0]!); await writeFile(prefix+'.html',result.html);
  const digest=sha(result.png), page=await browser.newPage({viewport:{width:result.receipt.width,height:result.receipt.height}});
  let anchors:any[],routes:Awaited<ReturnType<typeof measureRoutes>>;
  try {await page.setContent(result.html);await page.evaluate(()=>document.fonts.ready);
    anchors=await measure(page);routes=await measureRoutes(page);
  } finally {await page.close();}
  await observe(result.png,anchors,prefix+'.png',routes);
  await writeFile(prefix+'.receipt.json',JSON.stringify({sourceSHA256:figure.sourceSHA256,sourceCut:cut,imageDigest:digest,rendering:result.receipt},null,2)+'\n');
  console.log(JSON.stringify({image:relative(prefix+'.png'),readability:result.receipt.readability,width:result.receipt.width,height:result.receipt.height}));
} finally {await browser.close();}
