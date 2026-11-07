;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session tool and hook permission predicates.

(import :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy-core
        :agentic-ai-lab/modules/session/policy-tool-grant)

(export agentic-ai-lab-session-tool-permission-policy-allows?
        agentic-ai-lab-session-hook-tool-permission-policy-allows?)

;; : (-> PooSessionPolicy Symbol Symbol Boolean)
(def (agentic-ai-lab-session-tool-permission-policy-allows? policy
                                                      tool-ref
                                                      action)
  (agentic-ai-lab-session-require "session tool permission requires a policy"
                            (agentic-ai-lab-session-policy? policy)
                            policy)
  (and (eq? (agentic-ai-lab-session-policy-kind policy)
            'agent-tool-permission)
       (not (agentic-ai-lab-session-policy-match?
             tool-ref
             (agentic-ai-lab-session-policy-slot policy
                                           'denied-tool-refs
                                           '())))
       (agentic-ai-lab-session-tool-grants-allow?
        (agentic-ai-lab-session-policy-slot policy 'tool-grants '())
        tool-ref
        action)))

;; : (-> PooSessionPolicy Symbol Symbol Symbol Boolean)
(def (agentic-ai-lab-session-hook-tool-permission-policy-allows? policy
                                                           hook-event
                                                           tool-ref
                                                           action)
  (agentic-ai-lab-session-require "session hook tool permission requires a policy"
                            (agentic-ai-lab-session-policy? policy)
                            policy)
  (and (eq? (agentic-ai-lab-session-policy-kind policy)
            'hook-tool-permission)
       (agentic-ai-lab-session-policy-match?
        hook-event
        (agentic-ai-lab-session-policy-slot policy 'hook-events '()))
       (agentic-ai-lab-session-tool-grants-allow?
        (agentic-ai-lab-session-policy-slot policy 'tool-grants '())
        tool-ref
        action)))
