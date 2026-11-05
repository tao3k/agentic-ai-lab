;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .ref .call)
        (only-in :std/io/tempfile call-with-temporary-file-name current-temporary-directory)
        (only-in :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-pack journal-hash))
(export context-workspace-text-endpoint)

;; The deployment supplies a private workspace or a writer fence shared by
;; all writers. A matching preimage alone cannot establish repeat safety.
(def (context-workspace-text-endpoint scope)
  (let* ((root (.ref scope 'workspace))
         (name (.ref scope 'path))
         (scope-value (.ref scope 'scope-digest)))
    (unless (and (string? root) (string? name)
                 (< 0 (string-length name) 257)
                 (not (member name '("." "..")))
                 (not (ormap (lambda (c) (memv c '(#\/ #\\ #\nul))) (string->list name))))
      (error "Workspace endpoint requires a direct child path"))
    (let (path (path-expand name root))
      (def (read-current)
        (unless (eq? 'regular (file-info-type (file-info path #f)))
          (error "Workspace effect requires an existing regular text file"))
        (call-with-input-file path
          (lambda (port)
            (let* ((buffer (make-string 65537))
                   (length (read-substring buffer 0 65537 port)))
              (when (> length 65536) (error "Workspace text exceeds the effect limit"))
              (substring buffer 0 length)))))
      (def (scoped-effect intent)
        (let* ((body (.ref intent 'body))
               (effect (.ref body 'effect))
               (input (.ref (.ref body 'attempt) 'input)))
          (and (equal? root (.ref effect 'workspace))
               (equal? name (.ref effect 'path))
               (equal? scope-value (.ref input 'scope-digest))
               effect)))
      (def (apply-original intent)
        (.call scope .with-writer scope
          (lambda ()
            (let* ((effect (or (scoped-effect intent) (error "Workspace intent scope mismatch")))
                   (before (read-current))
                   (desired (.ref effect 'desired)))
              (unless (equal? before (.ref effect 'before)) (error "Workspace preimage changed"))
              (parameterize ((current-temporary-directory root))
                (call-with-temporary-file-name ".context-write-"
                  (lambda (temporary)
                    (call-with-output-file temporary (lambda (port) (display desired port)))
                    (rename-file temporary path #t))))
              (let ((after (read-current)) (command-id (.ref intent 'identity)))
                (unless (equal? after desired) (error "Workspace write readback changed"))
                (journal-pack (.o kind: 'context.workspace-write-observation.v1
                                 command: command-id workspace: root path: name
                                 before-digest: (journal-hash before)
                                 after-digest: (journal-hash after))))))))
      (.o workspace: root path: name scope-digest: scope-value
          .read!: (lambda (self)
            (.call scope .with-writer scope
              (lambda ()
                (let* ((bytes-value (read-current)) (current (read-current)))
                  (.o bytes: bytes-value coherent?: (equal? bytes-value current))))))
          .retry-premises: (lambda (self original predecessor)
            (let (effect (scoped-effect original))
              (if effect
                (.call scope .retry-premises scope original predecessor)
                (.o current-permission?: #f repeat-safe?: #f))))
          .apply!: (lambda (self intent) (apply-original intent))
          .dispatch-retry!: (lambda (self command original handoff)
            (unless handoff (error "Workspace retry requires a consumed issuer handoff"))
            (apply-original original))))))
