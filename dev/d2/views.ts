// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

import {composeDiagram, composeHeading, type FigureComposer, type FigureModel} from '@deterministic-engineering/render';

const states: Readonly<Record<string, readonly [string, string, string]>> = {
  open: ['1  Open', 'Interaction can continue', 'reference'],
  closing: ['2  Closing', 'Wait for unfinished work to settle', 'pending'],
  closed: ['3  Closed', 'Continue in a new Session', 'evidence'],
};
export function sessionLabels(model: FigureModel): FigureModel {
  return {...model, subjects: model.subjects.map(node => ({...node,
    label: states[node.sourceName ?? '']?.slice(0, 2).join('\n') ?? node.label,
  })), relations: model.relations.map(edge => ({...edge,
    label: edge.label === 'accept CloseRequested' ? 'Close requested'
      : edge.label === 'accept ClosureQualified' ? 'Closure conditions met' : edge.label,
  }))};
}
export const composeSession: FigureComposer = context => {
  // Show the three named states; the SDK still retains the initial marker.
  const nodes = ['open', 'closing', 'closed'].map(name => {
    const node = context.model!.subjects.find(node => node.sourceName === name);
    if (!node) throw new Error('Missing Session state: ' + name);
    return node;
  });
  const scene = composeDiagram(context, {
    graph: {id: 'session-flow', children: nodes.map(node => ({id: node.id})),
      layoutOptions: {'elk.algorithm': 'layered', 'elk.direction': 'RIGHT', 'elk.edgeRouting': 'ORTHOGONAL'}},
    icons: Object.fromEntries(nodes.map(node => [node.id, states[node.sourceName!]![2]])),
    roles: {[nodes[1]!.id]: 'knowledge', [nodes[2]!.id]: 'focus'},
  });
  return page(context, scene,
    'Context manages information; an independent Session owns the interaction lifecycle.',
    'A stop request starts closing. Required evidence permits closure; a closed Session cannot reopen.');
};

function page(context: Parameters<FigureComposer>[0], scene: ReturnType<typeof composeDiagram>, introduction: string, takeaway: string) {
  const title = composeHeading(context, {role: 'title', text: context.view.title, questionRef: context.view.question.ref});
  const intro = composeHeading(context, {role: 'answer', text: introduction});
  const note = composeHeading(context, {role: 'note', text: takeaway});
  return {markup: `<main><header>${title.markup}${intro.markup}</header>${scene.markup}<footer>${note.markup}</footer></main>`,
    css: title.css + scene.css + '[data-figure]{padding:var(--gutter)}header{margin-bottom:var(--gap)}footer{margin-top:var(--gap)}.scene-label:has(text:empty){display:none}'};
}
