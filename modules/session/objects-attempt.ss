;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Inert scheduling proposals. Runtime ownership and producer admission are separate.
(import (only-in :clan/poo/object .o))
(export SessionInputRef. SessionTask. SessionAttempt. SessionSchedule.)
(def SessionInputRef.
  (.o kind: 'agentic-ai-lab.session.input-ref.v1 producer: #f contract: #f
      identity: #f digest: #f scope-digest: #f source-vector-digest: #f
      query-digest: #f restriction-digest: #f profile-digest: #f
      receipt-ref: #f consumer-session: #f consumer-turn: 0 complete?: #f))
(def SessionTask.
  (.o kind: 'agentic-ai-lab.session.task.v1 identity: #f revision: 0
      input: #f anchor-refs: '()))
(def SessionAttempt.
  (.o kind: 'agentic-ai-lab.session.attempt.v1 session: #f task: #f task-revision: 0
      identity: #f generation: 0 turn: 0 request: #f input: #f anchor-refs: '()))
(def SessionSchedule.
  (.o kind: 'agentic-ai-lab.session.schedule.v1 identity: #f revision: 0
      generation: 0 status: 'idle active: #f obligations: '() completed: '()))
