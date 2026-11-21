// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import type {FigureComposer} from '@deterministic-engineering/render';
import {illustrationAssets} from './illustration';
import {buildExperimentArt} from './build-experiment-art';

// One model-authored teaching composition, not the Module's layout policy.
// All displayed nodes, status classes and relationship arrows come from its
// ASCENT/D2 result. The explorer is an explanatory illustration, not a claim
// that an external model or a real experiment ran in this development fixture.
export const composeAscentView: FigureComposer = context => {
  const {txt, line, arrow} = illustrationAssets(context);
  const art = buildExperimentArt(context);
  const subjects = context.model!.subjects;
  const kind = (node: typeof subjects[number]) => node.classes?.[0] ?? 'node';
  const windows = subjects.filter(node => kind(node) === 'window');
  const observations = subjects.filter(node => kind(node) === 'observation');
  const proposals = subjects.filter(node => ['proposal', 'candidate'].includes(kind(node)));
  const hypotheses = subjects.filter(node => ['hypothesis', 'conflicted'].includes(kind(node)))
    .sort((a, b) => Number(kind(b) === 'conflicted') - Number(kind(a) === 'conflicted'));
  if (windows.length !== 1 || proposals.length !== 1 || observations.length > 2 || hypotheses.length > 2)
    throw new Error('This teaching composition selects one small experience; choose another composer for a wider view');
  const window = windows[0]!, proposal = proposals[0]!;
  const positions = new Map<string, {x: number; y: number; role: string}>();
  positions.set(window.id, {x: 240, y: 270, role: 'window'});
  observations.forEach((node, index) => positions.set(node.id, {x: 230, y: 415 + index * 315, role: 'observation'}));
  hypotheses.forEach((node, index) => positions.set(node.id, {x: 728, y: 415 + index * 315, role: 'hypothesis'}));
  positions.set(proposal.id, {x: 1140, y: 415, role: 'proposal'});
  // Reader-facing wording; original labels/identities remain in the SDK capture.
  const wording: Record<string, string> = {
    'Stale generated inputs?': 'Old generated files?',
    'Compiler / ABI mismatch?': 'Do the build tools disagree?',
    'Proposed diagnostic method': 'A proposed way to investigate',
    'Clean rebuild passed': 'Rebuilding made it pass',
    'Control run still failed': 'A comparison test still failed',
    'Conflicting evidence': 'The evidence points both ways',
    'Review candidate only': 'Ready for review, not yet accepted',
  };
  const caption = (node: typeof subjects[number], x: number, y: number, color = '#244957') =>
    (node.label ?? node.id).split('\n').map((value, index) => txt(x, y + index * 30, wording[value] ?? value,
      index ? 20 : 24, index ? '#567781' : color, index ? 400 : 700, 'middle')).join('');
  const connectors = context.model!.relations.map(edge => {
    const source = positions.get(edge.src), target = positions.get(edge.dst);
    if (!source || !target) throw new Error('Unrepresented relationship endpoint');
    let path: string, labelX: number, labelY: number;
    if (source.role === 'window') {
      const lower = target.y > 500;
      path = lower ? `M100 270V${target.y - 85}H149` : 'M230 270V329';
      labelX = lower ? 200 : 367; labelY = lower ? target.y - 119 : 310;
    } else if (source.role === 'proposal') {
      path = `M1062 415H${target.x + 123}`; labelX = 957; labelY = 389;
    } else if (source.y > target.y + 80) {
      path = `M320 ${source.y}C450 ${source.y} 493 ${target.y + 57} ${target.x - 124} ${target.y + 57}`;
      labelX = 540; labelY = 650;
    } else {
      path = `M320 ${source.y}H${target.x - 124}`; labelX = 461; labelY = source.y - 23;
    }
    const color = edge.label === 'contradicts' ? '#BC8B43' : edge.label === 'proposes' ? '#8B81B4' : '#248C89';
    const wording = edge.label === 'in-window' ? 'visible in this view' : edge.label;
    return `<g data-relation-ref="${context.text(edge.id)}">${arrow(path, color, edge.label === 'proposes')}${txt(labelX, labelY, wording, 21, color, 400, 'middle')}</g>`;
  }).join('');
  const candidate = kind(proposal) === 'candidate';
  const pictures = observations.map((node, index) => {
    const position = positions.get(node.id)!;
    return `<g data-subject-ref="${context.text(node.id)}">${index ? art.failed(110, position.y - 106) : art.passed(110, position.y - 106)}${caption(node, 235, position.y + 118)}</g>`;
  }).join('') + hypotheses.map(node => {
    const position = positions.get(node.id)!;
    const isMismatch = (node.label ?? '').split('\n')[0] === 'Compiler / ABI mismatch?';
    return `<g data-subject-ref="${context.text(node.id)}">${isMismatch ? art.mismatch(position.x - 120, position.y - 96) : art.oldArtifacts(position.x - 120, position.y - 96, kind(node) === 'conflicted')}
      ${caption(node, position.x, position.y + 118, kind(node) === 'conflicted' ? '#A67B3D' : '#244957')}</g>`;
  }).join('');
  return {markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1440" height="1080" viewBox="0 0 1440 1080" role="img" aria-label="How new evidence changes an open explanation">
    <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
    <rect width="1440" height="1080" fill="#FAFCFA"/>
    ${txt(42, 61, candidate ? 'A useful clue is still only a clue.' : 'A counterexample opens the question again.', 37, '#244957', 700)}
    ${txt(44, 104, 'An illustrative experience. ASCENT keeps evidence, explanations and proposals linked.', 23, '#567781')}
    <rect x="28" y="137" width="1384" height="807" rx="28" fill="#EEF7F5" stroke="#C1DDDA" stroke-width="2"/>
    <g data-subject-ref="${context.text(window.id)}">
      ${txt(57, 178, 'CONTEXT / the current experience view', 24, '#168383', 700)}
      <rect x="61" y="198" width="1308" height="73" rx="18" fill="#DDECF1" stroke="#A5C6D0" stroke-width="2"/>
      ${txt(86, 226, (window.label ?? window.id).split('\n').join(' / '), 22, '#527B8D', 700)}
      ${line('M88 251H1335', '#83A3AE')}
      ${[145, 440, 740, 1040, 1280].map(x => `<circle cx="${x}" cy="251" r="5" fill="#83A3AE"/>`).join('')}
    </g>
    ${connectors}${pictures}
    ${observations.length === 1 ? `<g>${art.explore(139, 681)}${txt(261, 925, 'More explanations may be possible.', 20, '#567781', 400, 'middle')}</g>` : ''}
    <g data-subject-ref="${context.text(proposal.id)}">
      ${art.investigate(1047, 316, candidate)}
      ${caption(proposal, 1160, 544, candidate ? '#248C89' : '#77709E')}
    </g>
    ${observations.length > 1 ? art.explore(1040, 671) : ''}
    ${txt(1171, 927, 'A new scene can use a new visual metaphor.', 20, '#567781', 400, 'middle')}
    <path d="M57 976H1382" stroke="#D8E5E1" stroke-width="2"/>
    ${txt(53, 1015, candidate ? 'A promising method still needs checking before reuse.' : 'A new result can support one idea and challenge another.', 28, '#244957', 700)}
    ${txt(53, 1053, 'Arrows are derived relations. The explorer illustrates open inquiry, not a prescribed next task.', 20, '#65818A')}
  </svg>`, css: '[data-vector-surface]{display:block;max-width:100%;height:auto}'};
};
