;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Expected: strategy profile descriptors are reused by combinators.

(import (only-in :clan/poo/object .o .ref))

(def strategy-profile-family
  (.o (kind 'strategy-profile-family)
      (name 'strategy-profile-family)
      (source 'agentic-ai-lab.performance.strategy-profile)))

(def (strategy-profile profile-name tool-policy-value memory-value handoff-value)
  (.o (family 'strategy-profile-family)
      (name profile-name)
      (tool-policy tool-policy-value)
      (memory memory-value)
      (handoff handoff-value)))

(def base-profile
  (strategy-profile 'research-agent 'scoped 'session 'runtime))

(def composed-profile
  (.o (:extends base-profile)
      (proof 'required)
      (retry 'bounded)))

(def (strategy-profile-hot-loop profile rounds)
  (let (tool-policy-value (.ref profile 'tool-policy))
    (let loop ((round 0) (accepted 0))
      (if (>= round rounds)
        accepted
        (loop (+ round 1)
              (if tool-policy-value (+ accepted 1) accepted))))))
