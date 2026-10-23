;;; -*- Gerbil -*-
;;; Boundary: negative load! fixture.
;;; Importing this module must fail before object contributions are accepted.
;;; The harness trusts this fixture to prove load! propagates object contracts.

(import :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/workflow/scenario/configuration/init-syntax)

;;; The negative fixture must fail through the user-facing loader path, so the
;;; test keeps load! as the observable boundary instead of importing the part.
;; : [AgenticAILabModuleObject]
(load! "parts/object1")
