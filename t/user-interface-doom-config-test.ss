;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .all-slots .ref)
        (only-in :std/test check-equal? test-suite)
        (only-in :poo-flow/modules/workflow/scenario/case poo-flow-scenario-case?)
        :poo-flow/modules/workflow/scenario/accessors
        :yuanxu/module-system/source/collection
        (only-in :poo-flow/modules/module-authoring/module-source-collection make-poo-flow-contribution-module-load-path poo-flow-default-module-load-path poo-flow-maintained-module-source)
        (only-in :yuanxu/module-system/source/objects
                 yuanxu-module-source-ref-value)
        (only-in :poo-flow/user-interface/profiles/langchain langchain)
        (only-in :poo-flow/user-interface/scenarios/langchain/scenario
                 langchain-scenario)
        (only-in :poo-flow/user-interface/scenarios/tool-calling-agent-loop/scenario
                 tool-calling-agent-loop-scenario)
        :poo-flow/user-interface/config)

(export user-interface-doom-config-test)

(def user-interface-doom-config-test
  (test-suite
   "Doom-style User Interface roots"
   (yuanxu-test-case
    "config directly composes reusable Profiles across three stages"
    (check-equal?
     (poo-flow-scenario-case? default-agent-control-plane) #t)
    (check-equal?
     (poo-flow-scenario-case-name default-agent-control-plane)
     'default-agent-control-plane)
    (check-equal?
     (length (poo-flow-scenario-case-modules default-agent-control-plane)) 2)
    (check-equal?
     (length (poo-flow-scenario-case-profiles default-agent-control-plane)) 19)
    (check-equal?
     (.all-slots
      (poo-flow-scenario-case-stages default-agent-control-plane))
     '(development staging production)))
   (yuanxu-test-case
    "Profile and Scenario libraries retain explicit import paths"
    (check-equal? (.ref (.ref langchain 'memory) 'name)
                  'langchain-stateless-memory)
    (check-equal? (poo-flow-scenario-case? langchain-scenario) #t)
    (check-equal? (poo-flow-scenario-case? tool-calling-agent-loop-scenario)
                  #t))
   (yuanxu-test-case
    "custom modules expose one admitted interface entry"
    (let* ((collection
            (make-yuanxu-module-source-collection
             'user-custom 'user "user-interface" "custom"))
           (sources (yuanxu-module-source-collection-interfaces collection)))
      (check-equal? (map yuanxu-module-source-ref-value sources)
                    (list (path-expand "user-interface/custom/my-module/interface.ss")))))))
