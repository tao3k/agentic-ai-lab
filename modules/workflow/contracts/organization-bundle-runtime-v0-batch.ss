;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: encodes fixed-layout Runtime v0 batches from validated bundle events.
;;; Invariant: batching preserves canonical order and never changes event identity.
(export #t)

(import (only-in :clan/poo/object .o .ref object<-alist)
        (only-in :std/list/list fold))

(def +poo-flow-runtime-v0-layout-version+ 1)
(def +poo-flow-runtime-v0-event-header-bytes+ 96)

(def (poo-flow-runtime-v0-compact-id high-value low-value)
  (unless (and (integer? high-value) (>= high-value 0)
               (integer? low-value) (>= low-value 0))
    (error "compact identity requires nonnegative 64-bit words"
           high-value low-value))
  (.o (kind 'poo-flow.runtime-v0.compact-id.128)
      (high high-value) (low low-value)))

(def (poo-flow-runtime-v0-identity-entry full-identity-value compact-value)
  (.o (kind 'poo-flow.runtime-v0.identity-entry.1)
      (full-identity full-identity-value)
      (compact compact-value)))

(def (compact-id->list value)
  (list (.ref value 'high) (.ref value 'low)))

(def (poo-flow-runtime-v0-identity-table entries)
  (let (validated-identity-index
        (fold
         (lambda (entry seen)
           (let* ((compact (.ref entry 'compact))
                  (full-identity (.ref entry 'full-identity))
                  (key (compact-id->list compact))
                  (existing (assoc key seen)))
             (when (and existing
                        (not (equal? (cdr existing) full-identity)))
               (error "runtime v0 compact identity collision"
                      key (cdr existing) full-identity))
             (if existing seen
                 (cons (cons key full-identity) seen))))
         '()
         entries))
    (let (entry-values entries)
      (.o (kind 'poo-flow.runtime-v0.identity-table.1)
          (entries entry-values)
          (collision-checked? (list? validated-identity-index))))))

(def (poo-flow-runtime-v0-event event-kind-value flags-value sequence-value
                                event-identity-value correlation-identity-value
                                authorization-identity-value payload-offset-value
                                payload-length-value deadline-value
                                evidence-bits-value)
  (unless (and (integer? sequence-value) (>= sequence-value 0)
               (integer? payload-offset-value) (>= payload-offset-value 0)
               (integer? payload-length-value) (>= payload-length-value 0))
    (error "runtime v0 event requires nonnegative sequence and payload slice"))
  (object<-alist
   (list (cons 'kind 'poo-flow.runtime-v0.event.1)
         (cons 'layout-version +poo-flow-runtime-v0-layout-version+)
         (cons 'header-bytes +poo-flow-runtime-v0-event-header-bytes+)
         (cons 'event-kind event-kind-value) (cons 'flags flags-value)
         (cons 'sequence sequence-value)
         (cons 'event-identity event-identity-value)
         (cons 'correlation-identity correlation-identity-value)
         (cons 'authorization-identity authorization-identity-value)
         (cons 'payload-offset payload-offset-value)
         (cons 'payload-length payload-length-value)
         (cons 'deadline-mono-ns deadline-value)
         (cons 'required-evidence-bits evidence-bits-value)
         (cons 'reserved0 0))))

(def (poo-flow-runtime-v0-event->native-fields event)
  (list (cons 'layout-version (.ref event 'layout-version))
        (cons 'header-bytes (.ref event 'header-bytes))
        (cons 'event-kind (.ref event 'event-kind))
        (cons 'flags (.ref event 'flags))
        (cons 'sequence (.ref event 'sequence))
        (cons 'event-identity (compact-id->list (.ref event 'event-identity)))
        (cons 'correlation-identity
              (compact-id->list (.ref event 'correlation-identity)))
        (cons 'authorization-identity
              (compact-id->list (.ref event 'authorization-identity)))
        (cons 'payload-offset (.ref event 'payload-offset))
        (cons 'payload-length (.ref event 'payload-length))
        (cons 'deadline-mono-ns (.ref event 'deadline-mono-ns))
        (cons 'required-evidence-bits (.ref event 'required-evidence-bits))
        (cons 'reserved0 0)))
