;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: orthogonal POO capabilities for qualification object families.

(export #t)

(import (only-in :clan/poo/object .ref)
        :core/object-family/role-syntax
        (only-in :std/list/list fold fold-right))

(def +poo-flow-versioned-capability-slots+ '(schema-id schema-version))
(def +poo-flow-revision-bound-capability-slots+ '(source-revision))
(def +poo-flow-owner-bound-capability-slots+ '(owner-artifacts))
(def +poo-flow-evidence-bound-capability-slots+
  '(symbol-receipt version-receipt legacy-guards external-blocker))
(def +poo-flow-decision-state-capability-slots+
  '(decision-required? abi-v1-frozen? deletion-authorized? ready?))

(def poo-flow-versioned-capability-prototype
  (poo-core-role-object
   (slots ((qualification/versioned? #t)
           (schema-id #f)
           (schema-version #f)))
   (supers)))

(def poo-flow-revision-bound-capability-prototype
  (poo-core-role-object
   (slots ((qualification/revision-bound? #t)
           (source-revision #f)))
   (supers)))

(def poo-flow-owner-bound-capability-prototype
  (poo-core-role-object
   (slots ((qualification/owner-bound? #t)
           (owner-artifacts '())))
   (supers)))

(def poo-flow-evidence-bound-capability-prototype
  (poo-core-role-object
   (slots ((qualification/evidence-bound? #t)
           (symbol-receipt #f)
           (version-receipt #f)
           (legacy-guards '())
           (external-blocker #f)))
   (supers)))

(def poo-flow-decision-state-capability-prototype
  (poo-core-role-object
   (slots ((qualification/decision-state? #t)
           (decision-required? #t)
           (abi-v1-frozen? #f)
           (deletion-authorized? #f)
           (ready? #f)))
   (supers)))

(def (poo-flow-versioned-capability schema-id-value schema-version-value)
  (poo-core-role-object
   (slots ((schema-id schema-id-value)
           (schema-version schema-version-value)))
   (supers poo-flow-versioned-capability-prototype)))

(def (poo-flow-revision-bound-capability source-revision-value)
  (poo-core-role-object
   (slots ((source-revision source-revision-value)))
   (supers poo-flow-revision-bound-capability-prototype)))

(def (poo-flow-owner-bound-capability owner-artifacts-value)
  (poo-core-role-object
   (slots ((owner-artifacts owner-artifacts-value)))
   (supers poo-flow-owner-bound-capability-prototype)))

(def (poo-flow-evidence-bound-capability symbol-receipt-value
                                         version-receipt-value
                                         legacy-guards-value
                                         external-blocker-value)
  (poo-core-role-object
   (slots ((symbol-receipt symbol-receipt-value)
           (version-receipt version-receipt-value)
           (legacy-guards legacy-guards-value)
           (external-blocker external-blocker-value)))
   (supers poo-flow-evidence-bound-capability-prototype)))

(def (poo-flow-decision-state-capability decision-required-value?
                                         abi-v1-frozen-value?
                                         deletion-authorized-value?
                                         ready-value?)
  (poo-core-role-object
   (slots ((decision-required? decision-required-value?)
           (abi-v1-frozen? abi-v1-frozen-value?)
           (deletion-authorized? deletion-authorized-value?)
           (ready? ready-value?)))
   (supers poo-flow-decision-state-capability-prototype)))

(def (qualification-capability-slot/default value slot default)
  (with-catch (lambda (_failure) default)
              (lambda () (.ref value slot))))

(def (poo-flow-versioned-capability-valid? value)
  (and (qualification-capability-slot/default
        value 'qualification/versioned? #f)
       (let ((schema-id
              (qualification-capability-slot/default value 'schema-id #f))
             (schema-version
              (qualification-capability-slot/default value 'schema-version #f)))
         (and (or (symbol? schema-id) (string? schema-id))
              (exact-integer? schema-version)
              (> schema-version 0)))))

(def (poo-flow-revision-bound-capability-valid? value)
  (and (qualification-capability-slot/default
        value 'qualification/revision-bound? #f)
       (let (revision
             (qualification-capability-slot/default
              value 'source-revision #f))
         (and (string? revision) (> (string-length revision) 0)))))

(def (poo-flow-owner-bound-capability-valid? value)
  (and (qualification-capability-slot/default
        value 'qualification/owner-bound? #f)
       (let (owners
             (qualification-capability-slot/default
              value 'owner-artifacts #f))
         (and (list? owners) (pair? owners)))))

(def (poo-flow-evidence-bound-capability-valid? value)
  (and (qualification-capability-slot/default
        value 'qualification/evidence-bound? #f)
       (qualification-capability-slot/default value 'symbol-receipt #f)
       (qualification-capability-slot/default value 'version-receipt #f)
       (list? (qualification-capability-slot/default
               value 'legacy-guards #f))
       (qualification-capability-slot/default value 'external-blocker #f)))

(def (poo-flow-decision-state-capability-valid? value)
  (and (qualification-capability-slot/default
        value 'qualification/decision-state? #f)
       (boolean? (qualification-capability-slot/default
                  value 'decision-required? 'missing))
       (boolean? (qualification-capability-slot/default
                  value 'abi-v1-frozen? 'missing))
       (boolean? (qualification-capability-slot/default
                  value 'deletion-authorized? 'missing))
       (boolean? (qualification-capability-slot/default
                  value 'ready? 'missing))))

(def (poo-flow-qualification-capabilities-valid? value validators)
  (andmap (lambda (validator) (validator value)) validators))

(def (poo-flow-qualification-capability-composition-diagnostics descriptors)
  (let loop ((rest descriptors) (ids '()) (owned '()) (diagnostics '()))
    (if (null? rest)
        (reverse diagnostics)
        (let* ((descriptor (car rest))
               (id (car descriptor))
               (slots (cdr descriptor))
               (duplicate-id? (memq id ids))
               (collisions
                (filter (lambda (slot) (memq slot owned)) slots))
               (diagnostics
                (fold-right
                 (lambda (slot out)
                   (cons (list 'slot-owner-conflict slot) out))
                 diagnostics
                 collisions))
               (diagnostics
                (if duplicate-id?
                  (cons (list 'duplicate-capability id) diagnostics)
                  diagnostics)))
          (loop (cdr rest)
                (cons id ids)
                (fold cons owned slots)
                diagnostics)))))

(def (poo-flow-qualification-capability-composition-assert! descriptors)
  (let (diagnostics
        (poo-flow-qualification-capability-composition-diagnostics descriptors))
    (unless (null? diagnostics)
      (error "invalid qualification capability composition" diagnostics))
    #t))
