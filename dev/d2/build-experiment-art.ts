// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import type {FigureContext} from '@deterministic-engineering/render';
import {illustrationAssets} from './illustration';

// Fresh visual metaphors for this build experiment. These drawings do not
// form a global logo registry: another subject can supply another composer.
export function buildExperimentArt(context: FigureContext) {
  const {txt} = illustrationAssets(context);
  const shadow = '<ellipse cx="120" cy="159" rx="111" ry="13" fill="#31566410"/>';
  const passed = (x: number, y: number) => `<g transform="translate(${x} ${y})">
    ${shadow}
    <path d="M17 150V22H81M22 30L75 82M22 82L75 30" fill="none" stroke="#86A7AF" stroke-width="7" stroke-linecap="round"/>
    <path d="M81 22H123V47" fill="none" stroke="#86A7AF" stroke-width="6"/>
    <path d="M118 47Q118 60 129 54" fill="none" stroke="#86A7AF" stroke-width="4"/>
    <path d="M60 124Q125 16 198 124" fill="none" stroke="#3D9D90" stroke-width="13"/>
    <path d="M64 119H203M63 120V151M202 120V151M102 73V119M157 73V119" stroke="#80BDB0" stroke-width="8" fill="none"/>
    <path d="M44 150H222" stroke="#BED8D2" stroke-width="11" stroke-linecap="round"/>
    <circle cx="197" cy="34" r="31" fill="#DFEFE8" stroke="#3D9D90" stroke-width="3"/>
    <path d="M181 34L193 46L214 19" fill="none" stroke="#3D9D90" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
  </g>`;
  const failed = (x: number, y: number) => `<g transform="translate(${x} ${y})">
    ${shadow}
    <rect x="13" y="30" width="211" height="111" rx="15" fill="#FFF9EC" stroke="#D5B078" stroke-width="3"/>
    <path d="M30 122H89L107 98L119 137L139 114H207" fill="none" stroke="#C5964D" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M30 105H206" stroke="#E4D6B8" stroke-width="3" stroke-dasharray="6 8"/>
    <path d="M32 140V157M202 140V157" stroke="#A7BFC3" stroke-width="8"/>
    <path d="M155 55L182 10L209 55Z" fill="#F5DFB4" stroke="#C5964D" stroke-width="3" stroke-linejoin="round"/>
    <path d="M182 27V39" stroke="#A57C3D" stroke-width="4" stroke-linecap="round"/>
    <circle cx="182" cy="47" r="2.7" fill="#A57C3D"/>
    <path d="M55 59L65 69M65 59L55 69" stroke="#C5964D" stroke-width="4" stroke-linecap="round"/>
  </g>`;
  const oldArtifacts = (x: number, y: number, conflicted: boolean) => `<g transform="translate(${x} ${y})">
    ${shadow}
    <path d="M27 36H203V142H27Z" fill="#EDF2F4" stroke="#93ACB6" stroke-width="3"/>
    <path d="M27 88H203" stroke="#93ACB6" stroke-width="3"/>
    <rect x="42" y="52" width="62" height="24" rx="5" fill="#A8C3D0"/>
    <rect x="114" y="52" width="72" height="24" rx="5" fill="#C8D9DD"/>
    <rect x="42" y="105" width="89" height="24" rx="5" fill="#C5B8D6"/>
    <rect x="143" y="105" width="43" height="24" rx="5" fill="#D8C9A8"/>
    <path d="M41 26Q53 5 68 19M82 19Q95-3 107 12" fill="none" stroke="#B7C9CB" stroke-width="3" stroke-dasharray="4 6"/>
    <circle cx="199" cy="36" r="31" fill="#FAFCFA" stroke="${conflicted ? '#C5964D' : '#8CAABB'}" stroke-width="3"/>
    <path d="M199 18V37L211 43" fill="none" stroke="#8CAABB" stroke-width="3" stroke-linecap="round"/>
    ${conflicted ? '<path d="M15 159H76M91 159H153" stroke="#3D9D90" stroke-width="5"/><path d="M153 159H223" stroke="#C5964D" stroke-width="5"/>' : ''}
    <circle cx="19" cy="72" r="26" fill="#FAFCFA" stroke="${conflicted ? '#C5964D' : '#9296BF'}" stroke-width="3"/>
    ${txt(19, 82, '?', 30, conflicted ? '#AA7D39' : '#77709E', 700, 'middle')}
  </g>`;
  const mismatch = (x: number, y: number) => `<g transform="translate(${x} ${y})">
    ${shadow}
    <path d="M0 120Q35 120 46 87" fill="none" stroke="#A9C3D3" stroke-width="11"/>
    <path d="M194 87Q206 120 240 120" fill="none" stroke="#C5B9D7" stroke-width="11"/>
    <rect x="33" y="50" width="63" height="72" rx="13" fill="#83A9C1"/>
    <path d="M96 68H115M96 86H115M96 104H115" stroke="#AEC7D4" stroke-width="8" stroke-linecap="round"/>
    <rect x="150" y="50" width="63" height="72" rx="13" fill="#A39BC0"/>
    <rect x="157" y="69" width="11" height="29" rx="5" fill="#E9E6F4"/>
    <path d="M133 57L125 76L140 92L129 113" fill="none" stroke="#D1AA69" stroke-width="4" stroke-linecap="round"/>
    <circle cx="125" cy="18" r="28" fill="#FAFCFA" stroke="#9296BF" stroke-width="3"/>
    ${txt(125, 28, '?', 30, '#77709E', 700, 'middle')}
  </g>`;
  const investigate = (x: number, y: number, candidate: boolean) => `<g transform="translate(${x} ${y})">
    ${shadow}
    <path d="M15 83L36 50H199L223 83" fill="#E7E4F2" stroke="#9F98BB" stroke-width="3"/>
    <path d="M15 83H223V146Q223 154 215 154H23Q15 154 15 146Z" fill="#CAC6DF" stroke="#9F98BB" stroke-width="3"/>
    <path d="M84 52V36Q84 25 96 25H141Q154 25 154 36V52" fill="none" stroke="#9F98BB" stroke-width="6"/>
    <rect x="102" y="103" width="34" height="19" rx="6" fill="#F8F7FC"/>
    <path d="M54 83L44 20L61 10L77 23L67 84" fill="#A8C9D6" stroke="#83A9BE" stroke-width="3" stroke-linejoin="round"/>
    <circle cx="169" cy="50" r="29" fill="#FAFCFA" fill-opacity=".8" stroke="${candidate ? '#3D9D90' : '#9296BF'}" stroke-width="6"/>
    <path d="M190 73L208 94" stroke="${candidate ? '#3D9D90' : '#9296BF'}" stroke-width="9" stroke-linecap="round"/>
    ${candidate ? '<path d="M154 50L165 61L184 38" stroke="#3D9D90" stroke-width="5" fill="none" stroke-linecap="round" stroke-linejoin="round"/>' : txt(169, 59, '?', 28, '#77709E', 700, 'middle')}
  </g>`;
  const explore = (x: number, y: number) => `<g transform="translate(${x} ${y})">
    <ellipse cx="121" cy="165" rx="112" ry="13" fill="#31566410"/>
    <path d="M108 93L52 158M108 93L167 158M108 93V165" stroke="#8EA6B0" stroke-width="8" stroke-linecap="round"/>
    <path d="M43 79L143 20L168 61L67 119Z" fill="#A69BC4" stroke="#847DA5" stroke-width="3"/>
    <path d="M56 87L69 110M135 26L158 65" stroke="#CFC8E0" stroke-width="10"/>
    <ellipse cx="157" cy="40" rx="14" ry="25" transform="rotate(-29 157 40)" fill="#DDEFE9" stroke="#6C9E9C" stroke-width="4"/>
    <path d="M165 15L211-10M180 47L237 39" stroke="#B0A5CB" stroke-width="2.5" stroke-dasharray="5 6"/>
    <path d="M219-19L222-10L232-7L222-4L219 5L216-4L206-7L216-10Z" fill="#D6B576"/>
    <path d="M238 19L241 27L249 30L241 33L238 41L235 33L227 30L235 27Z" fill="#A6C8D0"/>
    <circle cx="201" cy="67" r="12" fill="#ECE8F6" stroke="#B0A5CB" stroke-width="2"/>
    ${txt(122, 206, 'Model exploration', 24, '#77709E', 700, 'middle')}
  </g>`;
  return {passed, failed, oldArtifacts, mismatch, investigate, explore};
}
