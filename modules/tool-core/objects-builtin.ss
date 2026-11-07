;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: builtin tool specs and default tool catalog.

(import :agentic-ai-lab/modules/tool-core/objects-spec
        :agentic-ai-lab/modules/tool-core/objects-catalog)

(export agentic-ai-lab-tool-core-builtin-read-workspace-file
        agentic-ai-lab-tool-core-builtin-write-workspace-file
        agentic-ai-lab-tool-core-builtin-run-shell-command
        agentic-ai-lab-tool-core-mcp-tool
        agentic-ai-lab-tool-core-default-catalog)

;; : PooToolSpec
(def agentic-ai-lab-tool-core-builtin-read-workspace-file
  (agentic-ai-lab-tool-spec
   'read-workspace-file
   'builtin-filesystem
   '(read)
   '((path . string) (mode . read-only))
   '((content-ref . artifact) (summary . string))
   "marlin-agent-core"
   'tool/read-workspace-file
   #t
   'agent/nono
   'marlin-tool-adapter
   '((builtin . #t))))

;; : PooToolSpec
(def agentic-ai-lab-tool-core-builtin-write-workspace-file
  (agentic-ai-lab-tool-spec
   'write-workspace-file
   'builtin-filesystem
   '(write)
   '((path . string) (content . string))
   '((artifact-ref . artifact))
   "marlin-agent-core"
   'tool/write-workspace-file
   #t
   'agent/nono
   'marlin-tool-adapter
   '((builtin . #t))))

;; : PooToolSpec
(def agentic-ai-lab-tool-core-builtin-run-shell-command
  (agentic-ai-lab-tool-spec
   'run-shell-command
   'builtin-command
   '(run)
   '((argv . list) (cwd . string))
   '((exit-status . integer) (stdout-ref . artifact) (stderr-ref . artifact))
   "marlin-agent-core"
   'tool/run-shell-command
   #t
   'agent/nono
   'marlin-tool-adapter
   '((builtin . #t))))

;; : (-> Symbol Symbol [Symbol] Alist Alist [Alist] PooToolSpec)
(def (agentic-ai-lab-tool-core-mcp-tool tool-ref
                                  server-ref
                                  actions
                                  input-schema
                                  output-schema
                                  . maybe-metadata)
  (agentic-ai-lab-tool-spec
   tool-ref
   'mcp
   actions
   input-schema
   output-schema
   "mcp-runtime"
   'tool/mcp-call
   #f
   #f
   server-ref
   (if (null? maybe-metadata) '() (car maybe-metadata))))

;; : PooToolCatalog
(def agentic-ai-lab-tool-core-default-catalog
  (agentic-ai-lab-tool-catalog
   'tool-core/default
   (list agentic-ai-lab-tool-core-builtin-read-workspace-file
         agentic-ai-lab-tool-core-builtin-write-workspace-file
         agentic-ai-lab-tool-core-builtin-run-shell-command)
   '((source . agentic-ai-lab-tool-core)
     (runtime-executed . #f))))
