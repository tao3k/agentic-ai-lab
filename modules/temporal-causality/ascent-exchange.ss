;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Explicit finite transport. Owner declarations are content, not MRR admission.
;;; No event identity, valid/knowledge coordinate or clock conversion is inferred.
(import (only-in :std/list/list find)
        (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :agentic-ai-lab/modules/temporal-causality/types
                 agentic-ai-lab-causal-event-graph? agentic-ai-lab-causal-cut?)
        (only-in :agentic-ai-lab/modules/temporal-causality/funs agentic-ai-lab-causal-cut)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types agentic-ai-lab-temporal-instant?)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/uncertainty-types
                 agentic-ai-lab-temporal-bounded-observation?)
        (only-in :gerbil-ascent/temporal/lens
                 temporal-interval temporal-lens temporal-source temporal-solve temporal-verify))
(export agentic-ai-lab-ascent-event-binding agentic-ai-lab-ascent-exchange
        agentic-ai-lab-ascent-exchange-solve agentic-ai-lab-ascent-exchange-verify)

(def (text? x) (and (string? x) (> (string-length x) 0)))
(def (id? x) (and (symbol? x) (not (eq? x 'unknown))))
(def (unique? xs)
  (or (null? xs) (and (not (member (car xs) (cdr xs))) (unique? (cdr xs)))))
(def (slots? x names)
  (and (object? x) (andmap (lambda (name) (.slot? x name)) names)))
(def (observed-instant? x)
  (and (agentic-ai-lab-temporal-instant? x) (eq? (.ref x 'modality) 'observed)))
(def (instant-data x)
  (map (lambda (slot) (.ref x slot))
       '(identity domain-identity coordinate provenance-identity modality)))
(def (valid-data x)
  (cond ((not x) 'unknown)
        ((observed-instant? x) (instant-data x))
        (else (list (instant-data (.ref x 'earliest))
                    (instant-data (.ref x 'latest))
                    (instant-data (.ref x 'acquisition-instant))
                    (map (lambda (slot) (.ref x slot))
                         '(identity semantic-digest clock-role source-identity precision
                           receipt-identity attestation-identity attempt-identity schema-identity))))))
(def (binding? x)
  (and (slots? x '(kind event-identity native-identity valid-time knowledge-time))
       (eq? (.ref x 'kind) 'agentic-ai-lab.ascent-event-binding.v1)
       (text? (.ref x 'event-identity)) (id? (.ref x 'native-identity))
       (let (v (.ref x 'valid-time))
         (or (not v) (observed-instant? v) (agentic-ai-lab-temporal-bounded-observation? v)))
       (observed-instant? (.ref x 'knowledge-time))))

(def (agentic-ai-lab-ascent-event-binding event-id native-id valid-value knowledge-value)
  (let (binding (.o kind: 'agentic-ai-lab.ascent-event-binding.v1
                   event-identity: event-id native-identity: native-id
                   valid-time: valid-value knowledge-time: knowledge-value))
    (unless (binding? binding) (error "invalid ASCENT event binding"))
    binding))

(def (event-data event)
  (list (.ref event 'identity) (.ref event 'subject) (.ref event 'event-kind)
        (map (lambda (slot) (.ref (.ref event 'observation) slot))
             '(identity clock-role logical-position provenance-identity))
        (.ref event 'payload-identity) (.ref event 'causal-parent-identities)
        (.ref event 'modality) (.ref event 'committed?)))
(def (cut-data cut)
  (list (.ref cut 'identity) (.ref cut 'event-graph-identity) (.ref cut 'subject)
        (map event-data (.ref cut 'events)) (.ref cut 'missing-parent-identities)
        (.ref cut 'temporal-order-violations) (.ref cut 'as-of-position) (.ref cut 'complete?)))
(def (digest data)
  (hex-encode (sha256 (string->utf8
                       (call-with-output-string "" (lambda (port) (write data port)))))))

;;; Both domains are explicit: the common native clock name identifies this
;;; declared pair of axes. Acquisition time and cut logical time are never used
;;; as a replacement for the caller's knowledge coordinate.
(def (agentic-ai-lab-ascent-exchange graph cut bindings source-name generation clock
                              valid-domain knowledge-domain cut-name
                              start end as-of horizon closed?)
  (unless (and (agentic-ai-lab-causal-event-graph? graph) (agentic-ai-lab-causal-cut? cut)
               (id? source-name) (boolean? closed?) (text? valid-domain) (text? knowledge-domain)
               (list? bindings) (<= (length bindings) 256) (andmap binding? bindings)
               (unique? (map (lambda (b) (.ref b 'event-identity)) bindings))
               (unique? (map (lambda (b) (.ref b 'native-identity)) bindings)))
    (error "invalid ASCENT exchange"))
  ;; Recompute owner cut selection instead of trusting a caller's complete? slot.
  (unless (equal? (cut-data cut)
                  (cut-data (agentic-ai-lab-causal-cut graph (.ref cut 'as-of-position))))
    (error "ASCENT exchange cut does not match the supplied graph"))
  (let* ((events (.ref graph 'events))
         (ordered (list-sort
                    (lambda (a b) (string<? (.ref a 'event-identity) (.ref b 'event-identity)))
                    bindings)))
    (unless (and (= (length events) (length ordered))
                 (andmap (lambda (event)
                           (member (.ref event 'identity)
                                   (map (lambda (b) (.ref b 'event-identity)) ordered))) events))
      (error "ASCENT exchange needs exactly one binding per graph event"))
    (def (find-binding name)
      (or (find (lambda (b) (equal? name (.ref b 'event-identity))) ordered)
          (error "ASCENT exchange has an unmapped parent" name)))
    (def (native name) (.ref (find-binding name) 'native-identity))
    (def (row binding)
      (let ((v (.ref binding 'valid-time)) (k (.ref binding 'knowledge-time)))
        (unless (and (equal? knowledge-domain (.ref k 'domain-identity))
                     (or (not v)
                         (if (observed-instant? v)
                           (equal? valid-domain (.ref v 'domain-identity))
                           (equal? valid-domain (.ref (.ref v 'earliest) 'domain-identity)))))
          (error "ASCENT exchange clock domain mismatch"))
        (list (.ref binding 'native-identity)
              (cond ((not v) 'unknown)
                    ((observed-instant? v) (.ref v 'coordinate))
                    (else (temporal-interval (.ref (.ref v 'earliest) 'coordinate)
                                             (.ref (.ref v 'latest) 'coordinate))))
              (.ref k 'coordinate))))
    (let* ((rows (map row ordered))
           (parents (apply append
                      (map (lambda (e)
                             (map (lambda (p) (list (native p) (native (.ref e 'identity))))
                                  (.ref e 'causal-parent-identities))) events)))
           (members (map (lambda (e) (native (.ref e 'identity))) (.ref cut 'events)))
           (lens-value (temporal-lens generation clock start end as-of cut-name members horizon
                                 (and closed? (.ref cut 'complete?))))
           ;; Bind ALL original identities/coordinates, even if native rows match.
           ;; This derived snapshot name is content integrity, not authentication.
           (source-id (string->symbol
                       (string-append "poo-exchange-"
                         (digest (list 'agentic-ai-lab.ascent-exchange.v1 source-name generation clock
                                       valid-domain knowledge-domain (cut-data cut)
                                       (.ref graph 'identity) (map event-data events)
                                       (map (lambda (b)
                                              (list (.ref b 'event-identity) (.ref b 'native-identity)
                                                    (valid-data (.ref b 'valid-time))
                                                    (instant-data (.ref b 'knowledge-time)))) ordered))))))
           (source-value (temporal-source source-id generation clock rows parents))
           (lookup (map (lambda (b) (cons (string-copy (.ref b 'event-identity)) (.ref b 'native-identity))) ordered)))
      (.o kind: 'agentic-ai-lab.ascent-exchange.v1 lens: lens-value source: source-value
          native-root: (lambda (name)
                         (let (entry (assoc name lookup))
                           (if entry (cdr entry) (error "unmapped ASCENT root" name))))))))

(def (agentic-ai-lab-ascent-exchange-solve exchange root)
  (temporal-solve (.ref exchange 'lens) (.ref exchange 'source)
                  ((.ref exchange 'native-root) root)))
(def (agentic-ai-lab-ascent-exchange-verify exchange root answer)
  (temporal-verify (.ref exchange 'lens) (.ref exchange 'source)
                   ((.ref exchange 'native-root) root) answer))
