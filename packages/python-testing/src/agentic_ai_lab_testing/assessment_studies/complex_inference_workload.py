# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Compound finite reasoning tasks; independent set oracle and executable contracts."""
import hashlib
import random
from . import inference_reuse_study as s

FAMILIES = ('four-hop-shared-witness', 'recursive-clean-bridge',
            'scoped-union-recursive-branch', 'all-targets-positive-reach')
QUESTIONS = {
 FAMILIES[0]: 'Return actor x iff there is a directed mentor walk of EXACTLY FOUR edges x->p->q->r->z, and z and an actor t in target appear in the SAME film f whose director has at least one selected_country. That supporting film f must not be banned_film. In addition, x must have NO appearance in ANY banned film. Intermediate actors may repeat; x need not act in f. Nationality belongs to the director, not the actors. All joins in this witness must use the same f, director and t.',
 FAMILIES[1]: 'Return actor x iff x reaches an actor z through ONE OR MORE directed mentor edges, and z and a target actor t appear in the SAME film f whose director has a selected_country; f must not be banned. Neither x nor z may appear in ANY banned film. Paths may traverse banned-film actors in intermediate positions: the actor-wide exclusion applies ONLY to x and z. Cycles are allowed; a zero-edge identity path is not sufficient.',
 FAMILIES[2]: 'Return the UNION of two branches. LEFT: x has an EXACTLY FOUR-edge directed mentor walk to z, where z and a target actor share a film f with a selected-country director; f is not banned, and x has NO appearance in ANY banned film. RIGHT: x has a ONE-OR-MORE-edge directed mentor path to a target actor, and x acts in some film g with a selected-country director, where this supporting g is not banned. The right branch has NO actor-wide banned-film exclusion: a different banned appearance must not remove x from RIGHT. The two branches may have different witnesses. Preserve local and branch exclusion scope before taking the union.',
 FAMILIES[3]: 'Return actors x in actor_domain that can reach EVERY actor t in target through ONE OR MORE directed mentor edges, and that share at least one unbanned film f with a target actor, where the director of that same f has a selected_country. This is universal coverage over the entire target relation, NOT existence of one reachable target. x must have NO appearance in ANY banned film. A target actor requires a positive-length path to itself; identity alone does not count. Cycles count as positive paths. For an empty target set the reachability condition is vacuous, but the coappearance condition still requires a target witness.'}


def workload(family, seed):
    rng=random.Random(seed)
    def ids(kind,n):
        return [kind+'_'+hashlib.sha256(f'{seed}:{kind}:{i}'.encode()).hexdigest()[:12] for i in range(n)]
    actors,films,directors,countries=ids('actor',96),ids('film',32),ids('director',8),ids('country',4)
    rows={name:[] for name in s.SCHEMA}
    rows['actor_domain']=[[a] for a in actors]
    rows['selected_country']=[[countries[0]],[countries[1]]]
    rows['directed']=[[f,directors[i%8]] for i,f in enumerate(films)]
    rows['citizen']=[[d,countries[i%4]] for i,d in enumerate(directors)]
    # Multiple nationalities make existential country qualification observable.
    rows['citizen'] += [[directors[3],countries[0]],[directors[7],countries[1]]]
    for block in range(16):
        a=actors[block*6:block*6+6];f,g=films[block*2:block*2+2]
        rows['mentor'] += [[a[i],a[i+1]] for i in range(5)]
        if block%3==0:rows['mentor'] += [[a[2],a[1]],[a[5],a[5]]]
        if block%2==0:rows['mentor'].append([a[3],a[0]])
        rows['cast'] += [[f,a[i]] for i in (0,2,4,5)]+[[g,a[i]] for i in (1,3,4,5)]
        if block%4==0:rows['banned_film'].append([g])
    # Cross-component paths create shared dependencies without dense all-pairs output.
    rows['mentor'] += [[actors[b*6+5],actors[(b+1)*6]] for b in range(15)]
    rows['target']=[[actors[b*6+5]] for b in (3,7,11,15)]
    for values in rows.values():rng.shuffle(values)
    source={'domains':dict(Actor=actors,Film=films,Director=directors,Country=countries),'rows':rows}
    return {'name':FAMILIES[family]+f'-seed-{seed}', 'family':FAMILIES[family],
            'question':QUESTIONS[FAMILIES[family]]+' Use only the supplied finite relations. Return unique actor identifiers.',
            'source':source, 'withdrawal':{'relation':'mentor','row':[actors[94],actors[95]]},
            'complexity':{'actors':96,'films':32,'directors':8,'countries':4,
                          'sourceFacts':sum(map(len,rows.values())), 'opaqueEntityIds':True,
                          'operators':['shared-witness joins','four-edge walks','positive recursive closure',
                                       'scoped negation','actor-wide anti-existence','union','universal target coverage'][0:]}}


