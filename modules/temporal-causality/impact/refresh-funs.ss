;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure replacement of a contrast when its source series versions change.
;;; Blocked recomputation leaves the previous result historical and untouched.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/delta-types
                 agentic-ai-lab-temporal-trajectory-delta?)
        (only-in :agentic-ai-lab/modules/temporal-causality/trajectory/delta-funs
                 agentic-ai-lab-temporal-trajectory-delta)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/types
                 agentic-ai-lab-temporal-impact-contrast?)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/funs
                 agentic-ai-lab-temporal-impact-contrast)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/refresh-objects
                 agentic-ai-lab-temporal-impact-refresh-value))
(export agentic-ai-lab-temporal-impact-refresh)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (digest datum)
  (string-append "sha256:"
   (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (port) (write datum port))))))))
(def (coordinates series)
  (map (lambda (sample) (.ref (.ref sample 'instant) 'coordinate))
       (.ref series 'samples)))

(def (agentic-ai-lab-temporal-impact-refresh
      identity previous left-delta right-delta)
  (unless (and (text? identity)
               (agentic-ai-lab-temporal-impact-contrast? previous)
               (agentic-ai-lab-temporal-trajectory-delta? left-delta)
               (agentic-ai-lab-temporal-trajectory-delta? right-delta))
    (error "invalid impact refresh input"))
  (let* ((left
          (agentic-ai-lab-temporal-trajectory-delta
           (.ref left-delta 'identity)
           (.ref left-delta 'previous-series)
           (.ref left-delta 'revised-series)))
         (right
          (agentic-ai-lab-temporal-trajectory-delta
           (.ref right-delta 'identity)
           (.ref right-delta 'previous-series)
           (.ref right-delta 'revised-series)))
         (old-left (.ref left 'previous-series))
         (old-right (.ref right 'previous-series))
         (new-left (.ref left 'revised-series))
         (new-right (.ref right 'revised-series))
         (canonical-previous
          (agentic-ai-lab-temporal-impact-contrast
           (.ref previous 'identity) old-left old-right)))
    (unless (and (equal? (.ref left-delta 'semantic-digest)
                         (.ref left 'semantic-digest))
                 (equal? (.ref right-delta 'semantic-digest)
                         (.ref right 'semantic-digest))
                 (equal? (.ref previous 'semantic-digest)
                         (.ref canonical-previous 'semantic-digest))
                 (equal? (.ref previous 'left-series-digest)
                         (.ref old-left 'semantic-digest))
                 (equal? (.ref previous 'right-series-digest)
                         (.ref old-right 'semantic-digest)))
      (error "impact refresh source digests do not match"))
    (let* ((unchanged?
            (and (eq? (.ref left 'status) 'unchanged)
                 (eq? (.ref right 'status) 'unchanged)))
           (scope-compatible?
            (every (lambda (slot)
                     (equal? (.ref new-left slot) (.ref new-right slot)))
                   '(subject-identity outcome-identity unit-identity
                     source-cut-digest source-projection-digest
                     time-domain-identity)))
           (grid-compatible?
            (equal? (coordinates new-left) (coordinates new-right)))
           (action
            (cond (unchanged? 'reused)
                  ((not scope-compatible?) 'blocked)
                  ((not grid-compatible?) 'blocked)
                  (else 'recomputed)))
           (reason
            (cond (unchanged? 'unchanged)
                  ((not scope-compatible?) 'scope-mismatch)
                  ((not grid-compatible?) 'grid-mismatch)
                  (else 'source-version)))
           (revised
            (case action
              ((reused) canonical-previous)
              ((recomputed)
               (agentic-ai-lab-temporal-impact-contrast
                (string-append identity "/contrast") new-left new-right))
              (else #f)))
           (semantic-digest
            (digest
             (list 'agentic-ai-lab.temporal-causality.impact-refresh.v1
                   identity (.ref canonical-previous 'semantic-digest)
                   (.ref left 'semantic-digest)
                   (.ref right 'semantic-digest)
                   (.ref new-left 'semantic-digest)
                   (.ref new-right 'semantic-digest)
                   action reason (and revised (.ref revised 'semantic-digest))))))
      (agentic-ai-lab-temporal-impact-refresh-value
       identity semantic-digest canonical-previous revised
       (.ref left 'semantic-digest) (.ref right 'semantic-digest)
       (.ref new-left 'semantic-digest) (.ref new-right 'semantic-digest)
       action reason))))
