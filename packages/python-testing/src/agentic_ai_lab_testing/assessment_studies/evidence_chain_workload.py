# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""New compound structures and shuffled entities, with an independent BFS oracle."""
import hashlib,random
from . import inference_reuse_study as s

FAMILIES=('mutual-cycle-clean-witness','universal-target-safe-escape',
          'per-target-recursive-coappearance','cycle-or-universal-two-hop')
QUESTIONS=(
 'Return actor x iff x has a POSITIVE directed mentor path to z AND z has a POSITIVE directed mentor path back to x; z shares the SAME unbanned film f with a target actor t, and the director of f has a selected country. x must have NO appearance in ANY banned film. Intermediate actors and z may have other banned appearances. A zero-length identity path never qualifies; a real nonempty cycle does.',
 'Return actor x iff x has a POSITIVE directed mentor path to EVERY target actor, x acts in at least one unbanned film with a selected-country director, and there is NO actor b such that x positively reaches b, b appears in a banned film, and b has NO positive mentor path to ANY target. The exclusion concerns a reachable dead-end banned actor, not any banned actor on any path. x itself need not be globally clean. For an empty target set the universal condition is vacuous but the dead-end and film conditions still apply.',
 'Return globally clean actors x (NO appearance in ANY banned film) such that for EVERY target t there exists an actor z and film f with a POSITIVE mentor path x->z, a direct mentor edge z->t, and x and z both appearing in the SAME unbanned f whose director has a selected country. The z and f witnesses may differ for different targets. One target witness cannot stand in for coverage of all targets. x must also act in some unbanned selected-country film, including when target is empty.',
 'Return the UNION of two independently scoped branches. LEFT: x is globally clean and x and z positively mentor-reach each other, while z shares an unbanned selected-country film with a target actor. RIGHT: for EVERY target t there is an EXACTLY TWO-edge mentor walk x->p->t, and x shares an unbanned selected-country film with some target actor. RIGHT has NO global banned-appearance exclusion: an unrelated banned appearance must not remove x from RIGHT. Different targets may use different p; repeated vertices are allowed. Positive cycles count for LEFT; zero-edge identities do not.')


def workload(family,seed):
    rng=random.Random(seed)
    def ids(kind,n):return [kind+'_'+hashlib.sha256(f'chain:{seed}:{kind}:{i}'.encode()).hexdigest()[:12] for i in range(n)]
    actors,films,directors,countries=ids('actor',120),ids('film',40),ids('director',10),ids('country',5)
    rows={n:[] for n in s.SCHEMA};rows['actor_domain']=[[a] for a in actors]
    edges=set()
    for block in range(15):
        start=block*8
        for i in range(7):edges.add((start+i,start+i+1))
        if block%3!=2:edges.add((start+7,start))
        edges.add((start+1,start+5));edges.add((start+6,start+3))
        if block<14:edges.add((start+7,start+8))
    # Independent nonlocal chords; this topology is not the old six-node corpus.
    for _ in range(24):
        x,y=rng.randrange(120),rng.randrange(120)
        if x!=y:edges.add((x,y))
    rows['mentor']=[[actors[x],actors[y]] for x,y in sorted(edges)]
    rows['cast']=[[film,a] for film in films for a in rng.sample(actors,6)]
    rows['directed']=[[film,directors[rng.randrange(10)]] for film in films]
    rows['citizen']=[[director,countries[i%5]] for i,director in enumerate(directors)]
    rows['citizen'] += [[directors[3],countries[0]],[directors[9],countries[2]]]
    rows['selected_country']=[[countries[i]] for i in (0,2)]
    rows['banned_film']=[[film] for film in rng.sample(films,8)]
    rows['target']=[[actors[i*15+7]] for i in range(8)]
    for values in rows.values():rng.shuffle(values)
    source={'domains':dict(Actor=actors,Film=films,Director=directors,Country=countries),'rows':rows}
    return {'name':FAMILIES[family]+f'-seed-{seed}','family':FAMILIES[family],
            'question':QUESTIONS[family]+' Use only the supplied finite relations; return unique original actor identifiers or a checked unary result reference.',
            'source':source,'complexity':{'actors':120,'films':40,'directors':10,'countries':5,'targets':8,'sourceFacts':sum(map(len,rows.values()))}}


