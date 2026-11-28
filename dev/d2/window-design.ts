// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// A model-authored illustration of the selected Org/SysML design. Geometry is
// local to this picture; the SDK/Module supply its objects and relation identities.
import type {FigureComposer} from '@deterministic-engineering/render';
import type {ModelSymbol} from '@openmbee/opensysml';

export const composeWindowDesign = (graphDetails: ModelSymbol, knowledgeDetails: ModelSymbol): FigureComposer => context => {
  const sourceText = (symbol: ModelSymbol, name: string) => {
    const value = symbol.attribute(name)?.value;
    if (value?.kind !== 'string') throw new Error('The selected SysML illustration needs textual content: ' + name);
    return value.value;
  };
  const parts = context.model!.subjects;
  const subject = (name: string) => {
    const matches = parts.filter(part => part.sourceName === name || part.sourceName?.endsWith('::' + name));
    if (matches.length !== 1) throw new Error('This illustration needs one SysML subject: ' + name);
    return matches[0]!;
  };
  const id = (name: string) => context.text(subject(name).id);
  const text = (x: number, y: number, value: string, size = 22, color = '#526F79', weight = 400, anchor = 'start') =>
    `<text x="${x}" y="${y}" font-size="${size}" fill="${color}" font-weight="${weight}" text-anchor="${anchor}">${context.text(value)}</text>`;
  const line = (d: string, color = '#83A6A8', dashed = false, arrow = false) =>
    `<path d="${d}" fill="none" stroke="${color}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"${dashed ? ' stroke-dasharray="7 8"' : ''}${arrow ? ' marker-end="url(#relation-tip)"' : ''}/>`;
  const circle = (x: number, y: number, radius: number, color: string, fill = 'white') =>
    `<circle cx="${x}" cy="${y}" r="${radius}" fill="${fill}" stroke="${color}" stroke-width="3"/>`;
  const caption = (x: number, y: number, value: string, color = '#526F79') => text(x, y, value, 21, color, 400, 'middle');
  const wrapped = (x: number, y: number, value: string) => {
    const lines: string[] = [];
    for (const word of value.split(/\s+/)) {
      const prior = lines.at(-1);
      if (!prior || prior.length + word.length + 1 > 22) lines.push(word);
      else lines[lines.length - 1] = prior + ' ' + word;
    }
    return lines.map((line, index) => text(x, y + index * 29, line, 21)).join('');
  };

  // Routes are illustration geometry, keyed by native connection names. No
  // relation is added by this composer. Changed endpoints require a new drawing.
  const routes: Record<string, {from: string; to: string; d: string; x: number; y: number; label: string; color?: string; dashed?: boolean}> = {
    selects: {from: 'windows', to: 'graph', d: 'M780 349V400', x: 903, y: 380, label: 'select a situated view'},
    composes: {from: 'objects', to: 'graph', d: 'M445 553H530', x: 488, y: 529, label: 'compose'},
    facts: {from: 'graph', to: 'ascent', d: 'M1025 511H1195', x: 1108, y: 487, label: 'facts'},
    explains: {from: 'ascent', to: 'graph', d: 'M1195 612H1025', x: 1108, y: 646, label: 'relations + reasons'},
    situatedView: {from: 'graph', to: 'model', d: 'M980 670C1080 664 1120 716 1164 767', x: 1055, y: 776, label: 'situated view'},
    proposals: {from: 'model', to: 'graph', d: 'M1215 980C1095 947 1144 792 1009 711', x: 1128, y: 910, label: 'new proposals', color: '#8B7CB0', dashed: true},
    scopedAdmission: {from: 'graph', to: 'knowledge', d: 'M623 702C507 719 453 765 368 814', x: 463, y: 754, label: 'scoped proposal', color: '#AD915C', dashed: true},
    reuseAndRecheck: {from: 'knowledge', to: 'graph', d: 'M577 1150C630 1100 578 942 594 860C600 817 604 790 620 755', x: 660, y: 1200, label: 'reuse + recheck'},
    actualUse: {from: 'graph', to: 'outcomes', d: 'M780 758V800', x: 865, y: 777, label: 'permitted use'},
    newEvidence: {from: 'outcomes', to: 'graph', d: 'M690 936C612 888 610 811 675 740', x: 610, y: 809, label: 'new evidence'},
  };
  const connectors = context.model!.relations.map(edge => {
    const route = routes[edge.label ?? ''];
    if (!route || edge.src !== subject(route.from).id || edge.dst !== subject(route.to).id)
      throw new Error('SysML changed: the model must reconsider this relation drawing: ' + edge.label);
    const labelWidth = route.label.length * 11 + 18;
    return `<g data-relation-ref="${context.text(edge.id)}">${line(route.d, route.color ?? '#198D87', route.dashed, true)}<rect x="${route.x - labelWidth / 2}" y="${route.y - 23}" width="${labelWidth}" height="31" fill="#EFF7F3"/>${caption(route.x, route.y, route.label, route.color)}</g>`;
  }).join('');
  if (context.model!.relations.length !== Object.keys(routes).length)
    throw new Error('The illustration must account for every selected SysML relation');

  return {markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1600" height="1350" viewBox="0 0 1600 1350" role="img" aria-label="Time windows, preserved earlier views, changed evidence and a method with concrete applicability limits">
    <defs><marker id="relation-tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
    <rect width="1600" height="1350" fill="#FBFCF8"/>
    ${text(52, 61, 'Time changes the view. Evidence changes the meaning.', 39, '#244957', 700)}
    ${text(54, 104, 'One Context. Shared objects. Open explanations.', 25)}
    <g data-subject-ref="${id('ContextEvolution')}">
    <rect x="30" y="130" width="1540" height="1155" rx="30" fill="#EFF7F3" stroke="#BCD9D2" stroke-width="2"/>
    <g data-subject-ref="${id('windows')}">
      <rect x="75" y="158" width="792" height="64" rx="17" fill="#DBEFE7" stroke="#A3CABD" stroke-width="2"/>
      ${text(101, 198, 'Window A / an experiment', 23, '#23897F', 700)}
      ${line('M103 237H1490', '#8BA5AD')}
      ${[170, 460, 790, 1110, 1410].map(x => `<circle cx="${x}" cy="237" r="7" fill="#7B9EA5"/>`).join('')}
      <rect x="475" y="252" width="1035" height="62" rx="17" fill="#EDEAF6" stroke="#B4AACD" stroke-width="2"/>
      ${text(502, 292, 'Window B / later use + new evidence', 23, '#796C9E', 700)}
      ${line('M460 245V261M790 245V261M1110 245V261M1410 245V261', '#B4AACD', true)}
      ${text(76, 344, 'Event time and known time differ. Windows can overlap, reopen or wait.', 21)}
    </g>
    ${connectors}

    <g data-subject-ref="${id('objects')}">
      ${text(73, 452, 'POO / compose objects', 26, '#244957', 700)}
      ${circle(135, 546, 34, '#769EB9', '#E7F0F5')}${circle(135, 546, 20, '#769EB9')}${circle(135, 546, 7, '#769EB9', '#769EB9')}
      ${line('M135 546L171 511', '#769EB9', false, true)}
      ${line('M221 570C277 570 231 518 287 518', '#8D80B0', false, true)}
      ${[221, 252, 287].map((x, i) => circle(x, [570, 546, 518][i]!, 6, '#8D80B0', 'white')).join('')}
      <path d="M326 546Q363 505 403 546Q363 587 326 546Z" fill="#E0F1EA" stroke="#38988E" stroke-width="3"/>
      ${circle(364, 546, 12, '#38988E', '#38988E')}
      ${caption(135, 611, 'Goal')}${caption(254, 611, 'Task')}${caption(365, 611, 'Observation')}
      ${text(75, 666, 'Identity / scope / source', 21)}
      ${text(75, 700, 'New versions keep their history.', 21)}
    </g>

    <g data-subject-ref="${id('graph')}">
      <ellipse cx="780" cy="563" rx="240" ry="147" fill="white" stroke="#B1D4CC" stroke-width="2"/>
      ${text(780, 447, 'One graph, versioned views', 24, '#244957', 700, 'middle')}
      ${caption(660, 490, 'Earlier view')}${caption(900, 490, 'Later view')}
      ${circle(660, 583, 65, '#DBEAE3', '#F4FAF6')}${circle(900, 583, 65, '#E8DCC6', '#FFFBF2')}
      ${text(650, 532, sourceText(graphDetails, 'earlierObservation'), 20, '#248B7F', 400, 'middle')}
      ${text(910, 532, sourceText(graphDetails, 'laterObservation'), 20, '#A08046', 400, 'middle')}
      ${circle(632, 561, 12, '#38988E', '#38988E')}${circle(680, 610, 16, '#D2A159')}
      ${line('M643 572L667 595', '#38988E', false, true)}
      ${text(612, 611, 'supports', 20, '#248B7F', 400, 'middle')}
      ${text(680, 617, '?', 20, '#A08046', 700, 'middle')}
      ${circle(876, 561, 12, '#38988E', '#38988E')}${circle(930, 561, 12, '#C39754', '#C39754')}
      ${circle(903, 610, 16, '#D2A159')}
      ${line('M883 573L896 591', '#38988E', false, true)}${line('M923 573L910 591', '#C39754', false, true)}
      ${text(839, 637, 'supports', 20, '#248B7F', 400, 'middle')}${text(968, 611, 'conflicts', 20, '#A08046', 400, 'middle')}
      ${text(903, 617, '?', 20, '#A08046', 700, 'middle')}
      ${line('M730 608H832', '#8A9DA7', true, true)}${caption(781, 572, 'same idea')}
      ${text(660, 664, sourceText(graphDetails, 'sharedHypothesis'), 20, '#526F79', 400, 'middle')}
      ${text(903, 664, sourceText(graphDetails, 'sharedHypothesis'), 20, '#526F79', 400, 'middle')}
      ${caption(780, 730, sourceText(graphDetails, 'retainedEarlier'))}
    </g>

    <g data-subject-ref="${id('ascent')}">
      ${text(1169, 450, 'ASCENT / relate + explain', 25, '#244957', 700)}
      <circle cx="1322" cy="551" r="68" fill="#E1F2EA" stroke="#258D85" stroke-width="7"/>
      ${line('M1369 600L1420 651', '#258D85')}
      <path d="M1369 600L1420 651" stroke="#258D85" stroke-width="13" stroke-linecap="round"/>
      ${line('M1286 563L1323 516L1360 558M1323 516V593', '#459A8C')}
      ${circle(1286, 563, 6, '#459A8C', '#459A8C')}${circle(1323, 516, 6, '#459A8C', '#459A8C')}${circle(1360, 558, 6, '#BE9856', '#BE9856')}
      ${caption(1322, 691, 'Support / conflict / impact')}
      ${caption(1322, 727, 'Why? Why not? What changed?')}
    </g>

    <g data-subject-ref="${id('knowledge')}">
      ${text(73, 855, 'Knowledge / keep the limits', 27, '#244957', 700)}
      ${text(75, 891, 'A candidate, not an automatic promotion.', 20)}
      <path d="M74 926Q202 900 330 926Q450 900 575 926V1180Q450 1154 330 1180Q202 1154 74 1180Z" fill="#FFF9EA" stroke="#C4AA73" stroke-width="3"/>
      ${line('M330 926V1180', '#D2BA89')}
      ${text(95, 965, 'Proposed method', 23, '#9C7A3D', 700)}
      ${wrapped(95, 1000, sourceText(knowledgeDetails, 'proposedMethod'))}
      ${text(95, 1080, 'Where it applies', 23, '#9C7A3D', 700)}
      ${wrapped(95, 1115, sourceText(knowledgeDetails, 'applicability'))}
      ${text(352, 965, 'Counterexample', 23, '#9C7A3D', 700)}
      ${wrapped(352, 1000, sourceText(knowledgeDetails, 'counterexample'))}
      ${text(352, 1080, 'Recheck when', 23, '#9C7A3D', 700)}
      ${wrapped(352, 1115, sourceText(knowledgeDetails, 'recheckWhen'))}
      ${text(75, 1225, 'The counterexample travels with the method.', 21)}
      ${text(75, 1258, 'A changed scope reopens the question.', 21)}
    </g>

    <g data-subject-ref="${id('outcomes')}">
      ${text(790, 856, 'Real-world feedback', 26, '#244957', 700, 'middle')}
      <path d="M689 1025V944A91 91 0 0 1 871 944V1025Z" fill="white" stroke="#80A5A5" stroke-width="3"/>
      <path d="M712 944A68 68 0 0 1 848 944" fill="none" stroke="#C8DED5" stroke-width="15"/>
      ${line('M781 947L825 904', '#278F83')}${circle(781, 947, 9, '#278F83', '#278F83')}
      ${line('M711 986H847M723 1010H837', '#B3CDCA')}
      <path d="M906 917H960V1024L950 1018L938 1024L926 1018L906 1024Z" fill="#FFFBF2" stroke="#C4AA73" stroke-width="2"/>
      ${line('M917 942H948M917 963H943M917 984H948', '#C4AA73')}
      ${caption(795, 1100, 'Actual outcomes, not confidence')}
      ${caption(795, 1133, 'A counterexample can reopen a claim.')}
    </g>

    <g data-subject-ref="${id('model')}">
      ${text(1145, 808, 'Model / explore + explain', 25, '#244957', 700)}
      <g transform="translate(1262 929) rotate(-28)">
        <path d="M0 0H131V47H0Z" fill="#A9A2CE" stroke="#8175A8" stroke-width="3"/>
        <path d="M112-10H144V57H112Z" fill="#DBD7EC" stroke="#8175A8" stroke-width="3"/>
        <ellipse cx="144" cy="24" rx="13" ry="34" fill="#F4F8FC" stroke="#8175A8" stroke-width="3"/>
      </g>
      ${line('M1320 953L1275 1042M1320 953L1369 1042M1320 953V1042', '#8175A8')}
      ${circle(1233, 874, 28, '#CFAB67', '#FFF1D4')}${text(1233, 883, 'A?', 23, '#9A773D', 700, 'middle')}
      ${circle(1465, 880, 28, '#9990BC', '#EEEBF7')}${text(1465, 889, 'B?', 23, '#796C9E', 700, 'middle')}
      ${caption(1331, 1100, 'New questions, ideas and tasks.')}
      ${caption(1331, 1133, 'View the actual image; ask again.')}
    </g>
    </g>
    ${text(52, 1327, 'Relations can reopen independently. There is no mandatory next step.', 26, '#244957', 700)}
  </svg>`, css: '[data-vector-surface]{display:block;max-width:100%;height:auto}'};
};
