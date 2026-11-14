// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import type {FigureComposer} from '@deterministic-engineering/render';

// A project-authored explanatory SVG, over SDK subject identities.
// The drawings are visual metaphors, not another executable workflow/model.
export function illustrationAssets(context: Parameters<FigureComposer>[0]) {
  const id = (name: string) => {
    const node = context.model!.subjects.find(node => node.sourceName === name);
    if (!node) throw new Error('Illustration requires Context subject: ' + name);
    return context.text(node.id);
  };
  const txt = (x: number, y: number, value: string, size = 22, color = '#244957', weight = 400, anchor = 'start') =>
    `<text x="${x}" y="${y}" font-size="${size}" fill="${color}" font-weight="${weight}" text-anchor="${anchor}">${context.text(value)}</text>`;
  const line = (d: string, color = '#7E9DA3', dashed = false) =>
    `<path d="${d}" fill="none" stroke="${color}" stroke-width="3" stroke-linecap="round" ${dashed ? 'stroke-dasharray="7 8"' : ''}/>`;
  const arrow = (d: string, color = '#148C8C', dashed = false) =>
    `<path d="${d}" fill="none" stroke="${color}" stroke-width="3" stroke-linecap="round" marker-end="url(#tip)" ${dashed ? 'stroke-dasharray="7 8"' : ''}/>`;
  const paper = (x: number, y: number, color: string, rotation = 0) => `<g transform="translate(${x} ${y}) rotate(${rotation} 55 65)">
    <rect x="3" y="8" width="105" height="132" rx="11" fill="#254B5920"/>
    <path d="M0 12Q0 0 12 0H72L106 34V122Q106 134 94 134H12Q0 134 0 122Z" fill="white" stroke="${color}" stroke-width="2.5"/>
    <path d="M72 0V34H106" fill="${color}22" stroke="${color}" stroke-width="2.5"/>
    <rect x="17" y="53" width="53" height="8" rx="4" fill="${color}"/>
    <rect x="17" y="74" width="70" height="6" rx="3" fill="${color}66"/>
    <rect x="17" y="93" width="59" height="6" rx="3" fill="${color}44"/>
  </g>`;
  const cube = (x: number, y: number, color: string, name: string) => `<g transform="translate(${x} ${y})">
    <path d="M0 18L29 0H115L87 18Z" fill="${color}" opacity=".5"/>
    <path d="M87 18L115 0V67L87 85Z" fill="${color}"/>
    <path d="M0 18H87V85H0Z" fill="white" stroke="${color}" stroke-width="2.5"/>
    <circle cx="19" cy="35" r="4" fill="${color}"/><circle cx="32" cy="35" r="4" fill="${color}" opacity=".5"/>
    ${txt(44, 65, name, 21, '#244957', 700, 'middle')}
  </g>`;
  const graphNode = (x: number, y: number, color: string, label: string) => `<g>
    <circle cx="${x}" cy="${y}" r="24" fill="white" stroke="${color}" stroke-width="3"/>
    ${txt(x, y + 8, label, 22, color, 700, 'middle')}</g>`;
  const model = (x = 1110, y = 246) => `<g transform="translate(${x} ${y})">
    <ellipse cx="37" cy="147" rx="85" ry="16" fill="#3C4D7D12"/>
    <path d="M-19 145Q-18 72 37 74Q92 72 96 145" fill="#7479BD"/>
    <path d="M19 78L37 101L55 78" fill="#F6F3ED"/>
    <rect x="23" y="60" width="29" height="26" rx="9" fill="#EAC0A1"/>
    <ellipse cx="37" cy="29" rx="44" ry="48" fill="#F5D6B9"/>
    <path d="M-7 29Q-17-32 38-27Q88-25 81 30L68 8L57 0L11 7Z" fill="#29465B"/>
    <g fill="white" stroke="#29465B" stroke-width="3"><rect x="3" y="20" width="27" height="22" rx="8"/><rect x="44" y="20" width="27" height="22" rx="8"/><path d="M30 29H44"/></g>
    <circle cx="19" cy="31" r="3" fill="#29465B"/><circle cx="56" cy="31" r="3" fill="#29465B"/>
    <path d="M28 56Q38 64 48 55" fill="none" stroke="#B67863" stroke-width="3" stroke-linecap="round"/>
    <path d="M-7 105L-48 82M81 105L116 83" stroke="#7479BD" stroke-width="24" stroke-linecap="round"/>
    <path d="M-50 80L-64 69M116 81L128 66" stroke="#F5D6B9" stroke-width="13" stroke-linecap="round"/>
    <path d="M-30-36Q-57-54-86-24M78-37Q110-57 133-29" fill="none" stroke="#AAB0D3" stroke-width="2.5" stroke-dasharray="5 5"/>
    <circle cx="-83" cy="-36" r="26" fill="#FFF0CF" stroke="#D6B26C" stroke-width="2"/>
    <circle cx="135" cy="-41" r="28" fill="#E8EAFB" stroke="#969CC6" stroke-width="2"/>
    ${txt(-83, -28, 'A?', 22, '#8A6835', 700, 'middle')}${txt(135, -33, 'B?', 22, '#5B6196', 700, 'middle')}
    ${txt(37, 131, 'LLM', 20, 'white', 700, 'middle')}
  </g>`;
  const folder = (x = 130, y = 729) => `<g transform="translate(${x} ${y})">
    ${paper(28, -24, '#D9AA5C', -8)}${paper(104, -34, '#8FABC0', 8)}
    <path d="M0 51Q0 38 13 38H93L109 55H237Q250 55 250 68V147Q250 160 237 160H13Q0 160 0 147Z" fill="#F4DFB9" stroke="#CEA261" stroke-width="3"/>
    <path d="M1 82H249" stroke="#E4BF83" stroke-width="3"/>
    <circle cx="126" cy="120" r="25" fill="#FFFBF2"/>${txt(126, 128, '?', 29, '#B18341', 700, 'middle')}
  </g>`;
  const books = (x = 1034, y = 736) => `<g transform="translate(${x} ${y})">
    <path d="M-12 139H280L268 156H0Z" fill="#C7DCDD"/>
    <rect x="0" y="0" width="71" height="137" rx="7" fill="#338F8E"/>
    <rect x="78" y="-17" width="71" height="154" rx="7" fill="#739FC2"/>
    <g transform="rotate(-9 220 135)"><rect x="159" y="9" width="71" height="128" rx="7" fill="#D9AB65"/>
      <g transform="translate(195 72) rotate(-90)">${txt(0, 0, 'Limits', 23, '#FFFFFF', 700, 'middle')}</g></g>
    <g transform="translate(36 70) rotate(-90)">${txt(0, 0, 'Method', 23, '#FFFFFF', 700, 'middle')}</g>
    <g transform="translate(114 62) rotate(-90)">${txt(0, 0, 'Scope', 23, '#FFFFFF', 700, 'middle')}</g>
    <rect x="14" y="111" width="43" height="7" rx="3" fill="#FFFFFF66"/><rect x="92" y="111" width="43" height="7" rx="3" fill="#FFFFFF66"/>
  </g>`;
  return {id, txt, line, arrow, paper, cube, graphNode, model, folder, books};
}