def expected(case,source):
    rows=source['rows'];adj={a:set() for a, in rows['actor_domain']}
    for a,b in rows['mentor']:adj[a].add(b)
    reach={}
    for a in adj:
        seen=set();pending=list(adj[a])
        while pending:
            b=pending.pop()
            if b in seen:continue
            seen.add(b);pending.extend(adj[b]-seen)
        reach[a]=seen
    cast=set(map(tuple,rows['cast']));banned={f for f, in rows['banned_film']};targets={t for t, in rows['target']}
    selected={c for c, in rows['selected_country']}
    films={f for f,d in rows['directed'] for dd,c in rows['citizen'] if dd==d and c in selected and f not in banned}
    dirty={a for f,a in cast if f in banned};local={a for f,a in cast if f in films}
    support={z for f,z in cast if f in films and any((f,t) in cast for t in targets)}
    mutual={x for x in adj if x not in dirty and any(z in support and x in reach[z] for z in reach[x])}
    family=case['family']
    if family==FAMILIES[0]:answer=mutual
    elif family==FAMILIES[1]:
        dead={b for b in dirty if not reach[b]&targets}
        answer={x for x in local if targets<=reach[x] and not reach[x]&dead}
    elif family==FAMILIES[2]:
        answer={x for x in local-dirty if all(any(t in adj[z] and any((f,x) in cast and (f,z) in cast for f in films) for z in reach[x]) for t in targets)}
    else:
        two={x:{z for y in adj[x] for z in adj[y]} for x in adj}
        answer=mutual|{x for x in support if targets<=two[x]}
    return [[a] for a in sorted(answer)]


def oracle_contract(case):
    atom,rule=s.atom,s.rule
    x,y,z,t,f,d,c,b=[s.var(n) for n in ('x','y','z','t','f','d','c','b')]
    declarations=[('reach',['Actor','Actor']),('dirty',['Actor']),('film_ok',['Film']),
                  ('local',['Actor']),('support',['Actor']),('mutual',['Actor'])]
    rules=[rule(atom('reach',x,y),atom('mentor',x,y)),rule(atom('reach',x,z),atom('reach',x,y),atom('mentor',y,z)),
           rule(atom('dirty',x),atom('cast',f,x),atom('banned_film',f)),
           rule(atom('film_ok',f),atom('directed',f,d),atom('citizen',d,c),atom('selected_country',c),atom('banned_film',f,negative=True)),
           rule(atom('local',x),atom('cast',f,x),atom('film_ok',f)),
           rule(atom('support',z),atom('cast',f,z),atom('cast',f,t),atom('target',t),atom('film_ok',f)),
           rule(atom('mutual',x),atom('reach',x,z),atom('reach',z,x),atom('support',z),atom('dirty',x,negative=True))]
    family=case['family']
    if family in (FAMILIES[0],FAMILIES[3]):rules.append(rule(atom('answer',x),atom('mutual',x)))
    if family==FAMILIES[1]:
        declarations += [('escape',['Actor']),('dead',['Actor']),('unsafe',['Actor']),('missing',['Actor'])]
        rules += [rule(atom('escape',b),atom('reach',b,t),atom('target',t)),
                  rule(atom('dead',b),atom('dirty',b),atom('escape',b,negative=True)),
                  rule(atom('unsafe',x),atom('reach',x,b),atom('dead',b)),
                  rule(atom('missing',x),atom('actor_domain',x),atom('target',t),atom('reach',x,t,negative=True)),
                  rule(atom('answer',x),atom('local',x),atom('missing',x,negative=True),atom('unsafe',x,negative=True))]
    if family==FAMILIES[2]:
        declarations += [('covered',['Actor','Actor']),('missing',['Actor'])]
        rules += [rule(atom('covered',x,t),atom('reach',x,z),atom('mentor',z,t),atom('target',t),atom('cast',f,x),atom('cast',f,z),atom('film_ok',f)),
                  rule(atom('missing',x),atom('actor_domain',x),atom('target',t),atom('covered',x,t,negative=True)),
                  rule(atom('answer',x),atom('local',x),atom('dirty',x,negative=True),atom('missing',x,negative=True))]
    if family==FAMILIES[3]:
        declarations += [('two',['Actor','Actor']),('missing_two',['Actor'])]
        rules += [rule(atom('two',x,t),atom('mentor',x,y),atom('mentor',y,t)),
                  rule(atom('missing_two',x),atom('actor_domain',x),atom('target',t),atom('two',x,t,negative=True)),
                  rule(atom('answer',x),atom('support',x),atom('missing_two',x,negative=True))]
    return {'relations':[{'name':n,'types':types} for n,types in declarations],'rules':rules}
