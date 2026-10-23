;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: domain noun slots compose through native gerbil-poo algebra.
;;; Invariant: refinements retain inherited declarations and never mutate their
;;; parent objects.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test check-exception check-equal? test-suite)
        (only-in :clan/poo/object .all-slots .def .get .o)
        (only-in :yuanxu/observability/slot-presentation
                 yuanxu-slot-view
                 yuanxu-slot-presentation))

(export poo-slot-algebra-test)

(.def OntologyCase
  (profile-selection ? (.o))
  (events ? (.o))
  (trajectories ? (.o)))

(.def (PrescriptionCase @ OntologyCase)
  (profile-selection =>.+
    (.o common: (.o evidence: 'evidence-profile)
        healthcare: (.o base: 'healthcare-base-profile)))
  (events =>.+
    (.o prescription: 'prescription-event))
  (trajectories =>.+
    (.o safety: 'prescription-safety-trajectory)))

(.def (ReviewedPrescriptionCase @ PrescriptionCase)
  ;; Refinement is recursive: the outer slot retains named groups and the
  ;; inner slot retains entries inside the common group.
  (profile-selection =>.+
    (.o common: =>.+ (.o privacy: 'privacy-profile)))
  (events =>.+
    (.o prescription: 'reviewed-prescription-event
        review: 'clinical-review-event)))

(def (fixture-source prototype-value source-line-value)
  (.o prototype: prototype-value
      source-path: "t/poo-slot-algebra-test.ss"
      source-line: source-line-value))

(def fixture-prototype-sources
  (.o reviewed: (fixture-source ReviewedPrescriptionCase 32)
      prescription: (fixture-source PrescriptionCase 23)
      ontology: (fixture-source OntologyCase 18)))

(def poo-slot-algebra-test
  (test-suite
   "POO noun-slot algebra"

   (yuanxu-test-case "base collection defaults remain empty"
     (check-equal? (.all-slots (.get OntologyCase profile-selection)) '())
     (check-equal? (.all-slots (.get OntologyCase events)) '())
     (check-equal? (.all-slots (.get OntologyCase trajectories)) '()))

   (yuanxu-test-case "refinement retains identities and overrides one identity"
     (check-equal?
      (.get PrescriptionCase events prescription)
      'prescription-event)
     (check-equal?
      (.get ReviewedPrescriptionCase events prescription)
      'reviewed-prescription-event)
     (check-equal?
      (.get ReviewedPrescriptionCase events review)
      'clinical-review-event)
     (check-equal?
      (.get PrescriptionCase events prescription)
      'prescription-event))

   (yuanxu-test-case "selection recursively refines named groups"
     (check-equal?
      (.get ReviewedPrescriptionCase
            profile-selection common evidence)
      'evidence-profile)
     (check-equal?
      (.get ReviewedPrescriptionCase
            profile-selection common privacy)
      'privacy-profile)
     (check-equal?
      (.get ReviewedPrescriptionCase
            profile-selection healthcare base)
      'healthcare-base-profile))

   (yuanxu-test-case "unmentioned noun slots remain inherited"
     (check-equal?
      (.get ReviewedPrescriptionCase trajectories safety)
      'prescription-safety-trajectory))

   (yuanxu-test-case "effective value precedes its slot declaration lineage"
     (let* ((events-view
             (yuanxu-slot-view
              ReviewedPrescriptionCase 'events fixture-prototype-sources))
            (trajectory-view
             (yuanxu-slot-view
              ReviewedPrescriptionCase 'trajectories fixture-prototype-sources)))
       (check-equal? (.get (.get events-view effective-value) prescription)
                     'reviewed-prescription-event)
       (check-equal? (.get events-view provenance)
                     '(reviewed prescription ontology))
       (check-equal? (.get trajectory-view provenance)
                     '(prescription ontology))
       (check-equal? (.get (car (.get events-view declaration-sources))
                           source-path)
                     "t/poo-slot-algebra-test.ss")))

   (yuanxu-test-case "default presentation shows only the effective value"
     (let (presented
           (yuanxu-slot-presentation
            ReviewedPrescriptionCase 'events))
       (check-equal? (.all-slots presented) '(effective-value))
       (check-equal? (.get (.get presented effective-value) prescription)
                     'reviewed-prescription-event)))

   (yuanxu-test-case "progressive views preserve native declaration order"
     (let* ((provenance
             (yuanxu-slot-presentation
              ReviewedPrescriptionCase 'events 'provenance
              fixture-prototype-sources))
            (composition
             (yuanxu-slot-presentation
              ReviewedPrescriptionCase 'events 'composition
              fixture-prototype-sources))
            (advanced
             (yuanxu-slot-presentation
              ReviewedPrescriptionCase 'events 'advanced
              fixture-prototype-sources))
            (source
             (yuanxu-slot-presentation
              ReviewedPrescriptionCase 'events 'source
              fixture-prototype-sources)))
       (check-equal? (.get provenance declaration-lineage)
                     '(reviewed prescription ontology))
       (check-equal?
        (map (lambda (step) (.get step mode))
             (.get composition composition-chain))
        '(super-aware super-aware default))
       (check-equal?
        (map (lambda (entry) (.get entry label))
             (.get advanced prototype-precedence))
        '(reviewed prescription ontology))
       (check-equal? (.get (car (.get source source-declarations))
                           source-line)
                     32)))

   (yuanxu-test-case "detailed presentation requires declared source metadata"
     (check-exception
      (yuanxu-slot-presentation
       ReviewedPrescriptionCase 'events 'advanced)
      true))

   (yuanxu-test-case "unknown disclosure level fails closed"
     (check-exception
      (yuanxu-slot-presentation
       ReviewedPrescriptionCase 'events 'unsupported)
      true))

   (yuanxu-test-case "default and detailed views use one slot evaluation"
     (let* ((evaluation-count 0)
            (subject (.o measured:
                         (begin
                           (set! evaluation-count (+ evaluation-count 1))
                           'native-result)))
            (sources
             (.o measured: (fixture-source subject 163))))
       (check-equal?
        (.get (yuanxu-slot-presentation subject 'measured)
              effective-value)
        'native-result)
       (check-equal?
        (.get (yuanxu-slot-presentation
               subject 'measured 'source sources)
              effective-value)
        'native-result)
       (check-equal? evaluation-count 1)))

   (yuanxu-test-case "incomplete provenance labels fail closed"
     (check-exception
      (yuanxu-slot-view
       ReviewedPrescriptionCase 'events
       (.o reviewed: (fixture-source ReviewedPrescriptionCase 32)))
      true))

   (yuanxu-test-case "duplicate prototype labels fail closed"
     (check-exception
      (yuanxu-slot-view
       ReviewedPrescriptionCase 'events
       (.o reviewed: (fixture-source ReviewedPrescriptionCase 32)
           duplicate: (fixture-source ReviewedPrescriptionCase 32)
           prescription: (fixture-source PrescriptionCase 23)
           ontology: (fixture-source OntologyCase 18)))
      true))

   (yuanxu-test-case "invalid declared source fails closed"
     (check-exception
      (yuanxu-slot-view
       ReviewedPrescriptionCase 'events
       (.o reviewed: (.o prototype: ReviewedPrescriptionCase
                         source-path: "" source-line: 0)
           prescription: (fixture-source PrescriptionCase 23)
           ontology: (fixture-source OntologyCase 18)))
      true))

   (yuanxu-test-case "missing slot cannot be presented"
     (check-exception
      (yuanxu-slot-view
       ReviewedPrescriptionCase 'nonexistent fixture-prototype-sources)
      true))))
