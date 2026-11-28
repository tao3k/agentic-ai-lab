// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// IO adapter for an open model-host exchange. No semantic rules or stage loop.
import {readFile, writeFile, mkdir, readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {parseArgs} from 'node:util';
import {chromium} from 'playwright';
import {compileModel, composeFigure} from '@deterministic-engineering/render';
import {exportFigure} from '@deterministic-engineering/render/export';

const directory = import.meta.dir, root = path.resolve(directory, '../..');
const output = path.join(directory, 'output/authoring');
const sha = (data: string | Uint8Array) => createHash('sha256').update(data).digest('hex');
const {values} = parseArgs({options: {asset: {type: 'string'}, revision: {type: 'string'}, verify: {type: 'boolean'}}});
type Receipt = {revision: string; asset: string; assetSHA256: string; image: string; imageSHA256: string;
  semanticSources: Record<string, string>; sourceSHA256: Readonly<Record<string, string>>; rendering: unknown};
const resolve = (name: string) => {
  const filename = path.resolve(root, name);
  if (!filename.startsWith(root + path.sep)) throw new Error('Expected a repository artifact');
  return filename;
};
if (values.verify) {
  const files = await readdir(output).catch(() => [] as string[]);
  let count = 0;
  for (const name of files.filter(name => name.endsWith('.receipt.json'))) {
    const receipt: Receipt = JSON.parse(await readFile(path.join(output, name), 'utf8'));
    for (const [name, expected] of Object.entries({[receipt.asset]: receipt.assetSHA256,
      [receipt.image]: receipt.imageSHA256, ...receipt.semanticSources}))
      if (sha(await readFile(resolve(name))) !== expected) throw new Error('Stale authoring artifact: ' + name);
    count++;
  }
  console.log(`Verified ${count} authoring image/source receipts`);
  process.exit(0);
}
if (!values.asset || !values.revision || !/^[a-zA-Z0-9_-]+$/.test(values.revision))
  throw new Error('Use --asset <repository SVG> --revision <id>, or --verify');
const asset = path.relative(root, resolve(values.asset));
const svg = await readFile(resolve(asset), 'utf8');
if (!svg.includes('data-vector-surface') || /[\u3400-\u9fff]/u.test(svg))
  throw new Error('Expected an English-only model-authored vector surface');
const sources: Record<string, string> = {[asset]: svg};
const semanticSources: Record<string, string> = {};
for (const name of ['dev/d2/context-evolution-example.ss', 'dev/d2/output/ascent-early.d2', 'dev/d2/output/ascent-later.d2']) {
  sources[name] = await readFile(resolve(name), 'utf8');
  semanticSources[name] = sha(sources[name]!);
}
for (const name of ['dev/d2/session-render.ts', 'dev/d2/author.ss', 'dev/d2/examples/time-window/scenario.ss', 'dev/d2/examples/time-window/history.ss'])
  sources[name] = await readFile(resolve(name), 'utf8');
for await (const name of new Bun.Glob('**/*.ss').scan({cwd: path.join(root, 'modules/d2')})) {
  const source = 'modules/d2/' + name;
  sources[source] = await readFile(resolve(source), 'utf8');
}
const modelRef = 'dev/d2/output/ascent-later.d2';
const {model} = await compileModel({[modelRef]: sources[modelRef]!}, modelRef);
const figure = composeFigure({model, sources, language: 'en', width: 1600,
  references: {model: modelRef}, questions: [{ref: 'context-lesson', text: 'How can a late observation change what we keep?', focusRefs: ['model']}],
  view: {source: 'dev/d2/author.ss', title: 'How time changes Context', purpose: 'architecture', kind: 'system',
    question: {ref: 'context-lesson', text: 'How can a late observation change what we keep?'},
    basis: {captureRef: values.revision, modelRefs: [modelRef], obligationRefs: [], evidenceRefs: []}}},
  context => ({markup: svg.replace('data-vector-surface', `data-vector-surface data-question="${context.text(context.view.question.ref)}"`)
    .replace(/data-object="([^"]+)"/g, (_, name: string) => {
      const subject = context.model!.subjects.find(subject => subject.id === name);
      if (!subject) throw new Error('Image names an undeclared Context object: ' + name);
      return `data-object="${context.text(name)}" data-subject-ref="${context.text(subject.id)}"`;
    }),
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto;font-family:Inter,sans-serif}'}));
const browser = await chromium.launch();
try {
  const result = await exportFigure(figure, browser, {scale: 1, minimumTextSize: 12,
    attribution: {copyright: ['2026 tao3k team and Contributors', '2026 hardenedlinux Linux Team and Contributors',
      '2016 The Inter Project Authors (https://github.com/rsms/inter)'], license: 'Apache-2.0 AND LGPL-2.1-or-later AND OFL-1.1'}});
  for (const [name, content] of Object.entries(sources))
    if (await readFile(resolve(name), 'utf8') !== content) throw new Error('Source changed during export: ' + name);
  await mkdir(output, {recursive: true});
  const prefix = path.join(output, values.revision);
  await writeFile(prefix + '.png', result.png);
  await writeFile(prefix + '.svg', result.svg[0]!);
  await writeFile(prefix + '.html', result.html);
  const receipt: Receipt = {revision: values.revision, asset, assetSHA256: sha(svg),
    image: path.relative(root, prefix + '.png'), imageSHA256: sha(result.png), semanticSources,
    sourceSHA256: figure.sourceSHA256, rendering: result.receipt};
  await writeFile(prefix + '.receipt.json', JSON.stringify(receipt, null, 2) + '\n');
  console.log(JSON.stringify({assetSHA256: receipt.assetSHA256, imageSHA256: receipt.imageSHA256,
    image: receipt.image, readability: result.receipt.readability}));
} finally { await browser.close(); }
