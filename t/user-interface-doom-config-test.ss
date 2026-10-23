;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .all-slots .ref)
        (only-in :std/test check-equal? test-suite)
        (only-in :agentic-ai-lab/modules/workflow/scenario/case agentic-ai-lab-scenario-case?)
        :agentic-ai-lab/modules/workflow/scenario/accessors
        :yuanxu/module-system/source/collection
        (only-in :agentic-ai-lab/modules/module-authoring/module-source-collection make-agentic-ai-lab-contribution-module-load-path agentic-ai-lab-default-module-load-path agentic-ai-lab-maintained-module-source)
        (only-in :yuanxu/module-system/source/objects
                 yuanxu-module-source-ref-value)
        (only-in :agentic-ai-lab/user-interface/profiles/langchain langchain)
        (only-in :agentic-ai-lab/user-interface/scenarios/langchain/scenario
                 langchain-scenario)
        (only-in :agentic-ai-lab/user-interface/scenarios/tool-calling-agent-loop/scenario
                 tool-calling-agent-loop-scenario)
        :agentic-ai-lab/user-interface/config)

(export user-interface-doom-config-test)

(def user-interface-doom-config-test
  (test-suite
   "Doom-style User Interface roots"
   (yuanxu-test-case
    "config directly composes reusable Profiles across three stages"
    (check-equal?
     (agentic-ai-lab-scenario-case? default-agent-control-plane) #t)
    (check-equal?
     (agentic-ai-lab-scenario-case-name default-agent-control-plane)
     'default-agent-control-plane)
    (check-equal?
     (length (agentic-ai-lab-scenario-case-modules default-agent-control-plane)) 2)
    (check-equal?
     (length (agentic-ai-lab-scenario-case-profiles default-agent-control-plane)) 19)
    (check-equal?
     (.all-slots
      (agentic-ai-lab-scenario-case-stages default-agent-control-plane))
     '(development staging production)))
   (yuanxu-test-case
    "Profile and Scenario libraries retain explicit import paths"
    (check-equal? (.ref (.ref langchain 'memory) 'name)
                  'langchain-stateless-memory)
    (check-equal? (agentic-ai-lab-scenario-case? langchain-scenario) #t)
    (check-equal? (agentic-ai-lab-scenario-case? tool-calling-agent-loop-scenario)
                  #t))
   (yuanxu-test-case
    "custom modules expose one admitted interface entry"
    (let* ((collection
            (make-yuanxu-module-source-collection
             'user-custom 'user "user-interface" "custom"))
           (sources (yuanxu-module-source-collection-interfaces collection)))
      (check-equal? (map yuanxu-module-source-ref-value sources)
                    (list (path-expand "user-interface/custom/my-module/interface.ss")))))))
