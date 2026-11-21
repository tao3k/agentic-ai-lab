# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Provider output grammar for the finite Scheme relation contract."""
import copy
import json


def compact_request(request,source_identity):
    """Compile intent against an explicit ABI; execution retains source rows."""
    result=copy.deepcopy(request)
    instruction,context=result['input'][0]['content'].split('\n',1)
    public=json.loads(context)
    if 'gold' in public or 'expected' in public:raise ValueError('private answers in compiler context')
    for name in ('facts','domains','materializedViews'):public.pop(name,None)
    public['sourceIdentity']=source_identity
    public['viewDefinitions']={
        'eligible':'eligible(c,f,d,a) iff cast(f,a) AND directed(f,d) AND citizen(d,c).',
        'coactor':'coactor(x,g,a) iff anchor(x) AND cast(g,x) AND cast(g,a).'}
    public['executionBoundary']='Finite data and exact materialized view values remain in Scheme. Compile question intent; never enumerate actor answers or source rows.'
    result['input'][0]['content']=instruction+'\n'+json.dumps(public,ensure_ascii=False,sort_keys=True)
    result['text']={'format':output_format()}
    return result


def output_format():
    def object(properties,required):
        return {'type':'object','properties':properties,'required':required,'additionalProperties':False}
    text={'type':'string'}
    term={'anyOf':[object({'var':text},['var']),object({'const':text},['const'])]}
    atom={'relation':text,'terms':{'type':'array','items':term,'maxItems':16}}
    head=object(atom,['relation','terms'])
    body=object({**atom,'not':{'type':'boolean'}},['relation','terms'])
    relation=object({'name':text,'types':{'type':'array','items':{'enum':['Film','Actor','Director','Country']},
                                        'minItems':1,'maxItems':16}},['name','types'])
    rule=object({'head':{'type':'array','items':head,'minItems':1},
                 'body':{'type':'array','items':body,'minItems':1}},['head','body'])
    schema=object({'relations':{'type':'array','items':relation,'maxItems':128},
                   'rules':{'type':'array','items':rule,'maxItems':128}},['relations','rules'])
    return {'type':'json_schema','name':'ascent_relation_contract','schema':schema}
