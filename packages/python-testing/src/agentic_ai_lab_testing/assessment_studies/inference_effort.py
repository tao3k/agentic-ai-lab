# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Work until the first independently verified answer, including failed attempts."""


def until_verified(attempts):
    """One immutable question/source identity; diagnostics remain labelled adaptive.

    Model output_tokens includes reasoning tokens. Never use visible answer bytes
    as the reasoning-work denominator. A zero-model-call execution has zero model
    tokens; missing usage on an actual model call is unknown, never zero.
    """
    totals={'attempts':0,'modelCalls':0,'inputTokens':0,'outputIncludingReasoningTokens':0,
            'observedReasoningTokens':0,'reasoningUsageComplete':True,
            'modelUsageComplete':True,'schemeSeconds':0.0,'verified':False,
            'firstVerifiedAttempt':None,'adaptive':False}
    for index,attempt in enumerate(attempts,1):
        totals['attempts']+=1
        calls=attempt['providerCalls'];totals['modelCalls']+=calls
        totals['adaptive'] |= attempt.get('adaptive',False)
        totals['schemeSeconds']+=attempt.get('schemeSeconds',0.0)
        usage=attempt.get('usage')
        if calls and not usage:
            totals['modelUsageComplete']=False;totals['reasoningUsageComplete']=False
        elif calls:
            totals['inputTokens']+=usage['input_tokens']
            totals['outputIncludingReasoningTokens']+=usage['output_tokens']
            reasoning=usage.get('output_tokens_details',{}).get('reasoning_tokens')
            if reasoning is None:totals['reasoningUsageComplete']=False
            else:totals['observedReasoningTokens']+=reasoning
        if attempt['correct']:
            totals.update(verified=True,firstVerifiedAttempt=index)
            break
    totals['totalModelTokens']=totals['inputTokens']+totals['outputIncludingReasoningTokens'] if totals['modelUsageComplete'] else None
    return totals


def paired_reduction(baseline,candidate,metric):
    """A failed trajectory is censored, not an inexpensive correct answer."""
    if not baseline['verified'] or not candidate['verified']:return None
    if metric=='totalModelTokens' and (not baseline['modelUsageComplete'] or not candidate['modelUsageComplete']):return None
    if metric=='observedReasoningTokens' and (not baseline['reasoningUsageComplete'] or not candidate['reasoningUsageComplete']):return None
    denominator=baseline[metric]
    return 1-candidate[metric]/denominator if denominator else None


def primary_trajectories(records):
    """Raw one-attempt trials do not establish multi-round convergence gains."""
    result={}
    for record in records:
        key=(record['case'],record['repetition'],record['phase'],record['arm'])
        result[key]=until_verified([record])
    return result
