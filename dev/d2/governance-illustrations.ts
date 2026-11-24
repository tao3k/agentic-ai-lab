// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

// Illustrated, beginner-friendly visual explanations for Context System
// Governance, Temporal Causality memory quotients, and ORG S-expr x GQL search
// (Slices 40-45), rendered via @deterministic-engineering/render and OpenSysML.

import {readFile, mkdir, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {connect} from '@openmbee/opensysml';
import {chromium} from 'playwright';
import {composeFigure, type FigureComposer, type FigureInput} from '@deterministic-engineering/render';
import {captureOpenSysMLView, projectOpenSysMLView} from '@deterministic-engineering/render/opensysml';
import {exportFigure} from '@deterministic-engineering/render/export';
import {composePresentationTheme, presentationThemeLayers} from '@deterministic-engineering/render/presentation-theme';
import {illustrationAssets} from './illustration';

const directory = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(directory, '../..');
const contextDir = path.join(root, 'docs/10-19-design/10.06-poo-module-system/agentic-ai-context');

function drawingHelpers(context: Parameters<FigureComposer>[0]) {
  const base = illustrationAssets(context);
  const subjectId = (name: string) => {
    const matches = context.model!.subjects.filter(
      node => node.sourceName === name || node.sourceName?.endsWith('::' + name),
    );
    if (matches.length !== 1) throw new Error('Expected one OpenSysML subject named: ' + name);
    return context.text(matches[0]!.id);
  };
  const pill = (
    x: number,
    y: number,
    w: number,
    h: number,
    fill: string,
    stroke: string,
    text: string,
    textColor: string,
    size = 18,
  ) =>
    `<g><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${Math.round(h / 2)}" fill="${fill}" stroke="${stroke}" stroke-width="2.5"/>${base.txt(x + w / 2, y + h / 2 + 6, text, size, textColor, 700, 'middle')}</g>`;
  const character = (x: number, y: number, coat: string, badge: string, roleCaption?: string) => `<g transform="translate(${x} ${y})">
    <ellipse cx="36" cy="132" rx="64" ry="12" fill="#24495714"/>
    <path d="M-12 130Q-10 68 36 70Q82 68 86 130Z" fill="${coat}"/>
    <path d="M20 72L36 92L52 72" fill="#FAF7F0"/>
    <rect x="24" y="55" width="24" height="22" rx="8" fill="#EAC0A1"/>
    <ellipse cx="36" cy="28" rx="38" ry="41" fill="#F5D6B9"/>
    <path d="M-2 27Q-10-24 37-20Q80-18 74 28L62 9L50 3L12 8Z" fill="#29465B"/>
    <g fill="white" stroke="#29465B" stroke-width="2.8"><rect x="6" y="19" width="24" height="19" rx="7"/><rect x="42" y="19" width="24" height="19" rx="7"/><path d="M30 28H42"/></g>
    <circle cx="18" cy="28" r="2.8" fill="#29465B"/><circle cx="54" cy="28" r="2.8" fill="#29465B"/>
    <path d="M27 50Q36 58 45 50" fill="none" stroke="#B67863" stroke-width="2.8" stroke-linecap="round"/>
    ${base.txt(36, 116, badge, 17, '#FFFFFF', 700, 'middle')}
    ${roleCaption ? base.txt(36, 156, roleCaption, 17, '#244957', 700, 'middle') : ''}
  </g>`;
  const castle = (x: number, y: number, wallFill: string, wallStroke: string, name: string, flag: string) => `<g transform="translate(${x} ${y})">
    <path d="M88-40V8" stroke="${wallStroke}" stroke-width="3"/>
    <rect x="88" y="-40" width="72" height="26" rx="6" fill="${wallStroke}"/>
    ${base.txt(124, -22, flag, 16, '#FFFFFF', 700, 'middle')}
    <path d="M0 24V0H28V18H52V0H80V18H104V0H132V18H156V0H184V24V138Q184 150 172 150H12Q0 150 0 138Z" fill="${wallFill}" stroke="${wallStroke}" stroke-width="3"/>
    <path d="M68 150V98A24 24 0 0 1 116 98V150Z" fill="#FFFFFF" stroke="${wallStroke}" stroke-width="2.5"/>
    ${base.txt(92, 64, name, 21, '#244957', 700, 'middle')}
  </g>`;
  const shieldStop = (x: number, y: number) => `<g transform="translate(${x} ${y})">
    <path d="M0 10L34 0L68 10V42C68 68 34 86 34 86C34 86 0 68 0 42Z" fill="#FADBD8" stroke="#C0392B" stroke-width="3"/>
    <path d="M21 27L47 53M47 27L21 53" stroke="#C0392B" stroke-width="5" stroke-linecap="round"/>
  </g>`;
  const waxSeal = (x: number, y: number, color: string, title: string) => `<g transform="translate(${x} ${y})">
    <circle cx="0" cy="0" r="36" fill="${color}" stroke="#FFFFFF" stroke-width="3"/>
    <circle cx="0" cy="0" r="29" fill="none" stroke="#FFFFFF99" stroke-width="1.8" stroke-dasharray="4 3"/>
    ${base.txt(0, 6, title, 16, '#FFFFFF', 700, 'middle')}
  </g>`;
  const roundTag = (x: number, y: number, r: number, stroke: string, label: string) => `<g>
    <circle cx="${x}" cy="${y}" r="${r}" fill="#FFFFFF" stroke="${stroke}" stroke-width="3"/>
    ${base.txt(x, y + 6, label, 17, stroke, 700, 'middle')}
  </g>`;
  return {...base, subjectId, pill, character, castle, shieldStop, waxSeal, roundTag};
}

// 1. Slice 42 & 40: Cross-Repo Multi-Agent Sharing & Controlled Declassification
const composeDeclassificationStory: FigureComposer = context => {
  const {txt, line, arrow, paper, subjectId, pill, character, castle, shieldStop, waxSeal} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1520" height="1140" viewBox="0 0 1520 1140" role="img" aria-label="Sharing across two repositories without spilling secrets">
      <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
      <rect width="1520" height="1140" fill="#FAFCFA"/>
      ${txt(46, 58, 'Two Castles, Two Keys: Share the Safe Lesson, Never Spill the Secret!', 34, '#244957', 700)}
      ${txt(48, 98, 'A helper in Repo-SDK cannot borrow Repo-Core secrets through a coordinator whisper.', 22, '#567781')}

      <rect x="36" y="128" width="1448" height="314" rx="26" fill="#FDF3F2" stroke="#E6B0AA" stroke-width="2.5"/>
      ${pill(64, 148, 520, 40, '#FADBD8', '#C0392B', 'X  Wrong Way: Confused-Deputy Whisper', '#922B21', 19)}
      ${castle(88, 248, '#E8EEF5', '#5D7B93', 'Repo-Core', 'cut c1')}
      ${paper(302, 248, '#C0392B', -6)}
      ${txt(355, 408, 'Raw secret + rule', 18, '#922B21', 700, 'middle')}
      ${character(468, 244, '#547A96', 'Coord')}
      ${arrow('M418 314H456', '#C0392B')}
      ${arrow('M574 314H746', '#C0392B', true)}
      ${txt(660, 292, 'copies into prompt', 18, '#922B21', 700, 'middle')}
      ${shieldStop(772, 270)}
      ${txt(806, 384, 'BLOCKED!', 20, '#C0392B', 700, 'middle')}
      ${txt(806, 410, 'No SDK grant on Core', 17, '#922B21', 400, 'middle')}
      ${arrow('M864 314H1018', '#D5A6A0', true)}
      ${character(1050, 244, '#CA7B5C', 'SDK', 'SDK Helper')}
      ${castle(1218, 248, '#F6EFE6', '#B0895A', 'Repo-SDK', 'cut s1')}

      <rect x="36" y="468" width="1448" height="596" rx="28" fill="#EEF7F5" stroke="#B6D8D2" stroke-width="2.5"/>
      ${pill(64, 492, 690, 42, '#D8EFE3', '#1E8268', '✓  Governed Way: Snip the Secret + Three Distinct Stamps + Cut Tether', '#145A48', 19)}

      <g data-subject-ref="${subjectId('coordinator')}">
        ${castle(84, 612, '#DCEBF2', '#3B6E8C', 'Repo-Core', 'cut c1')}
        ${character(292, 616, '#3B6E8C', 'Coord', 'Proposer')}
        ${txt(176, 806, '1. Verified Git binding', 19, '#244957', 700, 'middle')}
        ${txt(176, 834, 'Keeps warning pin D1!', 18, '#567781', 400, 'middle')}
      </g>

      ${arrow('M400 688H482', '#198D87')}
      ${txt(441, 668, 'propose', 18, '#198D87', 700, 'middle')}

      <g data-subject-ref="${subjectId('governanceGate')}">
        <rect x="496" y="560" width="516" height="344" rx="24" fill="#FFFFFF" stroke="#76B5AE" stroke-width="2.5"/>
        ${txt(754, 600, '2. Redaction Scissors & Three-Stamp Gate', 23, '#244957', 700, 'middle')}
        <rect x="526" y="628" width="182" height="54" rx="10" fill="#FADBD8" stroke="#C0392B" stroke-width="2" stroke-dasharray="6 4"/>
        ${txt(617, 661, 'Exploit bytes snipped', 17, '#922B21', 700, 'middle')}
        <circle cx="734" cy="644" r="11" fill="none" stroke="#B7791F" stroke-width="3.5"/>
        <circle cx="734" cy="668" r="11" fill="none" stroke="#B7791F" stroke-width="3.5"/>
        <path d="M744 649L784 669M744 663L784 643" stroke="#B7791F" stroke-width="4" stroke-linecap="round"/>
        <rect x="798" y="624" width="186" height="64" rx="12" fill="#D8EFE3" stroke="#1E8268" stroke-width="2.5"/>
        ${txt(891, 651, 'Safe Public Card', 18, '#145A48', 700, 'middle')}
        ${txt(891, 676, '+ Warning Pin D1', 16, '#8A6835', 700, 'middle')}

        ${waxSeal(596, 766, '#3B6E8C', '1. Coord')}
        ${waxSeal(754, 766, '#1E8268', '2. Officer')}
        ${waxSeal(912, 766, '#CA7B5C', '3. SDK')}
        ${txt(754, 838, 'Three different people/roles (No self-stamping!)', 18, '#244957', 700, 'middle')}
        ${txt(754, 868, 'Certificate binds ONLY the safe card digest at cut c1', 17, '#567781', 400, 'middle')}
      </g>

      ${arrow('M1024 688H1112', '#198D87')}
      ${txt(1068, 668, 'safe card', 18, '#198D87', 700, 'middle')}

      <g data-subject-ref="${subjectId('subagent')}">
        ${character(1134, 616, '#CA7B5C', 'SDK', 'Recipient')}
        ${castle(1262, 612, '#F5EBDC', '#A67C46', 'Repo-SDK', 'cut s1')}
        ${txt(1354, 806, '3. Uses only safe card', 19, '#244957', 700, 'middle')}
        ${txt(1354, 834, 'Trust rank never grows!', 18, '#567781', 400, 'middle')}
      </g>

      ${line('M184 862C360 1002 1060 1002 1240 862', '#248784', true)}
      ${pill(525, 956, 470, 42, '#FFF8E7', '#C8963E', 'Live Tether: if Repo-Core moves c1 -> c2, card retires!', '#7C5416', 17)}

      ${txt(48, 1106, 'Rule to remember: Sharing a project never shares secret keys. Only snipped & 3-way stamped cards cross castles.', 21, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// 2. Slice 43 & 41: Three Mystery Doors & OmittedAlternativesReceipt
const composeSecurityBranchesStory: FigureComposer = context => {
  const {txt, arrow, model, subjectId, pill} = drawingHelpers(context);
  const door = (
    x: number,
    y: number,
    fill: string,
    stroke: string,
    title: string,
    sub1: string,
    foot1: string,
    foot2: string,
  ) => `<g transform="translate(${x} ${y})">
    <rect x="0" y="0" width="224" height="284" rx="18" fill="${fill}" stroke="${stroke}" stroke-width="3"/>
    <rect x="16" y="20" width="192" height="94" rx="10" fill="#FFFFFFCC" stroke="${stroke}" stroke-width="2"/>
    <circle cx="192" cy="156" r="8" fill="${stroke}"/>
    ${txt(112, 58, title, 20, '#244957', 700, 'middle')}
    ${txt(112, 88, sub1, 17, '#567781', 400, 'middle')}
    ${txt(112, 224, foot1, 17, '#244957', 700, 'middle')}
    ${txt(112, 250, foot2, 16, '#567781', 400, 'middle')}
  </g>`;

  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1520" height="1140" viewBox="0 0 1520 1140" role="img" aria-label="Three mystery doors under OmittedAlternativesReceipt">
      <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
      <rect width="1520" height="1140" fill="#FAFCFA"/>
      ${txt(46, 58, 'Three Mystery Doors: Peek with a Flashlight, Never Swing a Blind Hammer!', 33, '#244957', 700)}
      ${txt(48, 98, 'When our backpack is too small to carry Door 3, an Omitted Receipt stops risky guesswork.', 22, '#567781')}

      <rect x="34" y="130" width="1452" height="926" rx="28" fill="#EEF7F5" stroke="#B8D8D2" stroke-width="2.5"/>

      <g data-subject-ref="${subjectId('inferencePlane')}">
        ${txt(62, 180, '1. ASCENT keeps every live suspect on the board (plus warnings!)', 24, '#168383', 700)}
        ${door(60, 216, '#E4F1EE', '#2E8B84', 'Door H1: CI Key', '1 clue missing', 'Warning Pin D1', 'stays glued on!')}
        <polygon points="172,334 150,374 194,374" fill="#F9E79F" stroke="#B7791F" stroke-width="2.5"/>
        ${txt(172, 369, '!', 20, '#7D5311', 700, 'middle')}

        ${door(306, 216, '#EAE8F7', '#766DA8', 'Door H2: Webhook', '3 clues missing', '"Fits the story"', 'is NOT real proof!')}
        ${pill(322, 338, 192, 34, '#FFF8E7', '#C8963E', 'No counting shortcuts!', '#7C5416', 15)}

        <g transform="translate(552 216)">
          <rect x="0" y="0" width="224" height="284" rx="18" fill="#F3EAF8" stroke="#8E6BB0" stroke-width="3" stroke-dasharray="8 6"/>
          <path d="M10 12H214V192Q162 170 112 192Q62 214 10 188Z" fill="#9B7BB8" opacity=".88"/>
          ${txt(112, 76, 'Door H3: Canary', 21, '#FFFFFF', 700, 'middle')}
          ${txt(112, 108, '(Healthy rollout?)', 18, '#F6EEFC', 400, 'middle')}
          <rect x="18" y="210" width="188" height="54" rx="10" fill="#FFF3CD" stroke="#B7791F" stroke-width="2.5"/>
          ${txt(112, 234, 'Omitted Receipt', 18, '#7C5416', 700, 'middle')}
          ${txt(112, 255, 'Curtained by budget!', 15, '#7C5416', 400, 'middle')}
        </g>

        ${model(210, 680)}
        ${txt(248, 868, 'Investigator LLM proposes two tools to try', 21, '#244957', 700, 'middle')}
        ${txt(248, 898, 'Every tool is checked against the doors!', 18, '#567781', 400, 'middle')}
      </g>

      ${arrow('M794 360H876', '#198D87')}
      ${arrow('M420 740H876', '#766DA8', true)}
      ${txt(648, 718, 'proposed branches B1 & B2', 19, '#5B538A', 700, 'middle')}

      <g data-subject-ref="${subjectId('governanceGate')}">
        <rect x="892" y="196" width="560" height="360" rx="24" fill="#FFFFFF" stroke="#2E8B84" stroke-width="3"/>
        ${pill(922, 220, 500, 42, '#D8EFE3', '#1E8268', '✓  Branch B1: Safe Flashlight (Read Audit Logs)', '#145A48', 19)}
        <g transform="translate(928 308)">
          <rect x="0" y="18" width="78" height="32" rx="10" fill="#3B8D88"/>
          <polygon points="78,18 110,4 110,64 78,50" fill="#76C4AE"/>
          <polygon points="110,8 184,-16 184,84 110,60" fill="#FFF9C4" opacity=".85"/>
        </g>
        ${txt(1134, 326, 'Shines light on H1 & H2,', 20, '#244957', 700)}
        ${txt(1134, 358, 'and helps uncover Door H3!', 20, '#244957', 700)}
        ${txt(1172, 426, 'Harms nothing if Canary H3 is innocent.', 19, '#145A48', 700, 'middle')}
        ${pill(1032, 464, 280, 40, '#E1F3EC', '#1E8268', 'ALLOWED (with read grant)', '#145A48', 18)}

        <rect x="892" y="596" width="560" height="386" rx="24" fill="#FFF8F7" stroke="#C0392B" stroke-width="3"/>
        ${pill(922, 620, 500, 42, '#FADBD8', '#C0392B', 'X  Branch B2: Big Hammer (Shut Down Prod Webhook)', '#922B21', 18)}
        <g transform="translate(932 718)">
          <rect x="0" y="34" width="96" height="15" rx="6" fill="#8D6E63" transform="rotate(-24 48 42)"/>
          <rect x="66" y="-8" width="48" height="68" rx="10" fill="#7F8C8D" stroke="#2C3E50" stroke-width="3" transform="rotate(-24 90 26)"/>
          <rect x="124" y="22" width="60" height="52" rx="10" fill="#FADBD8" stroke="#C0392B" stroke-width="3"/>
          <path d="M138 22V9A16 16 0 0 1 170 9V22" fill="none" stroke="#C0392B" stroke-width="4"/>
        </g>
        ${txt(1134, 736, 'Wait! Door H3 is curtained!', 20, '#922B21', 700)}
        ${txt(1134, 768, 'If H3 is a healthy canary,', 19, '#567781', 400)}
        ${txt(1134, 798, 'the hammer breaks prod!', 19, '#922B21', 700)}
        ${pill(972, 882, 400, 44, '#FADBD8', '#C0392B', 'LOCKED by OmittedAlternativesReceipt', '#922B21', 18)}
      </g>

      ${txt(48, 1104, 'Golden Rule: Never guess from fewer missing clues, and never swing a wrecking hammer while a door is curtained.', 21, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// 3. Slice 44: Temporal Causality & Memory as an Audited Anti-Entropy Quotient
const composeCausalSurvivalStory: FigureComposer = context => {
  const {txt, line, arrow, paper, model, subjectId, pill} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1520" height="1160" viewBox="0 0 1520 1160" role="img" aria-label="Memory as audited temporal quotient governed by Temporal Causality">
      <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
      <rect width="1520" height="1160" fill="#FAFCFA"/>
      ${txt(46, 58, 'Memory Is Not Hoarding Messy Boxes — Keep Only What Still Lives in Time!', 33, '#244957', 700)}
      ${txt(48, 98, 'Unchecked notes turn into heavy clutter. Temporal Causality keeps memory light, truthful, and self-cleaning.', 22, '#567781')}

      <g data-subject-ref="${subjectId('journalPlane')}">
        <rect x="36" y="128" width="1448" height="214" rx="24" fill="#EAF4F8" stroke="#9AC2D4" stroke-width="2.5"/>
        ${txt(66, 168, '1. Bitemporal Clocks & Watermark Tank (Journal & Clock Owner)', 23, '#235E7A', 700)}
        <circle cx="118" cy="248" r="44" fill="#FFFFFF" stroke="#3B7A9E" stroke-width="3.5"/>
        ${line('M118 248V218M118 248L142 260', '#3B7A9E')}
        ${txt(118, 316, 'World Time v', 18, '#244957', 700, 'middle')}

        <circle cx="254" cy="248" r="44" fill="#FFFFFF" stroke="#2E8B84" stroke-width="3.5"/>
        ${line('M254 248V220M254 248L276 236', '#2E8B84')}
        ${txt(254, 316, 'Known Cut a', 18, '#244957', 700, 'middle')}

        <g transform="translate(410 186)">
          <rect x="0" y="0" width="330" height="126" rx="16" fill="#FFFFFF" stroke="#3B7A9E" stroke-width="3"/>
          <rect x="4" y="54" width="322" height="68" rx="12" fill="#BDE3F2"/>
          ${line('M8 32H322', '#C0392B', true)}
          ${txt(165, 25, 'Required Cut Watermark Line', 16, '#C0392B', 700, 'middle')}
          <ellipse cx="92" cy="52" rx="20" ry="13" fill="#FFD54F" stroke="#B7791F" stroke-width="2"/>
          <circle cx="106" cy="40" r="10" fill="#FFD54F" stroke="#B7791F" stroke-width="2"/>
          ${txt(214, 94, 'Water below line = Wait!', 18, '#1B4F72', 700, 'middle')}
        </g>
        ${txt(1115, 224, 'Why-Not Rule: Never memorize "Zero errors happened!"', 20, '#244957', 700, 'middle')}
        ${txt(1115, 258, 'while late logs are still swimming below the watermark line!', 19, '#567781', 400, 'middle')}
        ${pill(915, 278, 400, 38, '#FFF8E7', '#C8963E', 'Past cuts P(J, a1, v) stay frozen in museum!', '#7C5416', 17)}
      </g>

      <rect x="36" y="370" width="1448" height="702" rx="28" fill="#EEF7F5" stroke="#B6D8D2" stroke-width="2.5"/>

      <g data-subject-ref="${subjectId('proposerPlane')}">
        ${txt(68, 418, '2. Squeeze 10 Messy Notes into 1 Candidate Gem', 23, '#244957', 700)}
        ${paper(76, 456, '#B0BEC5', -18)}${paper(132, 446, '#D7CCC8', 14)}${paper(104, 492, '#CFD8DC', -4)}
        ${txt(156, 666, '10 noisy trial notes', 19, '#607D8B', 700, 'middle')}
        ${txt(156, 694, '(Heavy prompt clutter!)', 17, '#922B21', 700, 'middle')}
        ${arrow('M258 552H334', '#766DA8')}
        ${model(364, 488)}
        ${txt(402, 678, 'ASCENT + LLM propose', 19, '#244957', 700, 'middle')}
        ${txt(402, 704, 'a smaller quotient gem', 18, '#567781', 400, 'middle')}

        <g transform="translate(64 762)">
          <rect x="0" y="0" width="498" height="176" rx="24" fill="#FFFFFF" stroke="#90B8B2" stroke-width="2.2" stroke-dasharray="7 5"/>
          ${txt(249, 54, 'Searched 30 leaves, cited ONLY 2!', 20, '#168383', 700, 'middle')}
          ${txt(249, 94, '28 unused leaves = ZERO upkeep burden!', 18, '#244957', 700, 'middle')}
          ${txt(249, 132, '(Changing unused leaves never breaks our gem)', 17, '#567781', 400, 'middle')}
        </g>
      </g>

      ${arrow('M512 566H606', '#766DA8', true)}
      ${txt(559, 544, 'check me!', 18, '#5B538A', 700, 'middle')}

      <g data-subject-ref="${subjectId('temporalSpine')}">
        <rect x="622" y="420" width="468" height="598" rx="24" fill="#FFFFFF" stroke="#248784" stroke-width="3"/>
        ${txt(856, 464, '3. Temporal Causality Survival Check', 24, '#168383', 700, 'middle')}

        ${pill(656, 492, 400, 42, '#E1F3EC', '#1E8268', 'Gate A: Smaller than raw notes + keeps D1!', '#145A48', 17)}
        ${pill(656, 550, 400, 42, '#E1F3EC', '#1E8268', 'Gate B: All cited roots active (not conflicted)', '#145A48', 17)}
        ${pill(656, 608, 400, 42, '#E1F3EC', '#1E8268', 'Gate C: Auto-evict Audit Hook attached!', '#145A48', 17)}

        <g transform="translate(652 680)">
          <rect x="0" y="0" width="408" height="206" rx="16" fill="#F8FBFD" stroke="#8FB8CA" stroke-width="2"/>
          ${txt(204, 34, 'Gate D: ImpactScope Balance Scale', 19, '#244957', 700, 'middle')}
          ${line('M114 108H294M204 62V156M164 156H244', '#3B7A9E')}
          <circle cx="120" cy="128" r="24" fill="#D8EFE3" stroke="#1E8268" stroke-width="2.5"/>
          ${txt(120, 134, 'T', 20, '#145A48', 700, 'middle')}
          <circle cx="288" cy="128" r="24" fill="#FFF3CD" stroke="#B7791F" stroke-width="2.5"/>
          ${txt(288, 134, 'P', 20, '#7C5416', 700, 'middle')}
          ${txt(204, 186, 'Target T improved & Protected P unharmed!', 17, '#244957', 700, 'middle')}
        </g>

        ${txt(856, 940, 'No Audit Hook = No Retention!', 20, '#922B21', 700, 'middle')}
        ${txt(856, 972, 'Never hoard a memory you cannot auto-clean.', 18, '#567781', 400, 'middle')}
      </g>

      ${arrow('M1104 560H1186', '#1E8268')}
      ${arrow('M1104 830H1186', '#7F8C8D', true)}

      <g transform="translate(1200 448)">
        <rect x="0" y="0" width="256" height="248" rx="22" fill="#D8EFE3" stroke="#1E8268" stroke-width="3"/>
        <polygon points="128,36 178,86 154,148 102,148 78,86" fill="#48C9B0" stroke="#145A48" stroke-width="3"/>
        ${txt(128, 188, 'Surviving Gem!', 22, '#145A48', 700, 'middle')}
        ${txt(128, 218, 'Light, live & tethered', 18, '#145A48', 400, 'middle')}
      </g>

      <g transform="translate(1200 742)">
        <rect x="0" y="0" width="256" height="260" rx="22" fill="#F2F4F6" stroke="#7F8C8D" stroke-width="2.5" stroke-dasharray="7 5"/>
        <rect x="78" y="38" width="100" height="106" rx="16" fill="#FFFFFF" stroke="#95A5A6" stroke-width="3"/>
        <rect x="92" y="26" width="72" height="14" rx="5" fill="#7F8C8D"/>
        ${txt(128, 98, 'Old Cut', 18, '#566573', 700, 'middle')}
        ${txt(128, 186, 'Cold Museum Jar', 21, '#2C3E50', 700, 'middle')}
        ${txt(128, 214, 'Kept for audit replay;', 17, '#566573', 400, 'middle')}
        ${txt(128, 238, 'ZERO prompt burden!', 17, '#1E8268', 700, 'middle')}
      </g>

      ${txt(48, 1122, 'Takeaway: Memory is a living survival crystal, not an ever-growing attic of unverified dusty boxes.', 22, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// 4. Slice 45: ORG Element (S-Expr Magnifier) x GQL Yarn Map x Twin-Ticket Gate
const composeHybridSearchStory: FigureComposer = context => {
  const {txt, line, arrow, subjectId, pill, roundTag} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1520" height="1140" viewBox="0 0 1520 1140" role="img" aria-label="ORG Element S-expression selector, GQL relationship map, and CandidateExchange turnstile">
      <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
      <rect width="1520" height="1140" fill="#FAFCFA"/>
      ${txt(46, 58, 'Tree Magnifier + Yarn Map + Twin-Ticket Gate: How Smart Search Works!', 33, '#244957', 700)}
      ${txt(48, 98, 'S-expressions pick real ORG apples, GQL follows yarn inside the fence, and matching tickets enter Temporal Causality.', 21, '#567781')}

      <rect x="34" y="132" width="1452" height="920" rx="28" fill="#EEF7F5" stroke="#B6D8D2" stroke-width="2.5"/>

      <g data-subject-ref="${subjectId('sexprEngine')}">
        <rect x="62" y="168" width="424" height="842" rx="24" fill="#FFFFFF" stroke="#6BA89E" stroke-width="2.5"/>
        ${txt(274, 214, '1. ORG Tree + S-Expr Magnifier', 24, '#244957', 700, 'middle')}
        ${pill(94, 234, 360, 38, '#E1F3EC', '#1E8268', '(org-elements (descendant-of root))', '#145A48', 17)}

        <path d="M254 570V430" stroke="#8D6E63" stroke-width="18" stroke-linecap="round"/>
        <circle cx="254" cy="378" r="108" fill="#C8E6C9" stroke="#388E3C" stroke-width="3"/>
        <circle cx="196" cy="350" r="26" fill="#FF8A65" stroke="#BF360C" stroke-width="2.5"/>
        ${txt(196, 356, 'Tbl', 16, '#FFFFFF', 700, 'middle')}
        <circle cx="308" cy="346" r="26" fill="#4DB6AC" stroke="#00695C" stroke-width="2.5"/>
        ${txt(308, 352, 'Note', 15, '#FFFFFF', 700, 'middle')}
        <circle cx="254" cy="424" r="26" fill="#7986CB" stroke="#283593" stroke-width="2.5"/>
        ${txt(254, 430, 'Link', 15, '#FFFFFF', 700, 'middle')}

        <circle cx="352" cy="458" r="42" fill="#E0F7FA" fill-opacity=".82" stroke="#00838F" stroke-width="7"/>
        <path d="M382 488L420 526" stroke="#00838F" stroke-width="13" stroke-linecap="round"/>
        ${txt(274, 626, 'Exact UTF-8 byte ruler [start, end)', 19, '#244957', 700, 'middle')}

        <rect x="92" y="676" width="364" height="292" rx="18" fill="#FDF3F2" stroke="#C0392B" stroke-width="2.5" stroke-dasharray="7 5"/>
        ${txt(274, 716, 'Code-Block Cage (#+begin_src)', 20, '#922B21', 700, 'middle')}
        <rect x="134" y="742" width="280" height="108" rx="12" fill="#FFFFFF" stroke="#C0392B" stroke-width="2"/>
        ${line('M168 742V850M220 742V850M274 742V850M328 742V850M380 742V850', '#E6B0AA')}
        <rect x="148" y="778" width="252" height="36" rx="8" fill="#FFF8F7"/>
        ${txt(274, 802, 'Sneaky Fake :ID: inside code', 17, '#922B21', 700, 'middle')}
        ${txt(274, 902, 'S-Expr AST knows it is just code text!', 18, '#244957', 700, 'middle')}
        ${txt(274, 934, 'Fake IDs NEVER escape the cage.', 18, '#922B21', 700, 'middle')}
      </g>

      ${arrow('M498 468H546', '#198D87')}

      <g data-subject-ref="${subjectId('gqlEngine')}">
        <rect x="558" y="168" width="436" height="842" rx="24" fill="#FFFFFF" stroke="#5D8AA8" stroke-width="2.5"/>
        ${txt(776, 214, '2. Fenced Garden + GQL Yarn Map', 24, '#244957', 700, 'middle')}
        ${pill(596, 234, 360, 38, '#E6F0F8', '#3B6E8C', 'MATCH (a)-[r:defeats|supports]->(b)', '#1F4E68', 17)}

        <rect x="586" y="302" width="380" height="392" rx="22" fill="#F6FBF9" stroke="#2E8B84" stroke-width="3" stroke-dasharray="10 6"/>
        ${txt(776, 338, 'Admitted ElementSpace Fence', 19, '#168383', 700, 'middle')}

        ${line('M668 430L874 422', '#1E8268')}
        ${txt(770, 406, ':supports', 18, '#1E8268', 700, 'middle')}
        ${line('M874 422L768 574', '#C0392B', true)}
        ${txt(866, 514, ':defeats', 18, '#C0392B', 700, 'middle')}
        ${line('M668 430L768 574', '#5B6196')}
        ${txt(672, 522, ':links-to', 18, '#5B6196', 700, 'middle')}

        ${roundTag(668, 430, 30, '#D85A32', 'Tbl')}
        ${roundTag(874, 422, 30, '#1E8268', 'Note')}
        ${roundTag(768, 574, 30, '#4E5BA6', 'Link')}
        ${txt(776, 662, 'Bounded steps & rows (no loops!)', 17, '#244957', 700, 'middle')}

        <rect x="586" y="728" width="380" height="240" rx="18" fill="#FFF9EB" stroke="#C8963E" stroke-width="2.5"/>
        ${txt(776, 768, 'LLM Can Suggest New Yarn Threads!', 19, '#7C5416', 700, 'middle')}
        ${txt(776, 812, '1. Both apples must live inside the fence', 18, '#244957', 400, 'middle')}
        ${txt(776, 848, '2. Reader key must be active', 18, '#244957', 400, 'middle')}
        ${txt(776, 884, '3. Trust rank never climbs upward', 18, '#244957', 400, 'middle')}
        ${pill(636, 908, 280, 38, '#FADBD8', '#C0392B', 'Fence escape = Fail-Closed!', '#922B21', 17)}
      </g>

      ${arrow('M1006 468H1054', '#198D87')}

      <g data-subject-ref="${subjectId('exchangeGate')}">
        <rect x="1066" y="168" width="392" height="842" rx="24" fill="#FFFFFF" stroke="#766DA8" stroke-width="2.5"/>
        ${txt(1262, 214, '3. Twin-Ticket Turnstile', 24, '#244957', 700, 'middle')}
        ${txt(1262, 248, '(CandidateExchange Gate)', 19, '#5B538A', 700, 'middle')}

        <rect x="1104" y="290" width="316" height="114" rx="16" fill="#E1F3EC" stroke="#1E8268" stroke-width="3"/>
        ${txt(1262, 336, 'Ticket 1: GQL Path Receipt', 20, '#145A48', 700, 'middle')}
        ${txt(1262, 374, 'Generation 2  •  Complete ✓', 19, '#145A48', 700, 'middle')}

        <rect x="1104" y="432" width="316" height="114" rx="16" fill="#FFF8E7" stroke="#B7791F" stroke-width="3"/>
        ${txt(1262, 478, 'Ticket 2: ASCENT Receipt', 20, '#7C5416', 700, 'middle')}
        ${txt(1262, 516, 'Generation 2  •  Complete ✓', 19, '#7C5416', 700, 'middle')}

        ${arrow('M1262 554V650', '#1E8268')}
        ${pill(1132, 580, 260, 36, '#FFFFFF', '#1E8268', 'Both Gen 2 + Complete!', '#145A48', 17)}

        <rect x="1104" y="662" width="316" height="154" rx="20" fill="#DCEBF2" stroke="#285E8E" stroke-width="3"/>
        ${txt(1262, 716, 'Temporal Causality', 24, '#1B4F72', 700, 'middle')}
        ${txt(1262, 754, 'Admits clean, synchronized', 18, '#244957', 400, 'middle')}
        ${txt(1262, 784, 'facts with 3-hash replay!', 18, '#1B4F72', 700, 'middle')}

        <rect x="1104" y="848" width="316" height="122" rx="16" fill="#FDF3F2" stroke="#C0392B" stroke-width="2"/>
        ${txt(1262, 892, 'Gen 1 + Gen 2 mismatch?', 19, '#922B21', 700, 'middle')}
        ${txt(1262, 926, 'Turnstile resets cleanly —', 17, '#567781', 400, 'middle')}
        ${txt(1262, 952, 'never mix half-old & half-new!', 17, '#922B21', 700, 'middle')}
      </g>

      ${txt(48, 1104, 'Result: Structure-exact search + explicit relationships + zero half-stale tears — replayable without re-running the LLM!', 21, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// 5. Slice 46: Alarm Clock != Permission, Crash Scout, & Breaking the Dangerous Triangle
const composeSandboxTrifectaStory: FigureComposer = context => {
  const {txt, line, arrow, paper, books, subjectId, pill, shieldStop} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1520" height="1140" viewBox="0 0 1520 1140" role="img" aria-label="Durable Agenda wake, crash reconciliation, and Sandbox Lethal Trifecta lock">
      <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
      <rect width="1520" height="1140" fill="#FAFCFA"/>
      ${txt(46, 58, 'Alarm Clocks Are Not Permission Slips — And Lock the Carrier Pigeon!', 33, '#244957', 700)}
      ${txt(48, 98, 'Agenda wakes recheck permission, crashes inspect before retrying, and Sandboxes break the Lethal Trifecta.', 21, '#567781')}

      <rect x="34" y="132" width="1452" height="920" rx="28" fill="#EEF7F5" stroke="#B6D8D2" stroke-width="2.5"/>

      <g data-subject-ref="${subjectId('agendaPlane')}">
        <rect x="64" y="168" width="560" height="394" rx="24" fill="#FFFFFF" stroke="#5D8AA8" stroke-width="2.5"/>
        ${txt(344, 214, '1. ORG Agenda Alarm Clock', 24, '#244957', 700, 'middle')}
        <circle cx="176" cy="340" r="64" fill="#FFF8E7" stroke="#B7791F" stroke-width="4"/>
        <circle cx="132" cy="272" r="20" fill="#F9E79F" stroke="#B7791F" stroke-width="3"/>
        <circle cx="220" cy="272" r="20" fill="#F9E79F" stroke="#B7791F" stroke-width="3"/>
        ${line('M176 340V300M176 340L208 356', '#7C5416')}
        ${txt(176, 434, '17:45 Ring!', 19, '#7C5416', 700, 'middle')}

        ${txt(426, 304, 'Ringing only says:', 20, '#244957', 700, 'middle')}
        ${txt(426, 336, '"Time to wake up & check!"', 19, '#168383', 700, 'middle')}
        ${txt(426, 382, 'Overdue TODO != Send grant.', 18, '#922B21', 700, 'middle')}
        ${txt(426, 412, 'Must recheck live cut & grant!', 18, '#567781', 400, 'middle')}
        ${pill(134, 486, 420, 42, '#E6F0F8', '#3B6E8C', 'Wake Carries ZERO Execution Authority', '#1F4E68', 18)}
      </g>

      ${arrow('M344 574V618', '#198D87')}

      <g data-subject-ref="${subjectId('sessionPlane')}">
        <rect x="64" y="630" width="560" height="384" rx="24" fill="#FFFFFF" stroke="#766DA8" stroke-width="2.5"/>
        ${txt(344, 676, '2. Foggy Crash? Send a Scout First!', 24, '#244957', 700, 'middle')}
        <ellipse cx="186" cy="792" rx="88" ry="48" fill="#E5E8EB" stroke="#7F8C8D" stroke-width="2.5" stroke-dasharray="6 4"/>
        ${txt(186, 788, 'Crash!', 20, '#2C3E50', 700, 'middle')}
        ${txt(186, 814, 'Receipt missing', 16, '#566573', 400, 'middle')}

        ${txt(432, 746, 'X  Never fire twice blindly!', 19, '#922B21', 700, 'middle')}
        ${txt(432, 784, '✓  1. Read-only scout checks', 19, '#145A48', 700, 'middle')}
        ${txt(432, 814, '✓  2. Retry only on confirmed', 18, '#244957', 400, 'middle')}
        ${txt(432, 842, 'no-send with fresh Attempt Gen 2', 18, '#244957', 400, 'middle')}
        ${pill(124, 932, 440, 42, '#EAE8F7', '#5B538A', 'Independent Session Owns Attempt Gen', '#3F376B', 18)}
      </g>

      <g data-subject-ref="${subjectId('contextRequestor')}">
        ${arrow('M642 360H698', '#198D87')}
      </g>

      <g data-subject-ref="${subjectId('sandboxGate')}">
        <rect x="712" y="168" width="742" height="846" rx="24" fill="#FFFFFF" stroke="#2E8B84" stroke-width="3"/>
        ${txt(1083, 216, '3. Sandbox Gate Breaks the "Lethal Trifecta"!', 25, '#168383', 700, 'middle')}
        ${txt(1083, 250, 'Effective Sandbox = Context Allowed Caps ∩ Profile Allowed Caps', 18, '#567781', 400, 'middle')}

        <polygon points="1083,320 848,680 1318,680" fill="#FDF3F2" stroke="#E6B0AA" stroke-width="3" stroke-dasharray="9 6"/>
        ${txt(1083, 536, 'DANGEROUS', 21, '#922B21', 700, 'middle')}
        ${txt(1083, 564, 'TRIANGLE', 21, '#922B21', 700, 'middle')}

        <g transform="translate(1030 278)">
          ${paper(0, 0, '#C0392B', -4)}
          ${pill(-58, 142, 224, 36, '#FADBD8', '#C0392B', '1. Untrusted Outside Input', '#922B21', 16)}
        </g>

        <g transform="translate(744 636)">
          <g transform="scale(.78)">${books(0, 0)}</g>
          ${pill(-10, 134, 224, 36, '#E6F0F8', '#285E8E', '2. Private Vault Secrets', '#1B4F72', 16)}
        </g>

        <g transform="translate(1196 626)">
          <rect x="20" y="0" width="156" height="122" rx="16" fill="#FFF8E7" stroke="#B7791F" stroke-width="3"/>
          ${line('M52 0V122M98 0V122M144 0V122', '#D4AC6E')}
          <ellipse cx="98" cy="68" rx="30" ry="20" fill="#90CAF9" stroke="#1F618D" stroke-width="2.5"/>
          <circle cx="122" cy="54" r="12" fill="#90CAF9" stroke="#1F618D" stroke-width="2.5"/>
          ${shieldStop(146, 20)}
          ${pill(-18, 144, 248, 36, '#D8EFE3', '#1E8268', '3. Outbound Pigeon LOCKED!', '#145A48', 16)}
        </g>

        <rect x="768" y="838" width="630" height="136" rx="18" fill="#E1F3EC" stroke="#1E8268" stroke-width="2.5"/>
        ${txt(1083, 880, 'Trifecta Law: If Backpack has (1) Untrusted + (2) Private Data,', 20, '#145A48', 700, 'middle')}
        ${txt(1083, 914, 'Sandbox MUST lock (3) External Network Egress = OFF', 20, '#244957', 700, 'middle')}
        ${txt(1083, 948, '(unless an independent Egress Endorsement Certificate is stamped!)', 17, '#567781', 400, 'middle')}
      </g>

      ${txt(48, 1104, 'Three Control Axes in Harmony: Agenda wakes gently, Session guards retries, and Sandbox locks secret leaks.', 21, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// 6. Slice 47: Six-Station Railway & Deterministic Zero-LLM Audit Time-Capsule
const composeEndToEndPipelineStory: FigureComposer = context => {
  const {txt, line, arrow, subjectId, pill} = drawingHelpers(context);
  const station = (
    x: number,
    y: number,
    w: number,
    fill: string,
    stroke: string,
    num: string,
    title: string,
    sub1: string,
    sub2: string,
    sliceTag: string,
  ) => `<g transform="translate(${x} ${y})">
    <rect x="0" y="0" width="${w}" height="320" rx="22" fill="${fill}" stroke="${stroke}" stroke-width="3"/>
    <circle cx="${w / 2}" cy="48" r="24" fill="${stroke}"/>
    ${txt(w / 2, 55, num, 20, '#FFFFFF', 700, 'middle')}
    ${txt(w / 2, 108, title, 20, '#244957', 700, 'middle')}
    ${txt(w / 2, 152, sub1, 16, '#244957', 400, 'middle')}
    ${txt(w / 2, 182, sub2, 16, '#567781', 400, 'middle')}
    ${pill(20, 248, w - 40, 38, '#FFFFFF', stroke, sliceTag, '#244957', 16)}
  </g>`;

  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1520" height="1140" viewBox="0 0 1520 1140" role="img" aria-label="End-to-end Context Governance pipeline and zero-LLM deterministic audit capsule">
      <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
      <rect width="1520" height="1140" fill="#FAFCFA"/>
      ${txt(46, 58, 'Five Safety Stations to the Castle Gate — Plus a Zero-LLM Time Capsule!', 33, '#244957', 700)}
      ${txt(48, 98, 'If any single station turns red, the train stops safely. And auditing replays from stamps without calling the LLM!', 21, '#567781')}

      <rect x="34" y="132" width="1452" height="920" rx="28" fill="#EEF7F5" stroke="#B6D8D2" stroke-width="2.5"/>

      ${line('M86 350H1434', '#90B8B2')}

      <g data-subject-ref="${subjectId('stageSearch')}">
        ${station(58, 190, 252, '#FFFFFF', '#2E8B84', '1', 'Tree & Yarn', 'S-Expr cages code;', 'Gen tickets match', 'Slice 45')}
      </g>
      ${arrow('M316 350H344', '#198D87')}

      <g data-subject-ref="${subjectId('stageTemporal')}">
        ${station(350, 190, 252, '#FFFFFF', '#3B6E8C', '2', 'Survival Gem', 'Watermark closed;', '0 unused-leaf debt', 'Slice 44')}
      </g>
      ${arrow('M608 350H636', '#198D87')}

      <g data-subject-ref="${subjectId('stageEpistemic')}">
        ${station(642, 190, 252, '#FFFFFF', '#766DA8', '3', 'Doors & Pins', 'Defeater D1 glued;', 'Omitted Receipt set', 'Slices 41 & 43')}
      </g>
      ${arrow('M900 350H928', '#198D87')}

      <g data-subject-ref="${subjectId('stageGovernance')}">
        ${station(934, 190, 252, '#FFFFFF', '#B7791F', '4', 'Shield & Lock', 'Taint/3-stamp SoD;', 'Pigeon cage locked', 'Slices 40, 42, 46')}
      </g>
      ${arrow('M1192 350H1220', '#1E8268')}

      <g data-subject-ref="${subjectId('cedarHost')}">
        ${station(1226, 190, 236, '#D8EFE3', '#1E8268', '5', 'Cedar & Host', 'Checks live grant', '& atomic CAS!', 'Runtime Owner')}
      </g>

      ${pill(370, 542, 780, 44, '#FFF8E7', '#C8963E', 'Inert Invariant: Stations 1–4 NEVER grant execution (ActionAuthority = False)!', '#7C5416', 18)}

      <rect x="64" y="618" width="1392" height="392" rx="26" fill="#FFFFFF" stroke="#285E8E" stroke-width="3"/>
      ${txt(760, 668, 'Pocket Audit Time-Capsule (DeterministicAuditCapsule)', 26, '#1B4F72', 700, 'middle')}
      ${txt(760, 704, 'Why auditing NEVER becomes a slow burden: six tiny hash stamps lock the whole story!', 19, '#567781', 400, 'middle')}

      <rect x="104" y="738" width="1312" height="112" rx="56" fill="#EAF4F8" stroke="#3B7A9E" stroke-width="3"/>
      ${pill(134, 768, 196, 52, '#FFFFFF', '#2E8B84', '1. ORG Cut Vec', '#145A48', 16)}
      ${pill(346, 768, 200, 52, '#FFFFFF', '#3B6E8C', '2. S-Expr + GQL', '#1B4F72', 16)}
      ${pill(562, 768, 204, 52, '#FFFFFF', '#285E8E', '3. P(J,a,v) Key', '#1B4F72', 16)}
      ${pill(782, 768, 200, 52, '#FFFFFF', '#766DA8', '4. Pins & Curtain', '#3F376B', 16)}
      ${pill(998, 768, 196, 52, '#FFFFFF', '#B7791F', '5. SoD & Threats', '#7C5416', 16)}
      ${pill(1210, 768, 176, 52, '#FFFFFF', '#1E8268', '6. Sandbox Cap', '#145A48', 16)}

      ${pill(136, 892, 560, 54, '#E1F3EC', '#1E8268', 'Hot Use Check: O(1) Cut-Stamp Equality!', '#145A48', 19)}
      ${pill(764, 892, 620, 54, '#EDEAF6', '#5B538A', 'Cold Audit Replay: 100% Exact — ZERO LLM Re-runs!', '#3F376B', 19)}

      ${txt(48, 1104, 'Complete Closure: Rigorous from ORG syntax tree to Cedar runtime fence — fast when live, exact when audited.', 21, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// 0. Slice 40-47 Full Formal Chain: ORG -> SysML2 XOR Dispatcher -> Lean4 DAG <-> Quint Races -> SysML Closure
const composeVerificationDispatchStory: FigureComposer = context => {
  const {txt, arrow, pill, character, subjectId} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1520" height="1260" viewBox="0 0 1520 1260" role="img" aria-label="End-to-end closed-loop chain across ORG, SysML v2, Lean 4 DAG, and Quint concurrent models">
      <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
      <rect width="1520" height="1260" fill="#FAFCFA"/>
      ${txt(46, 58, 'One Continuous Assurance Chain — Zero Gaps, Zero Duplicate Work!', 34, '#244957', 700)}
      ${txt(48, 98, 'ORG intent -> SysML v2 XOR dispatch -> Lean 4 imported DAG (40..46->47) + Quint composed races -> SysML run closure.', 20, '#567781')}

      <rect x="36" y="124" width="1448" height="1054" rx="28" fill="#F1F8F6" stroke="#B7D7D0" stroke-width="2.5"/>

      <!-- Top Dispatcher Card: ORG + SysML v2 -->
      <g id="${subjectId('governancePlane')}">
        <rect x="300" y="148" width="920" height="232" rx="24" fill="#FFFFFF" stroke="#2874A6" stroke-width="3.5"/>
        ${txt(760, 190, 'Stage 1: ORG Contracts + SysML v2 Master XOR Dispatcher', 25, '#1F4E78', 700, 'middle')}
        ${character(372, 214, '#2874A6', 'SysML2')}
        ${pill(504, 214, 676, 42, '#EBF5FB', '#2874A6', '42 Packages Validated (7,068 elements, 64,370 checks, 0 errors)', '#1F4E78', 17)}
        ${pill(504, 268, 676, 42, '#FEF9E7', '#B7791F', '100% Bidirectional XOR: 32 Reqs (19 Lean XOR 13 Quint), 0 Orphans', '#7D5A0B', 17)}
        ${txt(842, 344, 'Slice 47 SysML imports all 8 upstream packages (40..46, 48) + ITF Replay', 16, '#34495E', 700, 'middle')}
      </g>

      ${arrow('M550 380L360 450', '#1E8449')}
      ${txt(256, 418, 'LeanAlgebraicObligation', 18, '#1E8449', 700, 'middle')}

      ${arrow('M970 380L1160 450', '#6C5CE7')}
      ${txt(1264, 418, 'QuintInterleavingObligation', 18, '#6C5CE7', 700, 'middle')}

      <!-- Left Specialist: Lean 4 Imported DAG -->
      <g id="${subjectId('contextPlane')}">
        <rect x="56" y="456" width="636" height="516" rx="24" fill="#FFFFFF" stroke="#1E8449" stroke-width="3.5"/>
        ${pill(84, 478, 580, 46, '#EAFAF1', '#1E8449', 'Stage 2A: Lean 4 — Imported DAG & AxiomAudit', '#196F3D', 20)}
        ${character(98, 554, '#1E8449', 'Lean 4', '54 Theorems')}
        ${txt(232, 570, '47.lean imports «40»..«46» & «48» (.olean DAG):', 17, '#196F3D', 700)}
        ${txt(232, 602, '✓ 40–41: Semilattice meet + defeater list & frame', 16, '#2C3E50')}
        ${txt(232, 632, '✓ 42: Redaction idem + commit_redacted_ne_raw', 16, '#2C3E50')}
        ${txt(232, 662, '✓ 43: Matrix antitonicity + fit invariance', 16, '#2C3E50')}
        ${txt(232, 692, '✓ 44: Bitemporal cut append + citation frame', 16, '#2C3E50')}
        ${txt(232, 722, '✓ 45: Recursive AST code-cage + GQL walk', 16, '#2C3E50')}
        ${txt(232, 752, '✓ 46: Sandbox intersection + recipient frame', 16, '#2C3E50')}
        ${txt(232, 782, '✓ 48: L0–L3 defeater floor + Stage-1 repair idem', 16, '#2C3E50')}
        ${txt(232, 814, '✓ 47: pureGovernanceChain_end_to_end_sound', 16, '#196F3D', 700)}
        <rect x="84" y="846" width="580" height="98" rx="16" fill="#EAFAF1" stroke="#1E8449" stroke-width="2"/>
        ${txt(374, 884, 'Kernel #check & #print axioms Gate:', 17, '#196F3D', 700, 'middle')}
        ${txt(374, 916, '0 sorryAx, 0 custom axioms across all 54 theorems!', 16, '#2C3E50', 600, 'middle')}
      </g>

      <!-- Horizontal Quotient Bridge alpha between Lean 4 and Quint -->
      ${arrow('M692 714L828 714', '#B7791F', true)}
      ${pill(702, 660, 116, 38, '#FEF9E7', '#B7791F', 'Bridge α', '#7D5A0B', 16)}
      ${txt(760, 742, 'Quotient', 15, '#7D5A0B', 700, 'middle')}
      ${txt(760, 762, 'Guards', 15, '#7D5A0B', 700, 'middle')}

      <!-- Right Specialist: Quint + TLC + Apalache Composed State Machines -->
      <g id="${subjectId('runtimePlane')}">
        <rect x="828" y="456" width="636" height="516" rx="24" fill="#FFFFFF" stroke="#6C5CE7" stroke-width="3.5"/>
        ${pill(856, 478, 580, 46, '#F4F1FE', '#6C5CE7', 'Stage 2B: Quint — 8x Exhaustive TLC + Apalache', '#4A3B99', 20)}
        ${character(870, 554, '#6C5CE7', 'Quint', '71k States')}
        ${txt(1004, 570, '8x TLC (queue=0) + 47.qnt imports s40..s46,s48:', 17, '#4A3B99', 700)}
        ${txt(1004, 602, '✓ 40–41: Cut/threat CAS + 2-Session retraction', 16, '#2C3E50')}
        ${txt(1004, 632, '✓ 42: Multi-agent cert & Repo-Core cut cascade', 16, '#2C3E50')}
        ${txt(1004, 662, '✓ 43: Late competitor H3 vs prepared hammer', 16, '#2C3E50')}
        ${txt(1004, 692, '✓ 44: Watermark vs Why-Not & late valid-time', 16, '#2C3E50')}
        ${txt(1004, 722, '✓ 45: GQL/ASCENT gen-advance & retry race', 16, '#2C3E50')}
        ${txt(1004, 752, '✓ 46: Wake vs revoke & crash unknown scout', 16, '#2C3E50')}
        ${txt(1004, 782, '✓ 48: Defeater overrides L0–L2 + Stage-2 cut', 16, '#2C3E50')}
        ${txt(1004, 814, '✓ 47: 8-plane drift vs Host CAS & cold replay', 16, '#4A3B99', 700)}
        <rect x="856" y="846" width="580" height="98" rx="16" fill="#F4F1FE" stroke="#6C5CE7" stroke-width="2"/>
        ${txt(1146, 884, 'Exhaustive TLC + 27 Real ITF Trace Exports:', 17, '#4A3B99', 700, 'middle')}
        ${txt(1146, 916, '71,056 distinct states (queue=0) + 100% safety map!', 16, '#2C3E50', 600, 'middle')}
      </g>

      ${arrow('M374 972L560 1026', '#1E8449')}
      ${arrow('M1146 972L960 1026', '#6C5CE7')}

      <!-- Bottom Closure Card: Mechanized Chain Gate -->
      <rect x="210" y="1028" width="1100" height="122" rx="22" fill="#FFFFFF" stroke="#1F4E78" stroke-width="3.5"/>
      ${txt(760, 1068, 'Stage 3 Closure: just check-context-governance-chain (v2 Ledger)', 22, '#1F4E78', 700, 'middle')}
      ${pill(256, 1086, 1008, 44, '#EBF5FB', '#1F4E78', 'Replays 29 SysML Dispatch + 27 Real Quint ITF JSON Traces + SHA-256 Binding Ledger!', '#1F4E78', 17)}

      ${txt(48, 1222, 'Unbroken 2D Chain: Horizontal 40..46,48 -> 47 composition + Vertical ORG -> SysML2 -> Lean4/TLC/Apalache -> SysML ITF Replay.', 19, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// 7. Slice 48: ASCENT Progressive Disclosure (L0..L3) & Two-Stage ORG AST Repair
const composeProgressiveDisclosureStory: FigureComposer = context => {
  const {txt, arrow, pill, character, subjectId} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" width="1520" height="1140" viewBox="0 0 1520 1140" role="img" aria-label="Progressive disclosure L0 to L3 with mandatory L3 defeater floor and two-stage ORG AST repair">
      <defs><marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M1 1L11 6L1 11Z" fill="context-stroke"/></marker></defs>
      <rect width="1520" height="1140" fill="#FAFCFA"/>
      ${txt(46, 58, 'Four-Step Zoom Ladder (L0–L3) & Two-Stage Zero-Token Repair Shop!', 34, '#244957', 700)}
      ${txt(48, 98, 'ASCENT keeps prompts slim at L0–L2, ALWAYS snaps open to L3 when a warning pin arrives, and fixes 90% of syntax at 0 tokens.', 20, '#567781')}

      <rect x="36" y="128" width="1448" height="926" rx="28" fill="#F1F8F6" stroke="#B7D7D0" stroke-width="2.5"/>

      <!-- Left Panel: Progressive Disclosure Ladder L0..L3 -->
      <g id="${subjectId('disclosureDeriver')}">
        <rect x="64" y="156" width="668" height="870" rx="24" fill="#FFFFFF" stroke="#2874A6" stroke-width="3.5"/>
        ${pill(94, 182, 608, 48, '#EBF5FB', '#2874A6', 'Part 1: ASCENT Progressive Disclosure (0 LLM Tokens)', '#1F4E78', 20)}

        <!-- L0 -->
        <rect x="94" y="250" width="608" height="104" rx="16" fill="#F8FBFF" stroke="#85C1E9" stroke-width="2.5"/>
        ${pill(114, 278, 86, 44, '#D6EAF8', '#2874A6', 'L0', '#1F4E78', 20)}
        ${txt(224, 294, 'Skeleton Only (Headings + :ID:)', 19, '#1F4E78', 700)}
        ${txt(224, 326, 'Fast map of the whole ORG book without reading body text.', 16, '#567781')}

        <!-- L1 -->
        <rect x="94" y="372" width="608" height="104" rx="16" fill="#F8FBFF" stroke="#5DADE2" stroke-width="2.5"/>
        ${pill(114, 400, 86, 44, '#AED6F1', '#2874A6', 'L1', '#1F4E78', 20)}
        ${txt(224, 416, 'Properties + Checklists + Facets', 19, '#1F4E78', 700)}
        ${txt(224, 448, 'Shows TODO state, [done/total] cookies & dynamic facets.', 16, '#567781')}

        <!-- L2 -->
        <rect x="94" y="494" width="608" height="114" rx="16" fill="#FEF9E7" stroke="#D4AC0D" stroke-width="2.5"/>
        ${pill(114, 526, 86, 44, '#FCF3CF', '#B7791F', 'L2', '#7D5A0B', 20)}
        ${txt(218, 540, '#+RESULTS: Shown, #+BEGIN_THINKING Folded', 18, '#7D5A0B', 700)}
        ${txt(218, 574, 'Lean Law: Folding NEVER drops Defeaters or Results!', 16, '#567781')}

        <!-- L3 -->
        <rect x="94" y="628" width="608" height="148" rx="16" fill="#FDF3F2" stroke="#C0392B" stroke-width="3.5"/>
        ${pill(114, 676, 86, 44, '#FADBD8', '#C0392B', 'L3', '#922B21', 20)}
        ${txt(218, 674, 'MANDATORY Full Raw Span (Unmasked!)', 19, '#922B21', 700)}
        ${txt(218, 708, 'Active Defeater D1 OR explicit drill-down forces L3.', 16, '#2C3E50', 600)}
        ${txt(218, 740, 'TLC Race: Late Defeater evicts folded L0–L2 views!', 16, '#922B21', 700)}

        <rect x="94" y="802" width="608" height="196" rx="18" fill="#EAFAF1" stroke="#1E8449" stroke-width="2.5"/>
        ${character(116, 832, '#1E8449', 'ASCENT')}
        ${txt(250, 864, 'Join-Semilattice Law (Lean 4):', 19, '#196F3D', 700)}
        ${txt(250, 898, 'L0 <= L1 <= L2 <= L3 (idem, comm, assoc)', 17, '#2C3E50')}
        ${txt(250, 932, 'deriveDepth(_, _, defeater=true) == L3', 17, '#196F3D', 700)}
        ${txt(250, 966, 'Zero silent defeater hiding inside collapsed trees!', 16, '#567781')}
      </g>

      <!-- Right Panel: Two-Stage ORG AST Repair Shop -->
      <g id="${subjectId('stageOneRepairer')}">
        <rect x="768" y="156" width="688" height="416" rx="24" fill="#FFFFFF" stroke="#1E8449" stroke-width="3.5"/>
        ${pill(798, 182, 628, 48, '#EAFAF1', '#1E8449', 'Part 2A: Stage-1 Deterministic Auto-Repair (~90%, 0 Tokens)', '#196F3D', 19)}
        ${character(820, 268, '#1E8449', 'Stage 1', 'Idempotent')}
        ${txt(956, 276, 'Deterministic AST fixes before calling any LLM:', 18, '#196F3D', 700)}
        ${txt(956, 314, '✓ Rewrite nested :THINKING: drawer -> #+BEGIN_THINKING', 16, '#2C3E50')}
        ${txt(956, 348, '✓ Close unclosed drawers/blocks & normalize checkboxes', 16, '#2C3E50')}
        ${txt(956, 382, '✓ Recompute [done/total] / [pct%] statistics cookies', 16, '#2C3E50')}
        ${txt(956, 416, '✓ Re-parse via Orgize before admitting ElementSpace', 16, '#2C3E50')}
        <rect x="798" y="458" width="628" height="86" rx="16" fill="#EAFAF1" stroke="#1E8449" stroke-width="2"/>
        ${txt(1112, 492, 'Lean Proof: repair(repair(x)) == repair(x)', 17, '#196F3D', 700, 'middle')}
        ${txt(1112, 524, 'Preserves EVERY :ID: and activeDefeater flag identically!', 16, '#2C3E50', 600, 'middle')}
      </g>

      ${arrow('M1112 572L1112 624', '#6C5CE7')}
      ${txt(1272, 604, '~10% semantic break only', 16, '#6C5CE7', 700, 'middle')}

      <g id="${subjectId('stageTwoProposer')}">
        <rect x="768" y="628" width="688" height="398" rx="24" fill="#FFFFFF" stroke="#6C5CE7" stroke-width="3.5"/>
        ${pill(798, 654, 628, 48, '#F4F1FE', '#6C5CE7', 'Part 2B: Stage-2 Diagnostic Flash Repair (~10%, Fenced)', '#4A3B99', 19)}
        ${character(820, 740, '#6C5CE7', 'Flash', 'Zero Auth')}
        ${txt(956, 748, 'Receives ONLY failing subtree + ASCENT diagnostics:', 18, '#4A3B99', 700)}
        ${txt(956, 786, '✓ Carries ZERO direct write authority (uninhabited in Lean)', 16, '#2C3E50')}
        ${txt(956, 820, '✓ Must re-enter Orgize re-parse at exact live sourceCut', 16, '#2C3E50')}
        ${txt(956, 854, '✓ Concurrent sourceCut advance invalidates stale patches', 16, '#2C3E50')}
        <rect x="798" y="902" width="628" height="96" rx="16" fill="#FDF3F2" stroke="#C0392B" stroke-width="2"/>
        ${txt(1112, 938, 'Exhaustive TLC Race Guarantee (1,213 states, queue = 0):', 17, '#922B21', 700, 'middle')}
        ${txt(1112, 972, 'Raw unparsed or stale-cut Flash patches NEVER publish!', 16, '#2C3E50', 600, 'middle')}
      </g>

      ${txt(48, 1100, 'Slice 48 Closure: Slim prompts for Flash models without ever hiding a Defeater or bypassing Orgize re-parse.', 20, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// ---------------------------------------------------------------------------
// Story 49: Zero-SubAgent Shared Context, Scoped Detours & 3-State FunFlow
// ---------------------------------------------------------------------------
const composeSharedContextDetoursStory: FigureComposer = context => {
  const {subjectId, pill, txt, arrow} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" viewBox="0 0 1520 1120" width="1520" height="1120" role="img" aria-label="Zero-SubAgent Shared Org Context, 4-Exit Detours, and 3-State FunFlow">
      <defs>
        <marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
          <path d="M1 1L11 6L1 11Z" fill="context-stroke"/>
        </marker>
      </defs>
      <rect width="1520" height="1120" fill="#FBF8F1"/>
      ${txt(48, 64, 'One Shared Org Desk — Zero SubAgent Silos, 4-Exit Detours & 3-State FunFlow', 30, '#1B3B4B', 800)}
      ${txt(48, 102, 'Humans and peer Agents share one live Org tree (Extend, Never Overwrite) with 3-state FunFlow admission.', 19, '#496370', 500)}

      <g data-subject-ref="${subjectId('ownershipArbiter')}">
        <rect x="48" y="138" width="690" height="440" rx="22" fill="#FFFFFF" stroke="#2D7E8A" stroke-width="2.5"/>
        ${pill(72, 160, 410, 36, '#E4F4F5', '#2D7E8A', '1. ZERO-SUBAGENT SHARED ORG CONTEXT', '#1B5E68')}
        ${txt(72, 226, 'No isolated child chats re-reading the repo O(K × N)!', 19, '#1B3B4B', 700)}
        <rect x="72" y="248" width="642" height="116" rx="14" fill="#F2FAFA" stroke="#2D7E8A" stroke-width="2"/>
        ${txt(92, 282, ':ID: TASK-42  →  :OWNER_ACTOR: agentA  |  :CLAIM_LEASE_EPOCH: 1', 16, '#1B5E68', 700)}
        ${txt(92, 314, 'Peer agentB or Human sees this claim at L0/L1 in 0 tokens:', 16, '#2C3E50')}
        ${txt(92, 344, '✗ Direct overwrite by agentB REJECTED (Lean + Rust Ledger)', 16, '#B03A2E', 700)}
        <rect x="72" y="384" width="642" height="166" rx="14" fill="#F6FBF7" stroke="#2E7D32" stroke-width="2"/>
        ${txt(92, 418, '✓ Safe Peer Contribution = EXTEND via Disjoint Child :ID: Y', 17, '#1B5E20', 700)}
        ${txt(92, 452, ':EXTENDS_ID: TASK-42  →  leaves TASK-42 owner & bytes invariant', 16, '#2C3E50')}
        ${txt(92, 484, '✓ Explicit Handover or Heartbeat Expiry → increments epoch +', 16, '#2C3E50')}
        ${txt(92, 514, '  saves dirty edits in GitOps custody (zero split-brain!)', 16, '#1B5E20', 600)}
      </g>

      <g data-subject-ref="${subjectId('detourArbiter')}">
        <rect x="782" y="138" width="690" height="440" rx="22" fill="#FFFFFF" stroke="#8C5A2B" stroke-width="2.5"/>
        ${pill(806, 160, 410, 36, '#FDF1E4', '#8C5A2B', '2. SCOPED DETOURS & 4 CLOS EXIT STATES', '#784212')}
        ${txt(806, 226, 'Side-quests stay scoped; 0-token Org re-anchors mainline:', 19, '#1B3B4B', 700)}
        <rect x="806" y="248" width="310" height="140" rx="14" fill="#EEF8EE" stroke="#2E7D32" stroke-width="2"/>
        ${txt(824, 280, 'CompletedExit.', 17, '#1B5E20', 700)}
        ${txt(824, 310, 'Distill receipts to anchor,', 15, '#2C3E50')}
        ${txt(824, 336, 'fold detour to L0, unblock', 15, '#2C3E50')}
        ${txt(824, 362, 'mainline dependencies.', 15, '#2C3E50')}

        <rect x="1136" y="248" width="312" height="140" rx="14" fill="#EEF4FC" stroke="#2874A6" stroke-width="2"/>
        ${txt(1154, 280, 'ParkedExit.', 17, '#1B4F72', 700)}
        ${txt(1154, 310, 'Snapshot dirty worktree to', 15, '#2C3E50')}
        ${txt(1154, 336, 'GitOps custody-oid; keep', 15, '#2C3E50')}
        ${txt(1154, 362, 'mainline tree clean.', 15, '#2C3E50')}

        <rect x="806" y="408" width="310" height="142" rx="14" fill="#FDF2F2" stroke="#C0392B" stroke-width="2"/>
        ${txt(824, 440, 'CancelledExit.', 17, '#922B21', 700)}
        ${txt(824, 470, 'Discard dirty code, BUT', 15, '#2C3E50')}
        ${txt(824, 496, 'MUST keep defeat-conditions', 15, '#922B21', 700)}
        ${txt(824, 522, 'in Counterexample Core!', 15, '#922B21', 700)}

        <rect x="1136" y="408" width="312" height="142" rx="14" fill="#F5F0FA" stroke="#6C3483" stroke-width="2"/>
        ${txt(1154, 440, 'PromotedToTaskExit.', 17, '#4A235A', 700)}
        ${txt(1154, 470, 'Depth/scope exceeded →', 15, '#2C3E50')}
        ${txt(1154, 496, 'fission into top-level Task', 15, '#2C3E50')}
        ${txt(1154, 522, 'Tab in index.org.', 15, '#2C3E50')}
      </g>

      ${arrow('M738 358H782', '#2A586B')}

      <g data-subject-ref="${subjectId('effectGate')}">
        <rect x="48" y="612" width="1424" height="420" rx="22" fill="#FFFFFF" stroke="#5B4B8A" stroke-width="2.5"/>
        ${pill(72, 634, 600, 36, '#EFEBF9', '#5B4B8A', '3. THREE-STATE FUNFLOW EFFECTS & MONOTONIC OVERLAY', '#4A3B99')}
        ${txt(72, 702, 'Asymmetric CLOS (admit-node-effect) + 0-Token Premise Invalidation + Monotonic C4 OrgOverlay(g):', 19, '#1B3B4B', 700)}

        <rect x="72" y="728" width="430" height="270" rx="16" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(94, 766, 'PureCAS.', 20, '#1B5E20', 800)}
        ${txt(94, 804, 'Deterministic parses, builds, checks', 16, '#2C3E50')}
        ${txt(94, 838, '✓ Admitted unconditionally', 16, '#1B5E20', 700)}
        ${txt(94, 872, '✓ Skipped on exact input CAS hit', 16, '#2C3E50')}
        ${txt(94, 906, '✓ 0-token premise-digest invalidation', 16, '#2C3E50')}
        ${txt(94, 940, '  marks ONLY affected sub-DAG stale', 16, '#2C3E50')}

        <rect x="545" y="728" width="430" height="270" rx="16" fill="#EEF4FC" stroke="#2874A6" stroke-width="2"/>
        ${txt(567, 766, 'VerifiedEpistemic.', 20, '#1B4F72', 800)}
        ${txt(567, 804, 'Stochastic LLM reasoning steps', 16, '#2C3E50')}
        ${txt(567, 838, '✓ Semantic CAS reuse ONLY if bound', 16, '#1B4F72', 700)}
        ${txt(567, 872, '  to live source-cut + Endorsement', 16, '#2C3E50')}
        ${txt(567, 906, '✓ Premise shift forces re-plan epoch', 16, '#2C3E50')}
        ${txt(567, 940, '  (g → g+1) without losing clean CAS', 16, '#2C3E50')}

        <rect x="1018" y="728" width="430" height="270" rx="16" fill="#FDF2F2" stroke="#C0392B" stroke-width="2"/>
        ${txt(1040, 766, 'FencedEffect.', 20, '#922B21', 800)}
        ${txt(1040, 804, 'Irreversible external side-effects', 16, '#2C3E50')}
        ${txt(1040, 838, '✓ Requires claimsExhaustive = true', 16, '#922B21', 700)}
        ${txt(1040, 872, '✓ One-shot AuthorizedEffectToken', 16, '#2C3E50')}
        ${txt(1040, 906, '✓ Non-self Endorsement + finalizer', 16, '#2C3E50')}
        ${txt(1040, 940, '✓ TLC: 1,379,280 states, queue = 0!', 16, '#922B21', 700)}
      </g>

      ${txt(48, 1084, 'Slice 49 Closure: DeLM-class shared-context speed with formal Extend-Never-Overwrite, 4-exit detours, and 3-state FunFlow.', 19, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// ---------------------------------------------------------------------------
// Story 50: APPA Detour Taint Confinement & NeuroTaint Offline Causal Audit
// ---------------------------------------------------------------------------
const composeDetourConfinementAuditStory: FigureComposer = context => {
  const {subjectId, pill, txt, arrow} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" viewBox="0 0 1520 1120" width="1520" height="1120" role="img" aria-label="APPA Scoped Detour Taint Confinement and NeuroTaint Offline Causal Audit">
      <defs>
        <marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
          <path d="M1 1L11 6L1 11Z" fill="context-stroke"/>
        </marker>
      </defs>
      <rect width="1520" height="1120" fill="#FBF8F1"/>
      ${txt(48, 64, 'Absorbing 2026 Research: APPA Taint Confinement & NeuroTaint Causal Audit', 30, '#1B3B4B', 800)}
      ${txt(48, 102, 'Read untrusted web data without poisoning the mainline, catch implicit secret leaks offline, and advise without auto-mutating.', 19, '#496370', 500)}

      <g data-subject-ref="${subjectId('taintMonitor')}">
        <rect x="48" y="138" width="930" height="460" rx="22" fill="#FFFFFF" stroke="#2D7E8A" stroke-width="2.5"/>
        ${pill(72, 160, 560, 36, '#E4F4F5', '#2D7E8A', '1. APPA-STYLE SCOPED DETOUR TAINT CONFINEMENT', '#1B5E68')}
        ${txt(72, 226, 'Solves monotone taint "label creep" without weakening isolation:', 19, '#1B3B4B', 700)}

        <rect x="72" y="252" width="250" height="312" rx="16" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(92, 290, 'Clean Mainline', 19, '#1B5E20', 800)}
        ${txt(92, 326, 'tainted = false', 16, '#1B5E20', 700)}
        ${txt(92, 362, 'Opens a confined', 16, '#2C3E50')}
        ${txt(92, 390, 'no-egress detour', 16, '#2C3E50')}
        ${txt(92, 418, 'to inspect untrusted', 16, '#2C3E50')}
        ${txt(92, 446, 'web / external docs.', 16, '#2C3E50')}
        ${txt(92, 502, 'Mainline stays', 16, '#1B5E20', 700)}
        ${txt(92, 530, '100% clean!', 16, '#1B5E20', 700)}

        ${arrow('M322 408H372', '#C0392B')}

        <rect x="372" y="252" width="268" height="312" rx="16" fill="#FDF2F2" stroke="#C0392B" stroke-width="2"/>
        ${txt(392, 290, 'Confined Detour', 19, '#922B21', 800)}
        ${txt(392, 326, 'detourTainted = true', 16, '#922B21', 700)}
        ${txt(392, 362, 'egressAllowed = false', 16, '#922B21', 700)}
        ${txt(392, 402, '✗ External egress', 16, '#2C3E50')}
        ${txt(392, 430, '  blocked (Lean proof)', 16, '#2C3E50')}
        ${txt(392, 470, '✗ Raw unattested', 16, '#2C3E50')}
        ${txt(392, 498, '  return REJECTED', 16, '#922B21', 700)}

        ${arrow('M640 408H690', '#2E7D32')}

        <rect x="690" y="252" width="264" height="312" rx="16" fill="#EEF4FC" stroke="#2874A6" stroke-width="2"/>
        ${txt(710, 290, 'Attested Return', 19, '#1B4F72', 800)}
        ${txt(710, 328, 'Requires EITHER:', 16, '#1B4F72', 700)}
        ${txt(710, 364, '• attestSchema pass', 16, '#2C3E50')}
        ${txt(710, 394, '  (bounded fields)', 15, '#496370')}
        ${txt(710, 430, '• 3-party SoD', 16, '#2C3E50')}
        ${txt(710, 460, '  DeclassificationCert', 15, '#496370')}
        ${txt(710, 512, '✓ Mainline taint', 16, '#1B5E20', 700)}
        ${txt(710, 540, '  never escalates!', 16, '#1B5E20', 700)}
      </g>

      <g data-subject-ref="${subjectId('stallAdvisor')}">
        <rect x="1014" y="138" width="458" height="460" rx="22" fill="#FFFFFF" stroke="#8C5A2B" stroke-width="2.5"/>
        ${pill(1038, 160, 380, 36, '#FDF1E4', '#8C5A2B', '3. STALL & DIVERGENCE ADVISOR', '#784212')}
        ${txt(1038, 226, 'Memento / SagaLLM-inspired signal:', 18, '#1B3B4B', 700)}
        <rect x="1038" y="252" width="410" height="142" rx="14" fill="#FFF9F2" stroke="#8C5A2B" stroke-width="2"/>
        ${txt(1058, 286, 'Triggers deterministically when:', 16, '#784212', 700)}
        ${txt(1058, 320, '• repeatedFailures >= threshold', 16, '#2C3E50')}
        ${txt(1058, 354, '• consecutiveInvalidations >= threshold', 16, '#2C3E50')}
        <rect x="1038" y="414" width="410" height="150" rx="14" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(1058, 448, 'Strict Zero-Authority Guarantee:', 17, '#1B5E20', 700)}
        ${txt(1058, 482, '• Emits suggestParkOrCancel to', 16, '#2C3E50')}
        ${txt(1058, 510, '  ASCENT / Human ONLY', 16, '#2C3E50')}
        ${txt(1058, 542, '• authorizesAutoMutation = false', 16, '#922B21', 700)}
      </g>

      <g data-subject-ref="${subjectId('causalAuditor')}">
        <rect x="48" y="632" width="1424" height="398" rx="22" fill="#FFFFFF" stroke="#5B4B8A" stroke-width="2.5"/>
        ${pill(72, 654, 600, 36, '#EFEBF9', '#5B4B8A', '2. NEUROTAINT-STYLE ZERO-LLM OFFLINE CAUSAL AUDIT', '#4A3B99')}
        ${txt(72, 720, 'Catches implicit secret leaks (where an LLM flips a decision without copying secret strings):', 19, '#1B3B4B', 700)}

        <rect x="72" y="748" width="420" height="246" rx="16" fill="#F7F5FD" stroke="#5B4B8A" stroke-width="2"/>
        ${txt(94, 786, 'Counterfactual Replay Pair', 18, '#4A3B99', 700)}
        ${txt(94, 824, 'Run A: decisionWithSecret', 16, '#2C3E50')}
        ${txt(94, 858, 'Run B: decisionWithoutSecret', 16, '#2C3E50')}
        ${txt(94, 898, 'Zero LLM calls during offline', 16, '#4A3B99', 600)}
        ${txt(94, 928, 'AuditCapsule replay check.', 16, '#4A3B99', 600)}

        ${arrow('M492 871H552', '#5B4B8A')}

        <rect x="552" y="748" width="420" height="246" rx="16" fill="#FDF2F2" stroke="#C0392B" stroke-width="2"/>
        ${txt(574, 786, 'Unendorsed Decision Flip', 18, '#922B21', 700)}
        ${txt(574, 824, 'Run A != Run B  AND', 16, '#922B21', 700)}
        ${txt(574, 858, 'auditDeclassCertified = false', 16, '#922B21', 700)}
        ${txt(574, 902, '→ implicitCausalLeakFlag = TRUE', 17, '#922B21', 800)}
        ${txt(574, 940, 'Proven in Lean + TLC (555 states)!', 16, '#2C3E50')}

        ${arrow('M972 871H1032', '#2E7D32')}

        <rect x="1032" y="748" width="416" height="246" rx="16" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(1054, 786, 'Clean Audit Verdict', 18, '#1B5E20', 700)}
        ${txt(1054, 824, 'Either Run A == Run B', 16, '#2C3E50')}
        ${txt(1054, 858, '(counterfactual invariant), OR', 16, '#2C3E50')}
        ${txt(1054, 892, 'auditDeclassCertified = true', 16, '#1B5E20', 700)}
        ${txt(1054, 932, '→ implicitCausalLeakFlag = FALSE', 17, '#1B5E20', 800)}
      </g>

      ${txt(48, 1084, 'Slice 50 Closure: Bridges APPA (arXiv:2607.24625) + NeuroTaint (arXiv:2604.23374) + Memento into Lean & TLC.', 19, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// ---------------------------------------------------------------------------
// Story 51: Memory Poisoning Quarantine & KV-Prefix-Stable Serialization
// ---------------------------------------------------------------------------
const composeMemoryQuarantineKvPrefixStory: FigureComposer = context => {
  const {subjectId, pill, txt, arrow} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" viewBox="0 0 1520 1120" width="1520" height="1120" role="img" aria-label="Memory Poisoning Quarantine and Two-Zone KV-Prefix-Stable Serialization">
      <defs>
        <marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
          <path d="M1 1L11 6L1 11Z" fill="context-stroke"/>
        </marker>
      </defs>
      <rect width="1520" height="1120" fill="#FBF8F1"/>
      ${txt(48, 64, 'Memory Poisoning Quarantine & KV-Prefix-Stable Prompt Serialization', 30, '#1B3B4B', 800)}
      ${txt(48, 102, 'Blocks MINJA / MemoryGraft experience hijacking and stops rolling-detour context edits from fracturing KV radix caches.', 19, '#496370', 500)}

      <g data-subject-ref="${subjectId('quarantineGate')}">
        <rect x="48" y="138" width="1424" height="440" rx="22" fill="#FFFFFF" stroke="#C0392B" stroke-width="2.5"/>
        ${pill(72, 160, 680, 36, '#FDF2F2', '#C0392B', '1. QUARANTINE-BEFORE-RECALL (MINJA / MEMORYGRAFT DEFENSE)', '#922B21')}
        ${txt(72, 226, 'Even with Extend-Never-Overwrite, untrusted experience recipes cannot auto-enter recall:', 19, '#1B3B4B', 700)}

        <rect x="72" y="252" width="380" height="292" rx="16" fill="#FFF6F6" stroke="#C0392B" stroke-width="2"/>
        ${txt(94, 290, 'Untrusted Artifact Turn', 19, '#922B21', 800)}
        ${txt(94, 328, 'e.g. Poisoned README / Web doc', 16, '#2C3E50')}
        ${txt(94, 362, 'induces agent to log a fake', 16, '#2C3E50')}
        ${txt(94, 396, '"successful" procedural recipe:', 16, '#2C3E50')}
        ${txt(94, 434, 'origin = untrustedIngest', 16, '#922B21', 700)}
        ${txt(94, 468, 'selfClaimedSuccess = true', 16, '#922B21', 700)}
        ${txt(94, 506, '→ Forced into QUARANTINED tier', 16, '#922B21', 800)}

        ${arrow('M452 398H524', '#C0392B')}

        <rect x="524" y="252" width="420" height="292" rx="16" fill="#FFF9F2" stroke="#8C5A2B" stroke-width="2"/>
        ${txt(546, 290, 'Quarantine Staging Gate', 19, '#784212', 800)}
        ${txt(546, 328, '✗ Strictly invisible to recall()', 16, '#922B21', 700)}
        ${txt(546, 364, '✗ Self-claimed success CANNOT', 16, '#922B21', 700)}
        ${txt(546, 394, '  auto-promote (Lean proven!)', 16, '#922B21', 700)}
        ${txt(546, 436, 'Promotion requires BOTH:', 16, '#1B3B4B', 700)}
        ${txt(546, 470, '✓ independentEndorsement = true', 16, '#1B5E20', 700)}
        ${txt(546, 504, '✓ openDefeaters == 0', 16, '#1B5E20', 700)}

        ${arrow('M944 398H1016', '#2E7D32')}

        <rect x="1016" y="252" width="432" height="292" rx="16" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(1038, 290, 'Recallable Memory Pool', 19, '#1B5E20', 800)}
        ${txt(1038, 328, 'Production recall() queries', 16, '#2C3E50')}
        ${txt(1038, 362, 'ONLY tier == recallable.', 16, '#1B5E20', 700)}
        ${txt(1038, 404, '✓ Poisoned entries rejected', 16, '#2C3E50')}
        ${txt(1038, 438, '  before imitation ever fires', 16, '#2C3E50')}
        ${txt(1038, 480, '✓ Typed MemoryContract +', 16, '#1B5E20', 700)}
        ${txt(1038, 512, '  non-self provenance verified', 16, '#1B5E20', 700)}
      </g>

      <g data-subject-ref="${subjectId('prefixSerializer')}">
        <rect x="48" y="612" width="1424" height="420" rx="22" fill="#FFFFFF" stroke="#2874A6" stroke-width="2.5"/>
        ${pill(72, 634, 580, 36, '#EEF4FC', '#2874A6', '2. TWO-ZONE KV-PREFIX-STABLE PROMPT SERIALIZATION', '#1B4F72')}
        ${txt(72, 700, 'Prevents RadixAttention / Request-Order-Matters KV cache collapse (99.6% → 10.1%) & Context Rot:', 19, '#1B3B4B', 700)}

        <rect x="72" y="730" width="660" height="266" rx="16" fill="#EBF5FB" stroke="#2874A6" stroke-width="2.5"/>
        ${txt(96, 770, 'ZONE A — FROZEN CANONICAL PREFIX (Epoch g)', 19, '#1B4F72', 800)}
        ${txt(96, 810, '• Immutable Org policy & Goal spine + sealed L0/L1 skeleton', 16, '#2C3E50')}
        ${txt(96, 846, '• Sorted canonically by (epoch, nodeId) — invariant to peer', 16, '#2C3E50')}
        ${txt(96, 876, '  arrival order (canonicalPrefixSort_order_invariant)', 16, '#1B4F72', 700)}
        ${txt(96, 916, '• NEVER edited or evicted mid-epoch → 100% KV radix hit!', 16, '#1B5E20', 700)}
        ${txt(96, 954, 'take(|Prefix|, serialize(Prefix, Suffix)) = Prefix', 16, '#1B4F72', 800)}

        ${arrow('M732 863H796', '#2874A6')}

        <rect x="796" y="730" width="652" height="266" rx="16" fill="#F7F5FD" stroke="#5B4B8A" stroke-width="2.5"/>
        ${txt(820, 770, 'ZONE B — DYNAMIC APPEND-ONLY SUFFIX', 19, '#4A3B99', 800)}
        ${txt(820, 810, '• Active L2/L3 progressive drill-downs (Slice 48)', 16, '#2C3E50')}
        ${txt(820, 846, '• Active Scoped Detour & peer :ID: extensions (Slice 49)', 16, '#2C3E50')}
        ${txt(820, 882, '• Opening, swapping, or folding detours touches ONLY Zone B', 16, '#4A3B99', 700)}
        ${txt(820, 918, '• Zone A token prefix digest remains bit-for-bit identical', 16, '#1B5E20', 700)}
        ${txt(820, 954, '✓ Zero prefill stalls, zero mid-prefix cache fracturing!', 16, '#1B5E20', 700)}
      </g>

      ${txt(48, 1084, 'Slice 51 Closure: Defeats MemoryGraft/MINJA poisoning and eliminates KV-cache fracturing across rolling agent loops.', 19, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// ---------------------------------------------------------------------------
// Story 52: FunFlow CAS Singleflight, Premise Retraction, Pinned GC & Sandbox
// ---------------------------------------------------------------------------
const composeFunflowCasSandboxStory: FigureComposer = context => {
  const {subjectId, pill, txt, arrow} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" viewBox="0 0 1520 1120" width="1520" height="1120" role="img" aria-label="FunFlow CAS Singleflight, Fail-Closed Premise Invalidation, AuditCapsule-Pinned GC and ExternalTask Sandbox Binding">
      <defs>
        <marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
          <path d="M1 1L11 6L1 11Z" fill="context-stroke"/>
        </marker>
      </defs>
      <rect width="1520" height="1120" fill="#FBF8F1"/>
      ${txt(48, 64, 'FunFlow Formal Challenge: 5 Real Bugs Found & Repaired (Slice 52)', 30, '#1B3B4B', 800)}
      ${txt(48, 102, 'Formal contracts challenge modules/funflow/{durable-dag,store,control-plane/*}.ss across CAS, GC, finalizers, and sandbox.', 19, '#496370', 500)}

      <g data-subject-ref="${subjectId('casCompilerAndKeyGate')}">
        <rect x="48" y="138" width="930" height="450" rx="22" fill="#FFFFFF" stroke="#2874A6" stroke-width="2.5"/>
        ${pill(72, 160, 680, 36, '#EEF4FC', '#2874A6', '1. CANONICAL 5-TUPLE CAS KEY, PREMISE & FINALIZER CLOSURE', '#1B4F72')}
        ${txt(72, 224, 'Repairs BUG-F1 (dropped finalizer), BUG-F2 (fail-open premise), BUG-F3 (stale/Fenced CAS):', 18, '#1B3B4B', 700)}

        <rect x="72" y="250" width="280" height="310" rx="16" fill="#EBF5FB" stroke="#2874A6" stroke-width="2"/>
        ${txt(92, 286, '5-Tuple CAS Key', 18, '#1B4F72', 800)}
        ${txt(92, 322, '1. schemaVersion', 16, '#2C3E50')}
        ${txt(92, 352, '2. stepCodeDigest', 16, '#1B4F72', 700)}
        ${txt(92, 382, '3. envDigest (Nix/OCI)', 16, '#1B4F72', 700)}
        ${txt(92, 412, '4. sortedInputHashes', 16, '#2C3E50')}
        ${txt(92, 442, '5. sortedPremises', 16, '#2C3E50')}
        ${txt(92, 484, '✓ Code/Env drift busts', 16, '#1B5E20', 700)}
        ${txt(92, 514, '✓ Order-invariant key', 16, '#1B5E20', 700)}

        ${arrow('M352 405H392', '#2874A6')}

        <rect x="392" y="250" width="268" height="310" rx="16" fill="#FDF2F2" stroke="#C0392B" stroke-width="2"/>
        ${txt(412, 286, 'BUG-F2 & F3 Fixes', 18, '#922B21', 800)}
        ${txt(412, 324, 'Premise Retracted:', 16, '#922B21', 700)}
        ${txt(412, 354, 'live = none → DRIFT!', 16, '#922B21', 700)}
        ${txt(412, 384, '(was fail-open #f)', 15, '#496370')}
        ${txt(412, 428, 'FencedEffect. Skip:', 16, '#922B21', 700)}
        ${txt(412, 458, '✗ Plain CAS hit NEVER', 16, '#2C3E50')}
        ${txt(412, 488, '  skips FencedEffect', 16, '#2C3E50')}
        ${txt(412, 518, '✓ Needs idem receipt', 16, '#1B5E20', 700)}

        ${arrow('M660 405H700', '#2E7D32')}

        <rect x="700" y="250" width="254" height="310" rx="16" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(720, 286, 'BUG-F1 Finalizer', 18, '#1B5E20', 800)}
        ${txt(720, 324, 'Include after-start in', 16, '#2C3E50')}
        ${txt(720, 354, 'Tarjan SCC + topo', 16, '#2C3E50')}
        ${txt(720, 384, 'scheduling order.', 16, '#2C3E50')}
        ${txt(720, 428, 'Failed trigger ALWAYS', 16, '#1B5E20', 700)}
        ${txt(720, 458, 'records pending', 16, '#1B5E20', 700)}
        ${txt(720, 488, 'finalizer before', 16, '#1B5E20', 700)}
        ${txt(720, 518, 'archive can succeed.', 16, '#1B5E20', 700)}
      </g>

      <g data-subject-ref="${subjectId('externalSandboxGate')}">
        <rect x="1014" y="138" width="458" height="450" rx="22" fill="#FFFFFF" stroke="#8C5A2B" stroke-width="2.5"/>
        ${pill(1038, 160, 410, 36, '#FDF1E4', '#8C5A2B', '2. EXTERNAL SANDBOX & LEASE GATE', '#784212')}
        ${txt(1038, 224, 'Repairs BUG-F4 (lease & task.ss):', 18, '#1B3B4B', 700)}

        <rect x="1038" y="250" width="410" height="142" rx="14" fill="#FFF9F2" stroke="#8C5A2B" stroke-width="2"/>
        ${txt(1058, 284, 'Disjoint Lease Meet = Bottom', 17, '#784212', 800)}
        ${txt(1058, 318, 'leaseStart > leaseEnd admits 0 times', 16, '#2C3E50')}
        ${txt(1058, 350, '(Lean: disjointLeaseMeet_is_unsatisfiable)', 15, '#784212', 700)}

        <rect x="1038" y="410" width="410" height="150" rx="14" fill="#FDF2F2" stroke="#C0392B" stroke-width="2"/>
        ${txt(1058, 444, 'ExternalTask Sandbox Binding', 17, '#922B21', 800)}
        ${txt(1058, 478, '• Requires pinned Nix/OCI envDigest', 16, '#2C3E50')}
        ${txt(1058, 508, '• Refuses unendorsed Lethal Trifecta', 16, '#922B21', 700)}
        ${txt(1058, 538, '  (untrusted ∧ private ∧ egress)', 15, '#496370')}
      </g>

      <g data-subject-ref="${subjectId('singleflightStoreAndGc')}">
        <rect x="48" y="620" width="1424" height="410" rx="22" fill="#FFFFFF" stroke="#5B4B8A" stroke-width="2.5"/>
        ${pill(72, 642, 740, 36, '#EFEBF9', '#5B4B8A', '3. MULTI-AGENT SINGLEFLIGHT, CRASH-ATOMIC PUBLISH & PINNED CAS GC', '#4A3B99')}
        ${txt(72, 706, 'Repairs BUG-F5 (store.ss / durable-dag.ss concurrency, crash atomicity, and cold-replay survival):', 19, '#1B3B4B', 700)}

        <rect x="72" y="734" width="424" height="264" rx="16" fill="#F7F5FD" stroke="#5B4B8A" stroke-width="2"/>
        ${txt(94, 772, 'lookupOrWait Singleflight', 19, '#4A3B99', 800)}
        ${txt(94, 810, 'Agent A acquires key lock (active = 1)', 16, '#2C3E50')}
        ${txt(94, 842, 'Agent B arrives → waits (no double-run)', 16, '#2C3E50')}
        ${txt(94, 882, 'If Agent A crashes before rename,', 16, '#4A3B99', 700)}
        ${txt(94, 914, 'Agent B takes over cleanly.', 16, '#4A3B99', 700)}
        ${txt(94, 954, 'Invariant: activeComputeCount <= 1', 16, '#1B5E20', 800)}

        ${arrow('M496 866H548', '#5B4B8A')}

        <rect x="548" y="734" width="424" height="264" rx="16" fill="#EEF4FC" stroke="#2874A6" stroke-width="2"/>
        ${txt(570, 772, 'Atomic Temp → Rename', 19, '#1B4F72', 800)}
        ${txt(570, 810, '1. Stage bytes in private temp path', 16, '#2C3E50')}
        ${txt(570, 842, '2. Crash mid-write leaves CAS clean', 16, '#2C3E50')}
        ${txt(570, 882, '3. Atomic rename publishes entry +', 16, '#1B4F72', 700)}
        ${txt(570, 914, '   records livePremiseGen atomically', 16, '#1B4F72', 700)}
        ${txt(570, 954, 'Invariant: corruptCasVisible = false', 16, '#1B5E20', 800)}

        ${arrow('M972 866H1024', '#2E7D32')}

        <rect x="1024" y="734" width="424" height="264" rx="16" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(1046, 772, 'AuditCapsule-Pinned GC', 19, '#1B5E20', 800)}
        ${txt(1046, 810, 'Sealed cut=1 AuditCapsule pins its', 16, '#2C3E50')}
        ${txt(1046, 842, 'forensic CAS artifacts (pinned = true).', 16, '#2C3E50')}
        ${txt(1046, 882, 'GC sweeps only unpinned stale entries;', 16, '#1B5E20', 700)}
        ${txt(1046, 914, 'cold forensic replay always survives!', 16, '#1B5E20', 700)}
        ${txt(1046, 954, 'Lean + TLC verified (queue = 0)', 16, '#1B5E20', 800)}
      </g>

      ${txt(48, 1084, 'Slice 52 Closure: Formal challenge surfaced 5 real FunFlow bugs (BUG-F1..F5) and proved the repaired contract in Lean & TLC.', 19, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// ---------------------------------------------------------------------------
// Story 53: Two-Tier Yuanxu Interface, Slot-Observation & C4 Profile Convergence
// ---------------------------------------------------------------------------
const composeC4ProfileConvergenceStory: FigureComposer = context => {
  const {subjectId, pill, txt, arrow} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" viewBox="0 0 1520 1120" width="1520" height="1120" role="img" aria-label="Two-Tier Yuanxu Interface, POO Slot-Observation and C4 Profile Convergence">
      <defs>
        <marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
          <path d="M1 1L11 6L1 11Z" fill="context-stroke"/>
        </marker>
      </defs>
      <rect width="1520" height="1120" fill="#FBF8F1"/>
      ${txt(48, 64, 'Two-Tier Yuanxu Interface, POO Slot-Observation & C4 Profile Convergence', 30, '#1B3B4B', 800)}
      ${txt(48, 102, 'Formalizes INV-1..INV-6: explicit closure, veto dominance, fail-closed peer conflict, monotonic floor, and zero runtime compile bleed.', 19, '#496370', 500)}

      <g data-subject-ref="${subjectId('assemblyEntry')}">
        <rect x="48" y="138" width="1424" height="420" rx="22" fill="#FFFFFF" stroke="#2874A6" stroke-width="2.5"/>
        ${pill(72, 160, 740, 36, '#EEF4FC', '#2874A6', '1. TIER 1 ENTRYPOINT (yuanxu!) — EXPLICIT CLOSURE & VETO DOMINANCE', '#1B4F72')}
        ${txt(72, 224, 'INV-1, INV-2 & INV-3: Implied cross-module bridges & tag targeting NEVER pull undeclared modules:', 19, '#1B3B4B', 700)}

        <rect x="72" y="252" width="420" height="274" rx="16" fill="#EBF5FB" stroke="#2874A6" stroke-width="2"/>
        ${txt(94, 290, 'Closed Module Universe', 19, '#1B4F72', 800)}
        ${txt(94, 328, 'Admitted: { env, context, ... }', 16, '#2C3E50')}
        ${txt(94, 362, '• Implied bridges (durable.enabled?)', 16, '#2C3E50')}
        ${txt(94, 392, '  fire ONLY inside admitted closure', 16, '#1B4F72', 700)}
        ${txt(94, 430, '• by-tag Global Profiles NEVER pull', 16, '#2C3E50')}
        ${txt(94, 460, '  undeclared modules (Lean proven!)', 16, '#1B5E20', 700)}
        ${txt(94, 496, 'INV-1: subset_admitted = TRUE', 16, '#1B5E20', 800)}

        ${arrow('M492 389H548', '#2874A6')}

        <rect x="548" y="252" width="420" height="274" rx="16" fill="#FFF9F2" stroke="#8C5A2B" stroke-width="2"/>
        ${txt(570, 290, 'Band 4b Explicit Veto (-feat)', 19, '#784212', 800)}
        ${txt(570, 328, 'Band 1: implied bridge sets enabled', 16, '#2C3E50')}
        ${txt(570, 362, 'Band 4b: user -durable veto overrides', 16, '#922B21', 700)}
        ${txt(570, 396, 'purely via C4 precedence — ZERO', 16, '#2C3E50')}
        ${txt(570, 426, 'magic priority integers!', 16, '#784212', 700)}
        ${txt(570, 464, 'resolve(implied, explicitVeto) = false', 16, '#922B21', 700)}
        ${txt(570, 496, 'INV-3: Veto ALWAYS dominates', 16, '#1B5E20', 800)}

        ${arrow('M968 389H1024', '#2E7D32')}

        <rect x="1024" y="252" width="424" height="274" rx="16" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(1046, 290, 'Stage Separation (INV-6)', 19, '#1B5E20', 800)}
        ${txt(1046, 328, '• Inactive assembly features stay', 16, '#2C3E50')}
        ${txt(1046, 358, '  100% outside compiledClosure', 16, '#1B5E20', 700)}
        ${txt(1046, 396, '• Runtime slots (detour-state) mount', 16, '#2C3E50')}
        ${txt(1046, 426, '  C4 overlays at 0 compile cost', 16, '#1B5E20', 700)}
        ${txt(1046, 464, 'runtimeStageSlot_never_expands', 15, '#1B5E20', 700)}
        ${txt(1046, 496, '✓ Zero cost for inactive units', 16, '#1B5E20', 800)}
      </g>

      <g data-subject-ref="${subjectId('convergenceEngine')}">
        <rect x="48" y="592" width="1424" height="438" rx="22" fill="#FFFFFF" stroke="#5B4B8A" stroke-width="2.5"/>
        ${pill(72, 614, 880, 36, '#EFEBF9', '#5B4B8A', '2. TIER 2 CONVERGENCE ENGINE — PEER CONFLICT FAIL-CLOSED & GOVERNANCE FLOOR', '#4A3B99')}
        ${txt(72, 678, 'INV-4 & INV-5: Same-band exclusive disagreement fails closed; Band 5 GovernanceFloor only narrows:', 19, '#1B3B4B', 700)}

        <rect x="72" y="706" width="660" height="292" rx="16" fill="#FDF2F2" stroke="#C0392B" stroke-width="2.5"/>
        ${txt(96, 746, 'INV-4: Same-Band Peer Exclusive Conflict = FAIL-CLOSED', 19, '#922B21', 800)}
        ${txt(96, 786, '• Peer Profile A sets scalar slot = "on-blur"', 16, '#2C3E50')}
        ${txt(96, 820, '• Peer Profile B sets scalar slot = "immediate"', 16, '#2C3E50')}
        ${txt(96, 860, '✗ Silent order-luck overwrite is FORBIDDEN', 16, '#922B21', 700)}
        ${txt(96, 896, '✓ Emits structured conflict(left, right) verdict', 16, '#1B5E20', 700)}
        ${txt(96, 932, '✓ Equal peers collapse cleanly: combine(v, v) = ok(v)', 16, '#1B5E20', 700)}
        ${txt(96, 968, 'Lean: peerExclusive_disagreement_conflicts', 16, '#922B21', 800)}

        ${arrow('M732 852H796', '#5B4B8A')}

        <rect x="796" y="706" width="652" height="292" rx="16" fill="#F7F5FD" stroke="#5B4B8A" stroke-width="2.5"/>
        ${txt(820, 746, 'INV-5: Band 5 GovernanceFloor Monotonic Meet', 19, '#4A3B99', 800)}
        ${txt(820, 786, '• Folds envMeet across arbitrary Profile lists:', 16, '#2C3E50')}
        ${txt(820, 820, '  trustCeiling = min(a, b), network/write = a && b', 16, '#4A3B99', 700)}
        ${txt(820, 860, '• No Profile or overlay can EVER escalate trust ceiling', 16, '#2C3E50')}
        ${txt(820, 896, '  or re-grant disabled network/write capabilities', 16, '#2C3E50')}
        ${txt(820, 932, '✓ foldGovernanceFloor_no_escalation (Lean + TLC)', 16, '#1B5E20', 700)}
        ${txt(820, 968, '✓ 10 Lean theorems + exhaustive TLC (queue = 0)', 16, '#1B5E20', 800)}
      </g>

      ${txt(48, 1084, 'Slice 53 Closure: Unifies Yuanxu Design 165 Two-Tier C4 Profile Convergence into the 15-Slice Assurance Chain.', 19, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// Story 54: Pure Durable Work Engine Core Challenge (BUG-D1..BUG-D5)
const composeDurableWorkCoreChallengeStory: FigureComposer = context => {
  const {subjectId, pill, txt, arrow} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" viewBox="0 0 1520 1120" width="1520" height="1120" role="img" aria-label="Durable Work Engine Core Formal Challenge">
      <defs>
        <marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
          <path d="M1 1L11 6L1 11Z" fill="context-stroke"/>
        </marker>
      </defs>
      <rect x="0" y="0" width="1520" height="1120" fill="#FAF8F2"/>
      ${txt(48, 64, 'Durable Work Engine Core Challenge: 5 Real Bugs Found & Repaired (Slice 54)', 32, '#102A3A', 800)}
      ${txt(48, 102, 'Formal contracts challenge modules/durable/work/* & org-adapter.ss across overlays, detours, leases & archive.', 20, '#3C5B6B', 500)}

      <g data-subject-ref="${subjectId('overlayAndDetourGate')}">
        <rect x="48" y="138" width="1424" height="422" rx="22" fill="#FFFFFF" stroke="#1E6091" stroke-width="2.5"/>
        ${pill(72, 160, 820, 36, '#EBF5FB', '#1E6091', '1. MONOTONIC OVERLAY FLOOR, CONFINED DETOUR EXIT & INVARIANT PROJECTION', '#154360')}
        ${txt(72, 224, 'Repairs BUG-D1 (overlay escalation), BUG-D2 (tainted CompletedExit leak), and BUG-D5 (cancelled invariant drop):', 19, '#1B3B4B', 700)}

        <rect x="72" y="252" width="424" height="274" rx="16" fill="#F0F8FF" stroke="#1E6091" stroke-width="2"/>
        ${txt(94, 290, 'BUG-D1: Monotonic Budget Meet', 19, '#154360', 800)}
        ${txt(94, 328, 'Was: overlay overwrote max-parallel,', 16, '#922B21', 700)}
        ${txt(94, 358, 'retry-budget, detour-depth & drill-down', 16, '#2C3E50')}
        ${txt(94, 396, 'Now: min(parent, overlay) >= 0 and', 16, '#1B5E20', 700)}
        ${txt(94, 426, 'parent.allowDrill && overlay.allowDrill', 16, '#1B5E20', 700)}
        ${txt(94, 464, 'Lean: overlayBudgetMeet_never_escalates', 15, '#154360', 700)}
        ${txt(94, 496, '✓ Zero resource/capability escalation', 16, '#1B5E20', 800)}

        ${arrow('M496 389H548', '#1E6091')}

        <rect x="548" y="252" width="420" height="274" rx="16" fill="#FEF5E7" stroke="#9C640C" stroke-width="2"/>
        ${txt(570, 290, 'BUG-D2: Tainted CompletedExit Gate', 19, '#784212', 800)}
        ${txt(570, 328, 'Was: CompletedExit checked ONLY', 16, '#922B21', 700)}
        ${txt(570, 358, 'non-empty receipt digest (taint escaped)', 16, '#2C3E50')}
        ${txt(570, 396, 'Now: if detour.tainted? = #t, MUST carry', 16, '#1B5E20', 700)}
        ${txt(570, 426, 'schema-attested? OR 3-party DeclassCert', 16, '#1B5E20', 700)}
        ${txt(570, 464, 'Lean: taintedDetourCompletedExit_requires', 15, '#784212', 700)}
        ${txt(570, 496, '✓ Closes Slice 50 APPA return boundary', 16, '#1B5E20', 800)}

        ${arrow('M968 389H1024', '#2E7D32')}

        <rect x="1024" y="252" width="424" height="274" rx="16" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(1046, 290, 'BUG-D5: Org Projection Closure', 19, '#1B5E20', 800)}
        ${txt(1046, 328, 'Was: CANCELLED :INVARIANT: counted', 16, '#922B21', 700)}
        ${txt(1046, 358, 'as done? & dropped 5-tuple CAS fields', 16, '#2C3E50')}
        ${txt(1046, 396, 'Now: ONLY DONE satisfies :INVARIANT:', 16, '#1B5E20', 700)}
        ${txt(1046, 426, 'Forwards EffectClass, code & env digests', 16, '#1B5E20', 700)}
        ${txt(1046, 464, 'Lean: cancelledInvariant_remains_unsat', 15, '#1B5E20', 700)}
        ${txt(1046, 496, '✓ Cancelled blockers keep defeat log', 16, '#1B5E20', 800)}
      </g>

      <g data-subject-ref="${subjectId('schedulerAndClaims')}">
        <rect x="48" y="592" width="1424" height="438" rx="22" fill="#FFFFFF" stroke="#5B4B8A" stroke-width="2.5"/>
        ${pill(72, 614, 880, 36, '#EFEBF9', '#5B4B8A', '2. QUIESCENT ARCHIVE FENCE & AUTHORIZED EPOCH-CAS LEASE HANDOVER', '#4A3B99')}
        ${txt(72, 678, 'Repairs BUG-D4 (unclosed-attempt premature archive) and BUG-D3 (unendorsed force-explicit hijack & ABA):', 19, '#1B3B4B', 700)}

        <rect x="72" y="706" width="660" height="292" rx="16" fill="#FDF2F2" stroke="#C0392B" stroke-width="2.5"/>
        ${txt(96, 746, 'BUG-D4: Unclosed Attempts Block Auto-Archive', 19, '#922B21', 800)}
        ${txt(96, 786, '• Was: journal_quiescent checked ONLY in-flight & effects,', 16, '#2C3E50')}
        ${txt(96, 820, '  omitting unclosed-attempts -> archived crashed turns!', 16, '#922B21', 700)}
        ${txt(96, 860, '✓ Now: journal_quiescent requires (null? recovery-ids)', 16, '#1B5E20', 700)}
        ${txt(96, 896, '✓ Any crash-ambiguous attempt unconditionally blocks', 16, '#1B5E20', 700)}
        ${txt(96, 932, '  ready_to_auto_archive until reconciled', 16, '#1B5E20', 700)}
        ${txt(96, 968, 'Lean: unclosedAttempt_blocks_autoArchive_fail_closed', 16, '#922B21', 800)}

        ${arrow('M732 852H796', '#5B4B8A')}

        <rect x="796" y="706" width="652" height="292" rx="16" fill="#F7F5FD" stroke="#5B4B8A" stroke-width="2.5"/>
        ${txt(820, 746, 'BUG-D3: Authorized Handover & Expected-Epoch CAS', 19, '#4A3B99', 800)}
        ${txt(820, 786, '• Was: force-explicit?: #t hijacked active leases with', 16, '#2C3E50')}
        ${txt(820, 820, '  zero endorsement; no expected-epoch CAS or expiry check', 16, '#922B21', 700)}
        ${txt(820, 860, '✓ Early explicit handover requires non-self endorser', 16, '#1B5E20', 700)}
        ${txt(820, 896, '✓ expected-epoch rejects stale ABA claims/handovers', 16, '#1B5E20', 700)}
        ${txt(820, 932, '✓ work-assert-write-owner rejects expired leases', 16, '#1B5E20', 700)}
        ${txt(820, 968, '✓ 10 Lean theorems + exhaustive TLC (360 states, q=0)', 16, '#1B5E20', 800)}
      </g>

      ${txt(48, 1084, 'Slice 54 Closure: Formal challenge surfaced 5 real Durable Work Engine bugs (BUG-D1..D5) in Lean 4 & TLC.', 19, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// Story 55: MCP Tool Poisoning, Rug-Pull Pinning, Shadowing & CaMeL Capability Flow
const composeMcpToolPoisoningCamelStory: FigureComposer = context => {
  const {subjectId, pill, txt, arrow} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" viewBox="0 0 1520 1120" width="1520" height="1120" role="img" aria-label="MCP Tool Poisoning, Rug-Pull Pinning, Shadowing and CaMeL Capability Flow">
      <defs>
        <marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
          <path d="M1 1L11 6L1 11Z" fill="context-stroke"/>
        </marker>
      </defs>
      <rect x="0" y="0" width="1520" height="1120" fill="#FAF8F2"/>
      ${txt(48, 64, 'MCP Tool Poisoning, Rug-Pull Pinning & CaMeL Capability Flow (Slice 55)', 32, '#102A3A', 800)}
      ${txt(48, 102, 'Absorbs MCPTox (2025), CaMeL (Google/DeepMind/ETHZ) & MindGuard into zero-LLM formal tool gates.', 20, '#3C5B6B', 500)}

      <g data-subject-ref="${subjectId('manifestRegistryGate')}">
        <rect x="48" y="138" width="1424" height="422" rx="22" fill="#FFFFFF" stroke="#1E6091" stroke-width="2.5"/>
        ${pill(72, 160, 740, 36, '#EBF5FB', '#1E6091', '1. MANIFEST PINNING, SHADOW BLOCK & METADATA SEGREGATION', '#154360')}
        ${txt(72, 224, 'Blocks MCPTox post-approval rug-pulls, cross-server tool shadowing, and description-as-instruction injection:', 19, '#1B3B4B', 700)}

        <rect x="72" y="252" width="424" height="274" rx="16" fill="#F0F8FF" stroke="#1E6091" stroke-width="2"/>
        ${txt(94, 290, 'Cryptographic Manifest Pin', 19, '#154360', 800)}
        ${txt(94, 328, 'Pins (serverId, toolId,', 16, '#2C3E50')}
        ${txt(94, 358, 'descriptionDigest, schemaDigest)', 16, '#154360', 700)}
        ${txt(94, 396, '✗ Post-approval rug-pull mutation', 16, '#922B21', 700)}
        ${txt(94, 426, '  breaks pin equality immediately', 16, '#922B21', 700)}
        ${txt(94, 464, 'Lean: rugPullMutation_breaks_pin', 15, '#154360', 700)}
        ${txt(94, 496, '✓ Refuses invocation fail-closed', 16, '#1B5E20', 800)}

        ${arrow('M496 389H548', '#1E6091')}

        <rect x="548" y="252" width="420" height="274" rx="16" fill="#FEF5E7" stroke="#9C640C" stroke-width="2"/>
        ${txt(570, 290, 'Cross-Server Shadow Block', 19, '#784212', 800)}
        ${txt(570, 328, 'Registry enforces unique owner', 16, '#2C3E50')}
        ${txt(570, 358, 'serverId per registered toolId.', 16, '#2C3E50')}
        ${txt(570, 396, '✗ Untrusted server CANNOT shadow', 16, '#922B21', 700)}
        ${txt(570, 426, '  trusted git / deploy / mail tools', 16, '#922B21', 700)}
        ${txt(570, 464, 'Lean: crossServerShadowing_rejected', 15, '#784212', 700)}
        ${txt(570, 496, '✓ Namespace collision fail-closed', 16, '#1B5E20', 800)}

        ${arrow('M968 389H1024', '#2E7D32')}

        <rect x="1024" y="252" width="424" height="274" rx="16" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(1046, 290, 'Metadata Trust Segregation', 19, '#1B5E20', 800)}
        ${txt(1046, 328, 'External tool descriptions stay', 16, '#2C3E50')}
        ${txt(1046, 358, 'in untrustedMetadata (rank 0).', 16, '#1B5E20', 700)}
        ${txt(1046, 396, '• Strictly below userIntent (rank 3)', 16, '#2C3E50')}
        ${txt(1046, 426, '• Never promoted to systemPolicy', 16, '#1B5E20', 700)}
        ${txt(1046, 464, 'Lean: metadataSegregation_keeps_...', 15, '#1B5E20', 700)}
        ${txt(1046, 496, '✓ Zero instruction-lane leakage', 16, '#1B5E20', 800)}
      </g>

      <g data-subject-ref="${subjectId('camelSinkAuditGate')}">
        <rect x="48" y="592" width="1424" height="438" rx="22" fill="#FFFFFF" stroke="#5B4B8A" stroke-width="2.5"/>
        ${pill(72, 614, 880, 36, '#EFEBF9', '#5B4B8A', '2. CAMEL VALUE-LEVEL CAPABILITY PROVENANCE & MINDGUARD ZERO-LLM AUDIT', '#4A3B99')}
        ${txt(72, 678, 'Separates control/data flows at sensitive sinks and audits poisoned tool-metadata decision hijacks offline:', 19, '#1B3B4B', 700)}

        <rect x="72" y="706" width="660" height="292" rx="16" fill="#FDF2F2" stroke="#C0392B" stroke-width="2.5"/>
        ${txt(96, 746, 'CaMeL Sensitive Sink Provenance Gate', 19, '#922B21', 800)}
        ${txt(96, 786, '• High-impact sinks: recipient, remoteUrl, shellCmd', 16, '#2C3E50')}
        ${txt(96, 820, '✗ Refuses untrustedMetadata / rawToolOutput args', 16, '#922B21', 700)}
        ${txt(96, 856, '  unless backed by active 3-party DeclassificationCert', 16, '#922B21', 700)}
        ${txt(96, 896, '✓ Admits userIntent args with valid manifest pin', 16, '#1B5E20', 700)}
        ${txt(96, 932, '✓ Blocks exfiltration by design (no LLM alignment trust)', 16, '#1B5E20', 700)}
        ${txt(96, 968, 'Lean: untrustedOriginArgument_blocked_at_sensitive_sink', 15, '#922B21', 800)}

        ${arrow('M732 852H796', '#5B4B8A')}

        <rect x="796" y="706" width="652" height="292" rx="16" fill="#F7F5FD" stroke="#5B4B8A" stroke-width="2.5"/>
        ${txt(820, 746, 'MindGuard Counterfactual Decision Audit', 19, '#4A3B99', 800)}
        ${txt(820, 786, '• Compares selected tool with vs without untrusted', 16, '#2C3E50')}
        ${txt(820, 820, '  external MCP tool-description metadata', 16, '#2C3E50')}
        ${txt(820, 860, '✓ Any unendorsed decision flip flags hijack offline', 16, '#1B5E20', 700)}
        ${txt(820, 896, '✓ llmCallsUsed = 0 (deterministic cold forensic check)', 16, '#1B5E20', 700)}
        ${txt(820, 932, '✓ 6 Lean theorems + exhaustive TLC (144 states, q=0)', 16, '#1B5E20', 700)}
        ${txt(820, 968, '✓ 4 negative-control ITF counterexamples replayed', 16, '#1B5E20', 800)}
      </g>

      ${txt(48, 1084, 'Slice 55 Closure: Seals MCP rug-pull, shadowing & CaMeL sink provenance inside the 16-Slice Assurance Chain.', 19, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

// Story 56: ASCENT-Governed Loop Engine Termination, Anti-Oscillation & Safety Dominance
const composeAscentLoopTerminationStory: FigureComposer = context => {
  const {subjectId, pill, txt, arrow} = drawingHelpers(context);
  return {
    markup: `<svg xmlns="http://www.w3.org/2000/svg" data-vector-surface data-question="${context.text(context.view.question.ref)}" viewBox="0 0 1520 1120" width="1520" height="1120" role="img" aria-label="ASCENT-Governed Loop Engine Termination, Anti-Oscillation and Safety Dominance">
      <defs>
        <marker id="tip" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
          <path d="M1 1L11 6L1 11Z" fill="context-stroke"/>
        </marker>
      </defs>
      <rect x="0" y="0" width="1520" height="1120" fill="#FAF8F2"/>
      ${txt(48, 64, 'ASCENT-Governed Loop Engine Termination & Safety Dominance (Slice 56)', 32, '#102A3A', 800)}
      ${txt(48, 102, 'Eliminates infinite LLM loops via gerbil-ascent relational fixpoint, well-founded budgets & absorbing halts.', 20, '#3C5B6B', 500)}

      <g data-subject-ref="${subjectId('ascentGovernor')}">
        <rect x="48" y="138" width="1424" height="422" rx="22" fill="#FFFFFF" stroke="#1E6091" stroke-width="2.5"/>
        ${pill(72, 160, 740, 36, '#EBF5FB', '#1E6091', '1. ASCENT RELATIONAL CYCLE, OSCILLATION & STALL DETECTION', '#154360')}
        ${txt(72, 224, 'Evaluates pure turn fingerprints via gerbil-ascent relational-program before any LLM or tool action is admitted:', 19, '#1B3B4B', 700)}

        <rect x="72" y="252" width="424" height="274" rx="16" fill="#F0F8FF" stroke="#1E6091" stroke-width="2"/>
        ${txt(94, 290, 'Cycle & Oscillation Guard', 19, '#154360', 800)}
        ${txt(94, 328, '• exact_state_cycle: S_i == S_j (i < j)', 16, '#2C3E50')}
        ${txt(94, 358, '• oscillation_cycle: A -> B -> A ping-pong', 16, '#154360', 700)}
        ${txt(94, 396, '✗ Never admits retry on cycle', 16, '#922B21', 700)}
        ${txt(94, 426, '✓ Halts & escalates to HumanInbox', 16, '#1B5E20', 700)}
        ${txt(94, 464, 'Lean: exactCycle_or_oscillation_...', 15, '#154360', 700)}
        ${txt(94, 496, '✓ Zero infinite retry loops', 16, '#1B5E20', 800)}

        ${arrow('M496 389H548', '#1E6091')}

        <rect x="548" y="252" width="420" height="274" rx="16" fill="#FEF5E7" stroke="#9C640C" stroke-width="2"/>
        ${txt(570, 290, 'Progress Measure & Stall Cut', 19, '#784212', 800)}
        ${txt(570, 328, 'M(t) = frontier + invariants', 16, '#2C3E50')}
        ${txt(570, 358, '     + open_defeaters + blockers', 16, '#2C3E50')}
        ${txt(570, 396, '✗ Halts on repeated failure >= Kf', 16, '#922B21', 700)}
        ${txt(570, 426, '✗ Halts on zero-progress >= Ks', 16, '#922B21', 700)}
        ${txt(570, 464, 'Lean: repeatedFailure_or_zero...', 15, '#784212', 700)}
        ${txt(570, 496, '✓ Stops novel-state token burn', 16, '#1B5E20', 800)}

        ${arrow('M968 389H1024', '#2E7D32')}

        <rect x="1024" y="252" width="424" height="274" rx="16" fill="#F1FAF4" stroke="#2E7D32" stroke-width="2"/>
        ${txt(1046, 290, 'Well-Founded Budget Ceiling', 19, '#1B5E20', 800)}
        ${txt(1046, 328, 'Every admitted turn decrements', 16, '#2C3E50')}
        ${txt(1046, 358, 'stepBudgetRemaining strictly by 1.', 16, '#1B5E20', 700)}
        ${txt(1046, 396, '• Proven for ANY adversarial LLM', 16, '#2C3E50')}
        ${txt(1046, 426, '• Structural induction on budget', 16, '#1B5E20', 700)}
        ${txt(1046, 464, 'Lean: adversarialLoop_universally...', 15, '#1B5E20', 700)}
        ${txt(1046, 496, '✓ Guaranteed finite termination', 16, '#1B5E20', 800)}
      </g>

      <g data-subject-ref="${subjectId('loopBoundary')}">
        <rect x="48" y="592" width="1424" height="438" rx="22" fill="#FFFFFF" stroke="#5B4B8A" stroke-width="2.5"/>
        ${pill(72, 614, 790, 36, '#EFEBF9', '#5B4B8A', '2. SAFETY DOMINANCE, ABSORBING HALT & GOVERNED TURN CLOSURE', '#4A3B99')}
        ${txt(72, 678, 'Chains ContextAssemblyPipeline, Slice 55 MCP/CaMeL, GovernedFunflowRunner & AuditCapsule under absorbing halts:', 19, '#1B3B4B', 700)}

        <rect x="72" y="706" width="660" height="292" rx="16" fill="#FDF2F2" stroke="#C0392B" stroke-width="2.5"/>
        ${txt(96, 746, 'Upstream Safety Dominance & Absorbing Halt', 19, '#922B21', 800)}
        ${txt(96, 786, '• Priority 1: Prior halt (no human reopen) or Gov block', 16, '#2C3E50')}
        ${txt(96, 820, '✗ MCP rug-pull, CaMeL sink, Lethal Trifecta or Cedar', 16, '#922B21', 700)}
        ${txt(96, 856, '  revoke strictly dominates retry & convergence', 16, '#922B21', 700)}
        ${txt(96, 896, '✗ Halted loop CANNOT self-reset budget or cycle history', 16, '#922B21', 700)}
        ${txt(96, 932, '✓ Resuming requires non-self human reopen endorsement', 16, '#1B5E20', 700)}
        ${txt(96, 968, 'Lean: governanceBlock_dominates_retry_and_convergence', 15, '#922B21', 800)}

        ${arrow('M732 852H796', '#5B4B8A')}

        <rect x="796" y="706" width="652" height="292" rx="16" fill="#F7F5FD" stroke="#5B4B8A" stroke-width="2.5"/>
        ${txt(820, 746, 'Full Governed Turn & Red-Team Closure', 19, '#4A3B99', 800)}
        ${txt(820, 786, '• ContextAssemblyPipeline (AST/L3/MINJA/KV-Prefix)', 16, '#2C3E50')}
        ${txt(820, 820, '• MCP Manifest Pin + CaMeL Sink + MindGuard Audit', 16, '#2C3E50')}
        ${txt(820, 860, '✓ GovernedFunflowRunner (CAS singleflight + nono-sandbox)', 16, '#1B5E20', 700)}
        ${txt(820, 896, '✓ Deterministic zero-LLM AuditCapsule per turn', 16, '#1B5E20', 700)}
        ${txt(820, 932, '✓ 7 Lean theorems + exhaustive TLC (354 states, q=0)', 16, '#1B5E20', 700)}
        ${txt(820, 968, '✓ 8-class deterministic red-team benchmark verified', 16, '#1B5E20', 800)}
      </g>

      ${txt(48, 1084, 'Slice 56 Closure: Guarantees universal bounded loop termination inside the 17-Slice Assurance Chain.', 19, '#244957', 700)}
    </svg>`,
    css: '[data-vector-surface]{display:block;max-width:100%;height:auto}',
  };
};

interface StorySpec {
  slug: string;
  view: string;
  modelFile: string;
  title: string;
  composer: FigureComposer;
}

const stories: readonly StorySpec[] = [
  {
    slug: '40-verification-dispatch',
    view: 'ContextGovernanceFigures::verificationDispatch',
    modelFile: '40-context-governance-boundary.sysml',
    title: 'SysML v2 Master Verification Dispatch: Lean Algebraic Laws vs Quint Concurrent Races',
    composer: composeVerificationDispatchStory,
  },
  {
    slug: '42-declassification',
    view: 'ContextGovernanceFigures::declassification',
    modelFile: '42-multi-repo-multi-agent-declassification.sysml',
    title: 'Cross-repository Context sharing and controlled declassification',
    composer: composeDeclassificationStory,
  },
  {
    slug: '43-security-branches',
    view: 'ContextGovernanceFigures::securityBranches',
    modelFile: '43-ascent-security-branch-omission-refinement.sysml',
    title: 'ASCENT security branches under OmittedAlternativesReceipt',
    composer: composeSecurityBranchesStory,
  },
  {
    slug: '44-causal-survival',
    view: 'ContextGovernanceFigures::causalSurvival',
    modelFile: '44-temporal-causal-survival-and-memory-quotient.sysml',
    title: 'Temporal Causality survival spine and audited memory quotients',
    composer: composeCausalSurvivalStory,
  },
  {
    slug: '45-hybrid-search',
    view: 'ContextGovernanceFigures::hybridSearch',
    modelFile: '45-org-sexpr-gql-candidate-exchange-search.sysml',
    title: 'ORG Element S-expression selector, GQL relationships, and CandidateExchange',
    composer: composeHybridSearchStory,
  },
  {
    slug: '46-sandbox-trifecta',
    view: 'ContextGovernanceFigures::sandboxAxes',
    modelFile: '46-durable-agenda-session-sandbox-governance.sysml',
    title: 'Durable Agenda wake, Session crash scout, and Sandbox Lethal-Trifecta lock',
    composer: composeSandboxTrifectaStory,
  },
  {
    slug: '47-end-to-end-capsule',
    view: 'ContextGovernanceFigures::endToEndPipeline',
    modelFile: '47-end-to-end-context-governance-assurance-closure.sysml',
    title: 'End-to-end Context Governance closure and zero-LLM Audit Capsule',
    composer: composeEndToEndPipelineStory,
  },
  {
    slug: '48-progressive-disclosure',
    view: 'ContextGovernanceFigures::progressiveDisclosure',
    modelFile: '48-progressive-disclosure-and-two-stage-org-repair.sysml',
    title: 'ASCENT Progressive Disclosure (L0-L3) and Two-Stage ORG AST Repair',
    composer: composeProgressiveDisclosureStory,
  },
  {
    slug: '49-shared-context-detours',
    view: 'ContextGovernanceFigures::sharedContextDetours',
    modelFile: '49-scoped-detour-funflow-concurrent-shared-context.sysml',
    title: 'Zero-SubAgent Shared Org Context, 4-Exit Scoped Detours, and 3-State FunFlow',
    composer: composeSharedContextDetoursStory,
  },
  {
    slug: '50-detour-confinement-audit',
    view: 'ContextGovernanceFigures::detourConfinementAudit',
    modelFile: '50-literature-frontier-detour-confinement-and-causal-audit.sysml',
    title: 'APPA Scoped Detour Taint Confinement and NeuroTaint Offline Causal Audit',
    composer: composeDetourConfinementAuditStory,
  },
  {
    slug: '51-memory-quarantine-kv-prefix',
    view: 'ContextGovernanceFigures::memoryQuarantineKvPrefix',
    modelFile: '51-memory-poisoning-quarantine-and-kv-prefix-serialization.sysml',
    title: 'Memory Poisoning Quarantine and Two-Zone KV-Prefix-Stable Serialization',
    composer: composeMemoryQuarantineKvPrefixStory,
  },
  {
    slug: '52-funflow-cas-sandbox',
    view: 'ContextGovernanceFigures::funflowCasSandbox',
    modelFile: '52-funflow-cas-singleflight-and-external-sandbox-binding.sysml',
    title: 'FunFlow CAS Singleflight, Fail-Closed Premise Invalidation, Pinned GC and External Sandbox',
    composer: composeFunflowCasSandboxStory,
  },
  {
    slug: '53-c4-profile-convergence',
    view: 'ContextGovernanceFigures::c4ProfileConvergence',
    modelFile: '53-yuanxu-c4-profile-convergence-and-interface-slots.sysml',
    title: 'Two-Tier Yuanxu Interface, POO Slot-Observation and C4 Profile Convergence',
    composer: composeC4ProfileConvergenceStory,
  },
  {
    slug: '54-durable-work-core-challenge',
    view: 'ContextGovernanceFigures::durableWorkCoreChallenge',
    modelFile: '54-durable-work-engine-core-challenge.sysml',
    title: 'Pure Durable Work Engine Core Formal Challenge: 5 Real Bugs Repaired',
    composer: composeDurableWorkCoreChallengeStory,
  },
  {
    slug: '55-mcp-tool-poisoning-camel',
    view: 'ContextGovernanceFigures::mcpToolPoisoningCamel',
    modelFile: '55-mcp-tool-poisoning-and-camel-capability-flow.sysml',
    title: 'MCP Tool Poisoning, Rug-Pull Pinning, Shadowing & CaMeL Capability Flow',
    composer: composeMcpToolPoisoningCamelStory,
  },
  {
    slug: '56-ascent-loop-termination',
    view: 'ContextGovernanceFigures::ascentLoopTermination',
    modelFile: '56-ascent-governed-loop-termination.sysml',
    title: 'ASCENT-Governed Loop Engine Termination, Anti-Oscillation & Safety Dominance',
    composer: composeAscentLoopTerminationStory,
  },
];

const sources: Record<string, string> = {};
async function capture(absolute: string): Promise<string> {
  const relative = path.relative(root, absolute).split(path.sep).join('/');
  sources[relative] = await readFile(absolute, 'utf8');
  return relative;
}

const viewFile = await capture(path.join(directory, 'governance-figures.sysml'));
await capture(path.join(directory, 'governance-illustrations.ts'));
await capture(path.join(directory, 'illustration.ts'));
const allChainModelFiles = [
  '40-context-governance-boundary.sysml',
  '41-epistemic-consolidation-governance.sysml',
  '42-multi-repo-multi-agent-declassification.sysml',
  '43-ascent-security-branch-omission-refinement.sysml',
  '44-temporal-causal-survival-and-memory-quotient.sysml',
  '45-org-sexpr-gql-candidate-exchange-search.sysml',
  '46-durable-agenda-session-sandbox-governance.sysml',
  '48-progressive-disclosure-and-two-stage-org-repair.sysml',
  '49-scoped-detour-funflow-concurrent-shared-context.sysml',
  '50-literature-frontier-detour-confinement-and-causal-audit.sysml',
  '51-memory-poisoning-quarantine-and-kv-prefix-serialization.sysml',
  '52-funflow-cas-singleflight-and-external-sandbox-binding.sysml',
  '53-yuanxu-c4-profile-convergence-and-interface-slots.sysml',
  '54-durable-work-engine-core-challenge.sysml',
  '55-mcp-tool-poisoning-and-camel-capability-flow.sysml',
  '56-ascent-governed-loop-termination.sysml',
  '47-end-to-end-context-governance-assurance-closure.sysml',
];
const modelRelatives = await Promise.all(allChainModelFiles.map(f => capture(path.join(contextDir, f))));

const connection = await connect({version: 'v0.11.0', requireCapabilities: ['render_view']});
const browser = await chromium.launch();
try {
  const parsed = await connection.parseSources(
    [viewFile, ...modelRelatives].map(name => [name, sources[name]!] as const),
  );
  parsed.raiseForErrors();

  for (const story of stories) {
    const modelRef = path.relative(root, path.join(contextDir, story.modelFile)).split(path.sep).join('/');
    const question = {ref: story.slug, text: story.title, focusRefs: ['model']};
    const selection: FigureInput['view'] = {
      source: 'dev/d2/governance-illustrations.ts',
      title: story.title,
      purpose: 'architecture',
      kind: 'system',
      question,
      basis: {captureRef: 'local-sdk-render', modelRefs: [modelRef, viewFile], obligationRefs: [], evidenceRefs: []},
    };
    const sdkCapture = await captureOpenSysMLView(connection, parsed.hash, story.view);
    const projected = projectOpenSysMLView(sdkCapture, {selection, layout: 'reflow', portProjection: 'owner'});
    const input: FigureInput = {
      model: projected.model,
      modelTrace: projected.trace,
      sources,
      references: {model: modelRef},
      view: selection,
      questions: [question],
      language: 'en',
      width: 1520,
      presentation: {options: {'elk.direction': 'RIGHT', 'elk.edgeRouting': 'ORTHOGONAL'}},
      theme: composePresentationTheme(['ocean'], presentationThemeLayers),
    };
    const figure = composeFigure(input, story.composer);
    const result = await exportFigure(figure, browser, {
      scale: 1,
      minimumTextSize: 12,
      pngCompression: {palette: true, quality: 95, effort: 7},
      attribution: {
        copyright: [
          '2026 tao3k team and Contributors',
          '2026 hardenedlinux Linux Team and Contributors',
          '2016 The Inter Project Authors (https://github.com/rsms/inter)',
        ],
        license: 'Apache-2.0 AND LGPL-2.1-or-later AND OFL-1.1',
      },
    });
    const outPrefix = path.join(directory, 'output', story.slug);
    await mkdir(path.dirname(outPrefix), {recursive: true});
    await writeFile(outPrefix + '.svg', result.svg[0]!);
    await writeFile(outPrefix + '.png', result.png);
    const docFigure = path.join(contextDir, 'figures', story.slug + '.png');
    await mkdir(path.dirname(docFigure), {recursive: true});
    await writeFile(docFigure, result.png);
    if (result.webp) await writeFile(outPrefix + '.webp', result.webp);
    await writeFile(outPrefix + '.html', result.html);
    await writeFile(
      outPrefix + '.receipt.json',
      JSON.stringify({sdk: connection.info, sourceSHA256: figure.sourceSHA256, rendering: result.receipt}, null, 2) + '\n',
    );
    console.log(
      JSON.stringify({
        story: story.slug,
        readability: result.receipt.readability,
        width: result.receipt.width,
        height: result.receipt.height,
        pngCompression: result.receipt.pngCompression.figure,
        webp: result.receipt.webp?.encoding,
        preferredRaster: result.receipt.preferredRaster,
      }),
    );
  }
} finally {
  await browser.close();
  await connection.close();
}
