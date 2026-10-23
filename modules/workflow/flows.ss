;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public facade for workflow feature flows and Funflow tutorial alignment.
;;; Invariant: alignment reports and workflow builders live in leaf owners.

(import :agentic-ai-lab/modules/workflow/flows-alignment-specs
        :agentic-ai-lab/modules/workflow/flows-alignment-report
        :agentic-ai-lab/modules/workflow/flows-builders)

(export make-docker-store-run-config
        agentic-ai-lab-funflow-tutorial-alignment-schema
        agentic-ai-lab-funflow-tutorial-alignment-spec-kind
        agentic-ai-lab-funflow-tutorial-alignment-report-kind
        agentic-ai-lab-funflow-tutorial-alignment-spec
        agentic-ai-lab-funflow-tutorial-alignment-spec?
        agentic-ai-lab-funflow-tutorial-alignment-report?
        agentic-ai-lab-funflow-tutorial-alignment-spec-id
        agentic-ai-lab-funflow-tutorial-alignment-spec-status
        agentic-ai-lab-funflow-tutorial-alignment-specs
        agentic-ai-lab-funflow-tutorial-alignment-report
        make-ccompilation-flow
        make-ccompilation-store-workflow
        make-tensorflow-train-flow
        make-tensorflow-inference-flow
        make-tensorflow-workflow
        make-makefile-tool-parse-flow
        make-makefile-tool-run-flow
        make-makefile-tool-workflow
        make-makefile-tool-runtime-arguments
        make-makefile-tool-runtime-command-descriptor)
