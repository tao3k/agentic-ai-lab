# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Responses SSE transport with a deadline measured only by content progress."""
import asyncio
import json
import time


class ContentTimeout(RuntimeError):
    pass


async def consume_lines(lines, record, *, emit=lambda _: None, idle_seconds=5.0,
                        started=None, total_seconds=90.0, content_event='response.output_text.delta'):
    if content_event not in ('response.output_text.delta', 'response.function_call_arguments.delta'):
        raise ValueError('only text or function arguments count as genuine content')
    record['progressKind'] = content_event
    started = time.monotonic() if started is None else started
    last = started
    record.update(raw='', events=[], contentGapsSeconds=[])
    iterator = lines.__aiter__()
    terminal = False
    while True:
        remaining = min(last + idle_seconds, started + total_seconds) - time.monotonic()
        if remaining <= 0:
            raise ContentTimeout('five seconds without genuine content or total deadline exceeded')
        try:
            line = await asyncio.wait_for(iterator.__anext__(), remaining)
        except asyncio.TimeoutError as error:
            raise ContentTimeout('five seconds without genuine content or total deadline exceeded') from error
        except StopAsyncIteration:
            break
        if not line.startswith('data:'):
            continue
        event = json.loads(line[5:].strip())
        now = time.monotonic()
        kind = event.get('type', '')
        record['events'].append({'type': kind, 'seconds': now - started})
        if kind == content_event and event.get('delta'):
            record['raw'] += event['delta']
            if event['delta'].strip():
                record['contentGapsSeconds'].append(now - last)
                last = now
                emit(event['delta'])
        elif kind in ('response.completed', 'response.incomplete', 'response.failed'):
            response = event['response']
            record.update(responseId=response.get('id'), responseModel=response.get('model'),
                          responseStatus=response.get('status'), usage=response.get('usage'))
            if content_event == 'response.function_call_arguments.delta':
                record['toolCalls'] = [item for item in response.get('output', [])
                                       if item.get('type') == 'function_call']
            terminal = True
            break
    record['seconds'] = time.monotonic() - started
    if (not terminal or record.get('responseStatus') != 'completed'
            or not record['raw'].strip() or not record.get('responseId')):
        raise RuntimeError('provider omitted a complete content result')
    return record['raw']


async def predict(request, key, record, *, emit=lambda _: None,
                  content_event='response.output_text.delta'):
    import httpx
    started = time.monotonic()
    async with httpx.AsyncClient(timeout=httpx.Timeout(5.0), follow_redirects=False) as client:
        context = client.stream('POST', 'https://api.deepseek.com/responses',
                                headers={'Authorization': 'Bearer ' + key}, json=request)
        remaining = 5.0 - (time.monotonic() - started)
        try:
            response = await asyncio.wait_for(context.__aenter__(), max(0, remaining))
        except asyncio.TimeoutError as error:
            raise ContentTimeout('five seconds without genuine content while connecting') from error
        try:
            if response.is_error:
                body = (await response.aread()).decode('utf-8', 'replace')
                record['providerError'] = body.replace(key, '[REDACTED]')[:4096]
            response.raise_for_status()
            return await consume_lines(response.aiter_lines(), record, started=started, emit=emit, content_event=content_event)
        finally:
            await context.__aexit__(None, None, None)
