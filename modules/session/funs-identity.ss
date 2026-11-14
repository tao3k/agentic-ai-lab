;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Stable Session identity belongs to Session creation, not to Context content.
(import (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode))

(export agentic-ai-lab-session-identity)

;;; The owner supplies a persisted creation key (for example, its creation nonce).
;;; Distinct Sessions require distinct keys even when their task/scope is equal.
;;; Source edits change Context bindings, while this identity remains stable.
(def (agentic-ai-lab-session-identity namespace creation-key)
  (unless (and (string? namespace)
               (< 0 (string-length namespace) 257)
               (string? creation-key)
               (< 0 (string-length creation-key) 257))
    (error "Session identity requires a bounded namespace and creation key"))
  (let (bytes
          (call-with-output-string
            (lambda (port)
              (write (list 'session-creation-v1 namespace creation-key) port))))
    (string-append "sha256:" (hex-encode (sha256 (string->utf8 bytes))))))
