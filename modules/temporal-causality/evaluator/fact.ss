;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .ref)
        (only-in :std/crypto/digest sha256) (only-in :std/encoding/hex hex-encode))
(export agentic-ai-lab-temporal-mrr-fact-content agentic-ai-lab-temporal-mrr-fact-content-replay)
(def (text? x) (and (string? x) (< 0 (string-length x) 257)))
(def (relation? x) (and (text? x)
  (andmap (lambda (c) (or (char<=? #\a c #\z) (char<=? #\A c #\Z)
                         (char<=? #\0 c #\9) (char=? c #\_))) (string->list x))))
(def (scalar? x) (or (boolean? x) (and (exact-integer? x) (<= (- (expt 2 63)) x (- (expt 2 63) 1)))))
(def (agentic-ai-lab-temporal-mrr-fact-content identity-value generation-value relation-id-value evaluator-relation-value row-value)
  (unless (and (text? identity-value) (text? generation-value) (text? relation-id-value)
               (relation? evaluator-relation-value) (list? row-value) (<= 1 (length row-value) 32)
               (andmap scalar? row-value)) (error "unsupported MRR fact content profile"))
  (let* ((owned-row (map identity row-value))
         ;; Same inert Scheme datum v1 list spelling used by Rust/Python wire.
         (data (list 'list "agentic-ai-lab.mrr-fact-content.v1" identity-value generation-value
                     relation-id-value evaluator-relation-value (cons 'list owned-row)))
         (fingerprint (string-append "sha256:" (hex-encode (sha256 (string->utf8
           (call-with-output-string (lambda (p) (write data p)))))))))
    (.o kind: 'agentic-ai-lab.temporal-causality.mrr-fact-content.v1 identity: identity-value
        generation: generation-value relation-identity: relation-id-value
        evaluator-relation: evaluator-relation-value row: owned-row semantic-digest: fingerprint)))
(def (agentic-ai-lab-temporal-mrr-fact-content-replay fact)
  (unless (eq? (.ref fact 'kind) 'agentic-ai-lab.temporal-causality.mrr-fact-content.v1)
    (error "invalid fact content kind"))
  (let (canonical (agentic-ai-lab-temporal-mrr-fact-content (.ref fact 'identity) (.ref fact 'generation)
                    (.ref fact 'relation-identity) (.ref fact 'evaluator-relation) (.ref fact 'row)))
    (unless (equal? (.ref canonical 'semantic-digest) (.ref fact 'semantic-digest))
      (error "fact content digest mismatch")) canonical))
