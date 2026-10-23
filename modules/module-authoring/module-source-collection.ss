;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Agentic AI Lab maintained source roots and precedence, not collection mechanics.
(import (only-in :clan/poo/object .o)
        :yuanxu/module-system/source/collection
        (only-in :agentic-ai-lab/modules/module-authoring/source-policy
                 AgenticAILabModuleStylePolicy))
(export agentic-ai-lab-maintained-module-source agentic-ai-lab-maintained-integration-directories agentic-ai-lab-default-module-load-path
        make-agentic-ai-lab-contribution-module-load-path)

(def agentic-ai-lab-maintained-integration-directories
  '("building" "evidence-assessment" "module-authoring" "testing" "workflow"))

(def agentic-ai-lab-maintained-module-source
  (.o (:: @ (make-yuanxu-module-source-collection
   'agentic-ai-lab-maintained 'agentic-ai-lab "." "modules"
   style-policy: AgenticAILabModuleStylePolicy))
      excluded-directories: agentic-ai-lab-maintained-integration-directories))

(def (make-agentic-ai-lab-contribution-module-load-path identity-value
                                                  source-root-value)
  ;; A selected contribution owns its module names. Its source must win a
  ;; collision with a maintained module of the same name.
  (make-yuanxu-module-load-path
   identity-value
   (cons (make-yuanxu-contribution-module-source
          identity-value source-root-value style-policy: AgenticAILabModuleStylePolicy)
         (yuanxu-module-load-path-collections
          agentic-ai-lab-default-module-load-path))))

(def agentic-ai-lab-default-module-load-path
  (make-yuanxu-module-load-path
   'agentic-ai-lab-default
   (list agentic-ai-lab-maintained-module-source)))
