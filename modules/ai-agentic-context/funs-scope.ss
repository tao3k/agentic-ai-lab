;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Pure admission, freezing and canonical Scope digest functions.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        "types.ss" "objects.ss")
(export agentic-ai-lab-ai-agentic-context-scope-admit
        agentic-ai-lab-ai-agentic-context-digest)
(def (agentic-ai-lab-ai-agentic-context-digest x)
  (string-append "sha256:" (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (port) (write x port))))))))
(def (agentic-ai-lab-ai-agentic-context-scope-admit spec)
  (unless (agentic-ai-lab-ai-agentic-context-scope-shape? spec)
    (error "invalid AI Agentic-context Scope"))
  (let* ((tuple (map (lambda (k) (let (v (.ref spec k)) (if (string? v) (string-copy v) v)))
                    '(bundle organization epoch project worktree source-cut actor task destination session turn)))
         (scope-value (.o (:: @ AiAgenticContextScope.)
            bundle: (list-ref tuple 0) organization: (list-ref tuple 1)
            epoch: (list-ref tuple 2) project: (list-ref tuple 3) worktree: (list-ref tuple 4)
            source-cut: (list-ref tuple 5) actor: (list-ref tuple 6) task: (list-ref tuple 7)
            destination: (list-ref tuple 8) session: (list-ref tuple 9) turn: (list-ref tuple 10)
            semantic-digest: (agentic-ai-lab-ai-agentic-context-digest (cons 'ai-agentic-context/scope-v1 tuple)))))
    scope-value))
