;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native runtime handoff manifest projections.

(import (only-in :clan/poo/object .o .ref object?)
        :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/tool-core/objects-spec
        :agentic-ai-lab/modules/tool-core/objects-support)

(export +agentic-ai-lab-tool-core-handoff-manifest-kind+
        agentic-ai-lab-tool-handoff-manifest
        agentic-ai-lab-tool-handoff-manifest?
        agentic-ai-lab-tool-handoff-manifest->alist)

(def +agentic-ai-lab-tool-core-handoff-manifest-kind+
  'agentic-ai-lab.tool-core.handoff-manifest)

;; : (-> Symbol PooToolSpec [Alist] PooToolHandoffManifest)
(def (agentic-ai-lab-tool-handoff-manifest request-id spec . maybe-metadata)
  (agentic-ai-lab-session-require "tool handoff request id must be a symbol"
                            (symbol? request-id)
                            request-id)
  (agentic-ai-lab-session-require "tool handoff requires a tool spec"
                            (agentic-ai-lab-tool-spec? spec)
                            spec)
  (let* ((sandbox-required?
          (agentic-ai-lab-tool-spec-sandbox-required? spec))
         (sandbox-profile-ref
          (agentic-ai-lab-tool-spec-sandbox-profile-ref spec))
         (diagnostics
          (if (agentic-ai-lab-tool-valid-sandbox-profile-ref?
               sandbox-required?
               sandbox-profile-ref)
            '()
            (list
             (agentic-ai-lab-tool-field-rows
              (cons 'code 'tool-spec-missing-sandbox-profile)
              (cons 'tool-ref (agentic-ai-lab-tool-spec-ref spec))
              (cons 'severity 'error)))))
         ;; `.o` treats a bare identifier matching its slot as self dispatch.
         ;; Capture every local that crosses the object boundary first.
         (request-id-value request-id)
         (sandbox-required-value sandbox-required?)
         (sandbox-profile-ref-value sandbox-profile-ref)
         (diagnostic-values diagnostics)
         (metadata-value
          (if (null? maybe-metadata) '() (car maybe-metadata))))
    (.o (kind +agentic-ai-lab-tool-core-handoff-manifest-kind+)
        (schema 'agentic-ai-lab.modules.tool-core.handoff-manifest.v1)
        (request-id request-id-value)
        (tool-ref (agentic-ai-lab-tool-spec-ref spec))
        (tool-kind (agentic-ai-lab-tool-spec-tool-kind spec))
        (actions (agentic-ai-lab-tool-spec-actions spec))
        (operation (.ref spec 'handoff-operation))
        (input-schema (.ref spec 'input-schema))
        (output-schema (.ref spec 'output-schema))
        (runtime-owner (.ref spec 'runtime-owner))
        (runtime-backend (.ref spec 'runtime-backend))
        (sandbox-required? sandbox-required-value)
        (sandbox-profile-ref sandbox-profile-ref-value)
        (handoff-ready? (null? diagnostic-values))
        (diagnostic-count (length diagnostic-values))
        (diagnostics diagnostic-values)
        (runtime-executed #f)
        (metadata metadata-value))))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-tool-handoff-manifest? value)
  (and (object? value)
       (eq? (.ref value 'kind)
            +agentic-ai-lab-tool-core-handoff-manifest-kind+)))

;; : (-> PooToolHandoffManifest Alist)
(defpoo-final-projection
  agentic-ai-lab-tool-handoff-manifest->alist (manifest)
  (bindings ((checked-manifest
              (agentic-ai-lab-session-require
               "tool handoff projection requires a handoff manifest"
               (agentic-ai-lab-tool-handoff-manifest? manifest)
               manifest))))
  (fields ((kind (.ref checked-manifest 'kind))
           (schema (.ref checked-manifest 'schema))
           (request-id (.ref checked-manifest 'request-id))
           (tool-ref (.ref checked-manifest 'tool-ref))
           (tool-kind (.ref checked-manifest 'tool-kind))
           (actions (.ref checked-manifest 'actions))
           (operation (.ref checked-manifest 'operation))
           (input-schema (.ref checked-manifest 'input-schema))
           (output-schema (.ref checked-manifest 'output-schema))
           (runtime-owner (.ref checked-manifest 'runtime-owner))
           (runtime-backend (.ref checked-manifest 'runtime-backend))
           (sandbox-required? (.ref checked-manifest 'sandbox-required?))
           (sandbox-profile-ref (.ref checked-manifest 'sandbox-profile-ref))
           (handoff-ready? (.ref checked-manifest 'handoff-ready?))
           (diagnostic-count (.ref checked-manifest 'diagnostic-count))
           (diagnostics (.ref checked-manifest 'diagnostics))
           (runtime-executed (.ref checked-manifest 'runtime-executed))
           (metadata (.ref checked-manifest 'metadata)))))
