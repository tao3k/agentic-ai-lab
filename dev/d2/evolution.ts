// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import type {FigureComposer} from '@deterministic-engineering/render';
import {illustrationAssets} from './illustration';

// One explanatory view, not a reusable fixed-layout policy. The design document
// specifies the proposed ASCENT-driven read model; this picture does not execute it.
export const composeEvolution: FigureComposer = context => {
  const {id, txt, line, arrow, paper, cube, graphNode, model, books} = illustrationAssets(context);
  const label = (x: number, y: number, text: string, color = '#557780') => txt(x, y, text, 20, color, 400, 'middle');
  return {markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1440" height="1190" viewBox="0 0 1440 1190" role="img" aria-label="Event-driven Context evolution, not a fixed workflow">
    <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
    <rect width="1440" height="1190" fill="#FAFCFA"/>
    ${txt(42, 60, 'Time opens new views. Evidence changes what they mean.', 35, '#244957', 700)}
    ${txt(44, 101, 'POO builds objects. ASCENT explains relations. Models keep exploration open.', 23, '#567781')}

    <rect x="70" y="134" width="712" height="73" rx="18" fill="#E1F1EC" stroke="#A4C9C4" stroke-width="2"/>
    ${txt(96, 162, 'Window A / an experiment', 21, '#248784', 700)}
    ${line('M96 185H1330', '#8EA8AE')}
    ${[155, 440, 735, 1010, 1280].map(x => `<circle cx="${x}" cy="185" r="7" fill="#7B9DA6"/>`).join('')}
    <rect x="407" y="215" width="941" height="65" rx="17" fill="#EFEDF8" stroke="#B1ACCF" stroke-width="2"/>
    ${txt(435, 254, 'Window B / later use + new evidence', 21, '#77709E', 700)}
    ${line('M440 195V223M735 195V223M1010 195V223M1280 195V223', '#B6B0CE', true)}
    ${label(300, 303, 'Windows can overlap, reopen, or wait.')}
    ${arrow('M739 285V351')}${label(890, 325, 'new event / changed premise')}

    <rect x="28" y="358" width="1384" height="777" rx="28" fill="#EEF7F5" stroke="#C1DDDA" stroke-width="2"/>
    ${txt(52, 398, 'CONTEXT / an evolving information space', 25, '#168383', 700)}

    <g data-subject-ref="${id('composition')}">
      ${txt(69, 452, 'POO / compose objects', 25, '#244957', 700)}
      ${cube(76, 482, '#75A5C2', 'Goal')}${cube(141, 549, '#319994', 'Obs.')}${cube(205, 480, '#9296BF', 'Task')}
      ${label(227, 684, 'Identity + scope + source + policy')}
      ${label(227, 714, 'New versions preserve earlier ones.')}
    </g>
    ${arrow('M343 535H461')}${label(403, 513, 'compose')}

    <g data-subject-ref="${id('content')}">
      <ellipse cx="714" cy="573" rx="231" ry="127" fill="#FFFFFF" stroke="#B3D6D0" stroke-width="2"/>
      ${txt(714, 444, 'Current object + relation graph', 24, '#244957', 700, 'middle')}
      ${line('M570 543L729 505L839 575L707 644Z', '#83A8AC')}
      ${line('M570 543L707 644M729 505L707 644', '#BC9B66', true)}
      ${graphNode(570, 543, '#75A5C2', 'O')}${graphNode(729, 505, '#9296BF', 'T')}
      ${graphNode(839, 575, '#D7AA64', '?')}${graphNode(707, 644, '#319994', 'E')}
      ${label(565, 505, 'observation')}${label(727, 470, 'task')}
      ${label(841, 621, 'hypothesis')}${label(718, 688, 'evidence')}
    </g>

    <g data-subject-ref="${id('projection')}">
      ${txt(1035, 452, 'ASCENT / relate + explain', 24, '#244957', 700)}
      ${paper(1074, 485, '#8BA6B5', -5)}
      <circle cx="1201" cy="547" r="48" fill="#E1F2ED" fill-opacity=".88" stroke="#248C89" stroke-width="7"/>
      <path d="M1236 582L1271 618" stroke="#248C89" stroke-width="13" stroke-linecap="round"/>
      ${line('M1176 548L1201 523L1225 550M1201 523V569', '#489893')}
      <circle cx="1176" cy="548" r="5" fill="#489893"/><circle cx="1201" cy="523" r="5" fill="#489893"/><circle cx="1225" cy="550" r="5" fill="#C4A16B"/>
      ${label(1200, 666, 'Support / conflict / impact')}${label(1200, 696, 'Why? Why not? What changed?')}
    </g>
    ${arrow('M950 509H1057')}${label(1002, 489, 'facts')}
    ${arrow('M1053 608H946')}${label(1000, 640, 'relations')}

    ${arrow('M895 664C993 660 1023 744 1070 805')}${label(1024, 737, 'selected view')}
    ${arrow('M1063 928C975 916 965 813 860 761', '#8B81B4', true)}
    ${label(944, 849, 'new proposals', '#8177A4')}

    <g data-subject-ref="${id('longTerm')}">
      ${txt(70, 817, 'Long-term knowledge', 25, '#244957', 700)}
      ${books(83, 855)}
      ${label(235, 1051, 'Method + scope + counterexamples')}
    </g>
    ${arrow('M566 720C467 734 427 786 354 824', '#AD9869', true)}
    ${label(427, 775, 'scoped admission', '#94805B')}
    ${arrow('M373 937C446 942 457 830 545 798')}${label(460, 925, 'reuse + recheck')}

    <g data-subject-ref="${id('history')}">
      ${txt(705, 864, 'Real-world feedback', 25, '#244957', 700, 'middle')}
      <rect x="592" y="888" width="205" height="124" rx="13" fill="#304F60"/>
      <rect x="606" y="903" width="176" height="86" rx="5" fill="#E8F4EE"/>
      ${line('M628 923H702M628 942H682', '#90BDB0')}
      <path d="M713 951L730 965L758 928" fill="none" stroke="#319994" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M666 1012V1035H723V1012" fill="#8DABB3"/>
      <g transform="translate(805 928) scale(.62)">${paper(0, 0, '#D2A35F')}</g>
      ${label(711, 1081, 'Actual outcomes, not model confidence')}
    </g>
    ${arrow('M718 736V820')}${label(800, 790, 'permitted use')}
    ${arrow('M581 954C522 918 533 821 609 761')}${label(500, 858, 'receipts')}

    ${txt(1030, 797, 'LLM / explore freely', 25, '#244957', 700)}
    ${model(1137, 882)}
    ${label(1190, 1080, 'New hypotheses, tasks or methods.')}

    ${txt(54, 1167, 'An event-driven system, not a fixed sequence.', 23, '#244957', 700)}
    ${txt(871, 1167, 'Solid: data / relations    Dashed: proposals / revisit', 18, '#65818A')}
  </svg>`, css: '[data-vector-surface]{display:block;max-width:100%;height:auto}'};
};
