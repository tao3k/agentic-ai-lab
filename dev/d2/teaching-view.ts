// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import {composeDiagram, composeHeading, graphFromModel, type FigureComposer} from '@deterministic-engineering/render';

/** A reusable relation projection. ASCENT supplies the selected objects and
 * qualified explanatory edges and solver constraints. All global coordinates
 * and routes come from the upstream browser-measured ELK renderer. */
export const composeTeaching: FigureComposer = context => {
  const {items, links, attachments, regions, composition, intro, options} = context.presentation as {
    items: readonly (readonly string[])[]; links: readonly (readonly string[])[];
    attachments: readonly (readonly string[])[]; regions: readonly {id:string;label:string;visible:boolean;options:readonly (readonly [string,string])[]}[]; composition:{edges:readonly {id:string;options:readonly (readonly [string,string])[]}[]}; intro: string; options: Record<string,string>;
  };
  const t = context.text;
  const wrap = (value: string, width: number): string[] => value.split('\n').flatMap(line => {
    const lines: string[] = []; let current = '';
    for (const word of line.split(/\s+/)) {
      if (current && current.length + word.length + 1 > width) {lines.push(current);current = '';}
      current += (current ? ' ' : '') + word;
    }
    if (current) lines.push(current);return lines;
  });
  const graph = graphFromModel(context.model!, options);
  const configure = (nodes: NonNullable<typeof graph.children>) => {
    for (const node of nodes) {
      const region=regions.find(g=>g.id===node.id);
      if(region)node.layoutOptions=Object.fromEntries(region.options);
      if(node.children)configure(node.children);
    }
  };
  configure(graph.children!);
  graph.edges = context.model!.relations.filter(edge => links.find(l => l[0] === edge.id)?.[5] !== 'negation')
    .map(edge=>({id:edge.id,sources:[edge.src],targets:[edge.dst],layoutOptions:Object.fromEntries(composition.edges.find(e=>e.id===edge.id)?.options??[])}));
  const scene = composeDiagram(context, {graph}, node => {
    const item = items.find(row => row[0] === node.id)!;
    const [identity, , , , glyph, title, explanation] = item;
    const copy = [...wrap(title!, 29).map(line => [line, 'scene-title']), ...wrap(explanation!, 32).map(line => [line, 'scene-detail'])];
    const start = glyph ? 194 : 0;
    let y = start + copy.length * 27 + 4;
    const notes: string[] = [];
    const appendNotes = (parent: string) => {
      for (const [child, owner] of attachments) if (owner === parent) {
        const note = items.find(row => row[0] === child)!;
        const lines = [...wrap(note[5]!, 31), ...wrap(note[6]!, 33)];
        const top = y; y += lines.length * 24 + 12;
        notes.push(`<g data-explanation-id="${t(child!)}" data-question="${t(note[1]!)}" data-facet="${t(note[2]!)}" data-source-ref="${t(note[3]!)}"><path d="M7 ${top-15}V${y-16}" stroke="#D8A85A" stroke-width="4"/><text text-anchor="middle" font-size="18" fill="#927241">${lines.map((line,i)=>`<tspan data-text-line x="150" y="${top+i*24}">${t(line)}</tspan>`).join('')}</text></g>`);
        appendNotes(child!);
      }
    };
    appendNotes(identity!);
    for (const link of links.filter(l=>l[1]===identity && l[5]==='negation')) {
      const lines=wrap(link[4]!,28),top=y+7;y+=lines.length*24+20;
      notes.push(`<g data-explanation-id="${t(link[0]!)}"><path d="M12 ${top-14}L30 ${top+4}M30 ${top-14}L12 ${top+4}" stroke="#C77D70" stroke-width="4"/><text fill="#B56D62" font-size="20" text-anchor="middle">${lines.map((line,i)=>`<tspan data-text-line x="170" y="${top+i*24}">${t(line)}</tspan>`).join('')}</text></g>`);
    }
    return `${glyph ? `<svg class="mechanism-art" x="0" y="0" width="300" height="167" viewBox="0 0 360 200" preserveAspectRatio="xMidYMin meet">${context.glyph(identity!)}</svg>` : ''}<text text-anchor="middle">${copy.map(([line,style],index)=>`<tspan data-text-line class="${style}" x="150" y="${start + index * 27}">${t(line!)}</tspan>`).join('')}</text>${notes.join('')}`;
  });
  let markup = scene.markup;
  for (const region of regions) markup=markup.replace(`data-scene-node="${t(region.id)}"`, `data-scene-node="${t(region.id)}" data-explanation-region="${region.visible ? 'visible' : 'layout'}"`);
  for (const item of items) markup = markup.replace(`data-scene-node="${t(item[0]!)}"`,
    `data-scene-node="${t(item[0]!)}" data-question="${t(item[1]!)}" data-facet="${t(item[2]!)}" data-source-ref="${t(item[3]!)}" data-depiction="${item[4] ? 'object' : 'annotation'}"`);
  for (const link of links) {
    markup = markup.replace(`data-scene-edge="${t(link[0]!)}"`, `data-scene-edge="${t(link[0]!)}" data-edge-style="${t(link[5]!)}"`);
    const lines = wrap(link[4]!, 21);
    markup = markup.replace(`<text>${t(link[4]!)}</text>`, `<text>${lines.map((line,i)=>`<tspan x="0" dy="${i ? 24 : 0}">${t(line)}${i<lines.length-1?' ':''}</tspan>`).join('')}</text>`);
  }
  const headings = [composeHeading(context,{role:'title',text:context.view.title}),
    composeHeading(context,{role:'note',text:intro})];
  return {markup:`<main class="mechanism-view"><header>${headings.map(h=>h.markup).join('')}</header>${markup}</main>`,
    css:scene.css+headings.map(h=>h.css).join('\n')+`
      [data-figure]{padding:24px;background:#FAFCFA}.mechanism-view header{margin-bottom:12px}
      .mechanism-art>svg{width:360px;height:200px}.scene-frame{fill:none!important;stroke:none!important}[data-explanation-region="visible"]>.scene-frame{fill:#EEF7F5!important;stroke:#B7D3CC!important;rx:24}.scene-group-title{font-size:24px;fill:#285664;font-weight:650}
      [data-depiction="annotation"]>.scene-frame{fill:#FBF3E5!important;stroke:#D8C49C!important;stroke-dasharray:5 5}
      [data-edge-style="constraint"]{--edge-color:#9C8C65}[data-edge-style="support"]{--edge-color:#7D92A8}
      [data-edge-style="admitted"]{--edge-color:#268E88}[data-edge-style="unchanged"]{--edge-color:#C77D70}
      .scene-edge{stroke:var(--edge-color,var(--accent));stroke-width:2.6}
      [data-edge-style="constraint"] .scene-edge{stroke-dasharray:7 6}
      [data-edge-style="flow"] .scene-edge,[data-edge-style="support"] .scene-edge,[data-edge-style="admitted"] .scene-edge{stroke-dasharray:none}
      [data-edge-style="unchanged"] .scene-edge{stroke-dasharray:5 4}
      .scene-label text{fill:var(--edge-color,var(--ink))}.scene-label rect{fill:#FAFCFA}
      .scene-title{font-size:22px}.scene-detail{font-size:20px}.mechanism-art text{font-family:inherit}
    `};
};