def expected(case, source):
    rows=source['rows'];edges=set(map(tuple,rows['mentor']));cast=set(map(tuple,rows['cast']))
    banned={f for f, in rows['banned_film']};targets={t for t, in rows['target']}
    selected={c for c, in rows['selected_country']}
    films={f for f,d in rows['directed'] for dd,c in rows['citizen'] if d==dd and c in selected and f not in banned}
    excluded={a for f,a in cast if f in banned}
    coactors={z for f,z in cast if f in films and any((f,t) in cast for t in targets)}
    adjacency={a:set() for a, in rows['actor_domain']}
    for x,y in edges:adjacency[x].add(y)
    reach=set()
    for x in adjacency:
        seen=set();pending=list(adjacency[x])
        while pending:
            z=pending.pop()
            if z in seen:continue
            seen.add(z);pending.extend(adjacency[z]-seen)
        reach.update((x,z) for z in seen)
    four=set(edges)
    for _ in range(3):four={(x,z) for x,y in four for z in adjacency[y]}
    left={x for x,z in four if z in coactors and x not in excluded}
    family=case['family']
    if family==FAMILIES[0]:answer=left
    elif family==FAMILIES[1]:answer={x for x,z in reach if z in coactors and x not in excluded and z not in excluded}
    elif family==FAMILIES[2]:
        local={a for f,a in cast if f in films}
        answer=left|{x for x,t in reach if t in targets and x in local}
    else:answer={x for x, in rows['actor_domain'] if x in coactors and x not in excluded and all((x,t) in reach for t in targets)}
    return [[a] for a in sorted(answer)]


def oracle_contract(case):
    a,p,q,r,z,t,f,d,c=[s.var(v) for v in ('a','p','q','r','z','t','f','d','c')]
    atom,rule=s.atom,s.rule
    relations=[{'name':'excluded','types':['Actor']},{'name':'qualified','types':['Film']},
               {'name':'coactor','types':['Actor','Actor','Film']},
               {'name':'reachable','types':['Actor','Actor']},
               {'name':'four','types':['Actor','Actor']},
               {'name':'left_witness','types':['Actor','Actor','Actor','Film']}]
    rules=[rule(atom('excluded',a),atom('cast',f,a),atom('banned_film',f)),
           rule(atom('qualified',f),atom('directed',f,d),atom('citizen',d,c),atom('selected_country',c),atom('banned_film',f,negative=True)),
           rule(atom('coactor',z,t,f),atom('cast',f,z),atom('cast',f,t),atom('target',t),atom('qualified',f)),
           rule(atom('reachable',a,z),atom('mentor',a,z)),
           rule(atom('reachable',a,z),atom('reachable',a,p),atom('mentor',p,z)),
           rule(atom('four',a,z),atom('mentor',a,p),atom('mentor',p,q),atom('mentor',q,r),atom('mentor',r,z)),
           rule(atom('left_witness',a,z,t,f),atom('four',a,z),atom('coactor',z,t,f),atom('excluded',a,negative=True))]
    family=case['family']
    if family in (FAMILIES[0],FAMILIES[2]):rules.append(rule(atom('answer',a),atom('left_witness',a,z,t,f)))
    if family==FAMILIES[1]:
        relations.append({'name':'clean_witness','types':['Actor','Actor','Actor','Film']})
        body=[atom('reachable',a,z),atom('coactor',z,t,f),atom('excluded',a,negative=True),atom('excluded',z,negative=True)]
        rules += [rule(atom('clean_witness',a,z,t,f),*body),rule(atom('answer',a),atom('clean_witness',a,z,t,f))]
    if family==FAMILIES[2]:rules.append(rule(atom('answer',a),atom('reachable',a,t),atom('target',t),atom('cast',f,a),atom('qualified',f)))
    if family==FAMILIES[3]:
        relations.append({'name':'missing_target','types':['Actor','Actor']})
        relations.append({'name':'incomplete','types':['Actor']})
        rules += [rule(atom('missing_target',a,t),atom('actor_domain',a),atom('target',t),atom('reachable',a,t,negative=True)),
                  rule(atom('incomplete',a),atom('missing_target',a,t)),
                  rule(atom('answer',a),atom('actor_domain',a),atom('coactor',a,t,f),atom('excluded',a,negative=True),atom('incomplete',a,negative=True))]
    return {'relations':relations,'rules':rules}