export const composeIllustratedContext: FigureComposer = context => {
  const {id, txt, line, arrow, paper, cube, graphNode, model, folder, books} = illustrationAssets(context);
  return {markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1440" height="1100" viewBox="0 0 1440 1100" role="img" aria-label="Context, time windows and reusable knowledge">
    <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
    <rect width="1440" height="1100" fill="#FAFCFA"/>
    ${txt(42, 62, 'Context turns experience into reusable understanding', 36, '#244957', 700)}
    ${txt(44, 104, 'Objects, relationships, models and real feedback help us revisit what we know.', 23, '#567781')}
    <rect x="28" y="140" width="1384" height="840" rx="26" fill="#EEF7F5" stroke="#C1DDDA" stroke-width="2"/>
    ${txt(53, 181, 'Context / the whole information space', 24, '#168383', 700)}
    <g data-subject-ref="${id('content')}">${paper(87, 224, '#D1A762', -10)}${paper(126, 230, '#719ABD', 8)}
      ${txt(170, 428, 'New information', 24, '#244957', 700, 'middle')}</g>
    ${arrow('M265 305H324')}
    <g data-subject-ref="${id('composition')}">
      ${cube(347, 239, '#75A5C2', 'Goal')}${cube(407, 304, '#319994', 'Obs.')}${cube(468, 213, '#D7AA64', 'Idea')}
      ${line('M587 275L650 247L705 300M650 247L687 204M650 247L633 320', '#8BA6AC', true)}
      ${graphNode(632, 320, '#319994', '✓')}${graphNode(687, 204, '#D7AA64', '?')}${graphNode(705, 300, '#9296BF', '?')}
      ${txt(530, 428, 'POO objects + relations', 24, '#244957', 700, 'middle')}
    </g>
    ${arrow('M750 305H795')}
    <g data-subject-ref="${id('projection')}" transform="translate(824 248)">
      <path d="M0 28L24 0H128L151 28V108H0Z" fill="#FFFFFF" stroke="#629D9D" stroke-width="3"/>
      <path d="M0 28H151M76 1V28" stroke="#A3C8C3" stroke-width="2"/>
      <rect x="19" y="47" width="32" height="42" rx="6" fill="#D5E7EF"/><rect x="59" y="47" width="32" height="42" rx="6" fill="#DFEFE9"/><rect x="100" y="47" width="32" height="42" rx="6" fill="#F2E4CB"/>
      ${txt(75, 180, 'A selected view', 24, '#244957', 700, 'middle')}
    </g>
    ${arrow('M993 305H1040')}${model()}
    ${txt(1170, 428, 'Models explore new ideas', 23, '#244957', 700, 'middle')}
    <rect x="354" y="461" width="947" height="105" rx="18" fill="#D6E9F3" opacity=".64" stroke="#99BDCF" stroke-width="2" stroke-dasharray="7 6"/>
    ${arrow('M89 498H1340', '#829DA5')}
    ${[145, 444, 774, 1188].map(x => line(`M${x} 489V507`, '#829DA5')).join('')}
    ${txt(145, 538, 'Observe', 21, '#567781', 400, 'middle')}${txt(444, 538, 'Use', 21, '#567781', 400, 'middle')}
    ${txt(774, 538, 'Get feedback', 21, '#567781', 400, 'middle')}${txt(1188, 538, 'Revisit', 21, '#567781', 400, 'middle')}
    ${txt(830, 611, 'A bounded window of experience', 24, '#41758E', 700, 'middle')}
    ${arrow('M719 625V682')}${txt(744, 660, 'Actual outcomes + evidence', 20, '#567781')}
    <g transform="translate(643 723)">
      ${paper(5, -10, '#8EA8B1', -5)}
      <circle cx="106" cy="64" r="48" fill="#DFF2EF" fill-opacity=".86" stroke="#248C89" stroke-width="8"/>
      <path d="M141 101L185 145" stroke="#248C89" stroke-width="16" stroke-linecap="round"/>
      ${txt(107, 77, '?', 36, '#248C89', 700, 'middle')}
    </g>
    ${txt(735, 922, 'Reinterpret', 27, '#244957', 700, 'middle')}
    ${txt(735, 953, 'Model judgment + ASCENT + evidence', 20, '#567781', 400, 'middle')}
    ${arrow('M626 752Q527 700 410 757', '#BD975A')}${txt(492, 712, 'Still unresolved', 23, '#9D7A42', 700, 'middle')}
    ${arrow('M875 759Q950 697 1023 755')}${txt(1005, 707, 'Supported + reusable', 23, '#168383', 700, 'middle')}
    <g data-subject-ref="${id('shortTerm')}">${folder()}${txt(259, 937, 'Keep experience + questions', 24, '#8A6A3D', 700, 'middle')}</g>
    <g data-subject-ref="${id('longTerm')}">${books()}${txt(1165, 937, 'Long-term knowledge', 26, '#168383', 700, 'middle')}</g>
    ${arrow('M1326 794Q1380 792 1380 704V596', '#6C9C9A', true)}${txt(1235, 658, 'Recall later', 20, '#567781')}
    <path d="M57 1000H1382" stroke="#D8E5E1" stroke-width="2"/>
    <circle cx="85" cy="1041" r="22" fill="none" stroke="#568E8C" stroke-width="3"/>
    ${line('M85 1027V1041L96 1048', '#568E8C')}
    ${txt(124, 1049, 'Time invites a revisit. Evidence and use determine what we retain.', 25, '#244957', 700)}
    ${txt(124, 1082, 'Illustrative retention view. Age does not prove truth; retained knowledge remains open to revision.', 19, '#65818A')}
  </svg>`, css: '[data-vector-surface]{display:block;max-width:100%;height:auto}'};
};
