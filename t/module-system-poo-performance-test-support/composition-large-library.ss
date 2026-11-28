;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: large POO profile-library composition performance helpers.
;;; Invariant: keeps 1000+ profile object construction outside macro-expansion
;;; scenario modules so macro benchmarks, POO object families,
;;; object-list enumeration, and indexed profile lookup can be optimized
;;; independently.

(import (only-in :clan/poo/object .o .ref))

(export +poo-performance-large-runtime-profile-count+
        +poo-performance-large-runtime-profile-variant-count+
        poo-performance-large-runtime-profile-name
        poo-performance-large-runtime-profile-variant-name
        poo-performance-large-runtime-profile
        poo-performance-large-runtime-profile-library
        poo-performance-large-runtime-profile-variant-library
        poo-performance-large-runtime-profile-object-list
        poo-performance-large-runtime-profile-index-vector
        poo-performance-large-runtime-profile-family-object-list
        poo-performance-large-runtime-profile-family-profile-at
        poo-performance-large-runtime-profile-family-variant-profile-at
        poo-performance-large-runtime-profile-composition
        poo-performance-large-runtime-profile-valid-count*
        poo-performance-composition-lazy-demand-evidence)

;; : Integer
(def +poo-performance-large-runtime-profile-count+ 2048)

;; : Integer
(def +poo-performance-large-runtime-profile-variant-count+
  +poo-performance-large-runtime-profile-count+)

;; : Symbol
(def +poo-performance-large-runtime-profile-family-handle+
  'community-profiles)

;; poo-performance-large-runtime-profile-make-name-vector
;;   : (-> Integer String Vector)
;;   | doc m%
;;       Precomputes stable symbolic profile names once so large-profile
;;       construction does not rebuild strings during benchmark validation.
;;
;;       # Examples
;;       ```scheme
;;       (vector-ref
;;        (poo-performance-large-runtime-profile-make-name-vector 1 "p-")
;;        0)
;;       ;; => p-0
;;       ```
;;     %
(def (poo-performance-large-runtime-profile-make-name-vector
      count
      prefix)
  (list->vector
   (map (lambda (index)
          (string->symbol
           (string-append prefix (number->string index))))
        (iota count))))

;; : Vector
(def +poo-performance-large-runtime-profile-names+
  (poo-performance-large-runtime-profile-make-name-vector
   +poo-performance-large-runtime-profile-count+
   "community-profile-"))

;; : Vector
(def +poo-performance-large-runtime-profile-variant-names+
  (poo-performance-large-runtime-profile-make-name-vector
   +poo-performance-large-runtime-profile-variant-count+
   "audited-community-profile-"))

;; : (-> Integer Symbol)
(def (poo-performance-large-runtime-profile-name index)
  (vector-ref +poo-performance-large-runtime-profile-names+ index))

;; : (-> Integer Symbol)
(def (poo-performance-large-runtime-profile-variant-name index)
  (vector-ref +poo-performance-large-runtime-profile-variant-names+ index))

;; : (-> Integer PooObject)
(def (poo-performance-large-runtime-profile index)
  (.o (name (poo-performance-large-runtime-profile-name index))
      (scope '(session workflow publish-channel))
      (analysis '(checksum schema provenance))
      (publish '(human-approved proof-gated))
      (retention '(project-retained audit-log))))

;; : (-> PooObject Integer PooObject)
(def (poo-performance-large-runtime-profile-variant profile index)
  (.o (name (poo-performance-large-runtime-profile-variant-name index))
      (scope (.ref profile 'scope))
      (analysis '(checksum schema provenance citation-trace))
      (publish '(human-approved proof-gated internal-registry))
      (retention '(project-retained audit-log indexed-hot-path))))

;; poo-performance-large-runtime-profile-library
;;   : (-> Integer Vector)
;;   | doc m%
;;       Builds the large POO base-profile vector once for 1000+ profile
;;       composition benchmarks.
;;
;;       # Examples
;;       ```scheme
;;       (vector-length (poo-performance-large-runtime-profile-library 2))
;;       ;; => 2
;;       ```
;;     %
(def (poo-performance-large-runtime-profile-library count)
  (list->vector
   (map poo-performance-large-runtime-profile (iota count))))

;; poo-performance-large-runtime-profile-variant-library
;;   : (-> Vector Integer Vector)
;;   | doc m%
;;       Builds variant profiles from the shared base-profile vector without
;;       routing through macro expansion or alist adapters.
;;
;;       # Examples
;;       ```scheme
;;       (vector-length
;;        (poo-performance-large-runtime-profile-variant-library
;;         (poo-performance-large-runtime-profile-library 1)
;;         1))
;;       ;; => 1
;;       ```
;;     %
(def (poo-performance-large-runtime-profile-variant-library base-profiles count)
  (list->vector
   (map (lambda (index)
          (poo-performance-large-runtime-profile-variant
           (vector-ref base-profiles index)
           index))
        (iota count))))

;; : (-> Vector [PooObject])
(def (poo-performance-large-runtime-profile-object-list profiles)
  (vector->list profiles))

;; : (-> Vector Vector)
(def (poo-performance-large-runtime-profile-index-vector profiles)
  profiles)

;; : Vector
(def +poo-performance-large-runtime-profile-base-fixture+
  (poo-performance-large-runtime-profile-library
   +poo-performance-large-runtime-profile-count+))

;; : Vector
(def +poo-performance-large-runtime-profile-variant-fixture+
  (poo-performance-large-runtime-profile-variant-library
   +poo-performance-large-runtime-profile-base-fixture+
   +poo-performance-large-runtime-profile-variant-count+))

;; : (-> PooObject [PooObject])
(def (poo-performance-large-runtime-profile-family-object-list family)
  (if (eq? (.ref family 'handle)
           +poo-performance-large-runtime-profile-family-handle+)
    (poo-performance-large-runtime-profile-object-list
     +poo-performance-large-runtime-profile-base-fixture+)
    (error "missing large runtime profile family" (.ref family 'handle))))

;; poo-performance-large-runtime-profile-family-profile-at
;;   : (-> PooObject Integer PooObject)
;;   | doc m%
;;       Performs direct indexed lookup into the shared POO profile
;;       family without rebuilding profile objects.
;;
;;       # Examples
;;       ```scheme
;;       (.ref (poo-performance-large-runtime-profile-family-profile-at
;;              (.o (handle 'community-profiles))
;;              0)
;;             'name)
;;       ;; => community-profile-0
;;       ```
;;     %
(def (poo-performance-large-runtime-profile-family-profile-at family index)
  (if (eq? (.ref family 'handle)
           +poo-performance-large-runtime-profile-family-handle+)
    (vector-ref +poo-performance-large-runtime-profile-base-fixture+ index)
    (error "missing large runtime profile family" (.ref family 'handle))))

;; : (-> PooObject Integer PooObject)
(def (poo-performance-large-runtime-profile-family-variant-profile-at family index)
  (if (eq? (.ref family 'handle)
           +poo-performance-large-runtime-profile-family-handle+)
    (vector-ref +poo-performance-large-runtime-profile-variant-fixture+ index)
    (error "missing large runtime profile family" (.ref family 'handle))))

;; : (-> Integer [Integer])
(def (poo-performance-large-runtime-profile-sample-indexes count)
  (list 0
        (quotient count 8)
        (quotient count 4)
        (quotient count 2)
        (- count 2)
        (- count 1)))

;; : (-> (-> Integer PooObject) Integer Boolean)
(def (poo-performance-large-runtime-profile-base-pass?
      profile-at
      index)
  (let* ((name (poo-performance-large-runtime-profile-name index))
         (from-payload (profile-at index)))
    (and (eq? (.ref from-payload 'name) name)
         (memq 'schema (.ref from-payload 'analysis)))))

;; : (-> (-> Integer PooObject) Integer Boolean)
(def (poo-performance-large-runtime-profile-variant-pass?
      profile-at
      index)
  (let* ((name (poo-performance-large-runtime-profile-variant-name index))
         (from-payload (profile-at index)))
    (and (eq? (.ref from-payload 'name) name)
         (memq 'citation-trace (.ref from-payload 'analysis))
         (memq 'internal-registry (.ref from-payload 'publish)))))

;; poo-performance-large-runtime-profile-hot-path-pass?
;;   : (-> PooObject Boolean)
;;   | doc m%
;;       Checks a small deterministic sample of direct family lookups so the
;;       benchmark proves indexed POO profile reuse rather than list traversal.
;;
;;       # Examples
;;       ```scheme
;;       (poo-performance-large-runtime-profile-hot-path-pass?
;;        (.o (handle 'community-profiles) (count 2048)))
;;       ;; => #t
;;       ```
;;     %
(def (poo-performance-large-runtime-profile-hot-path-pass? family)
  (let* ((count (.ref family 'count))
         (indexes
          (poo-performance-large-runtime-profile-sample-indexes count)))
    (andmap
     (lambda (index)
       (and (poo-performance-large-runtime-profile-base-pass?
             (lambda (profile-index)
               (poo-performance-large-runtime-profile-family-profile-at
                family
                profile-index))
             index)
            (poo-performance-large-runtime-profile-variant-pass?
             (lambda (profile-index)
               (poo-performance-large-runtime-profile-family-variant-profile-at
                family
                profile-index))
             index)))
     indexes)))

;; poo-performance-large-runtime-profile-composition
;;   : (-> PooObject)
;;   | doc m%
;;       Builds the large-library composition object from shared POO
;;       profile-family fixtures.
;;
;;       # Examples
;;       ```scheme
;;       (.ref (poo-performance-large-runtime-profile-composition) 'name)
;;       ;; => poo-object-reuse-large-library-performance
;;       ```
;;     %
(def (poo-performance-large-runtime-profile-composition)
  (let* ((family
          (.o (name 'community-profiles)
              (handle +poo-performance-large-runtime-profile-family-handle+)
              (count +poo-performance-large-runtime-profile-count+)
              (variant-count
               +poo-performance-large-runtime-profile-variant-count+))))
    (.o (name 'poo-object-reuse-large-library-performance)
        (modules
         (list (.o (name 'community-profiles)
                   (value family))))
        (stages
         (list
          (.o (name 'production)
              (clauses
               (list
                (.o (name 'compose)
                    (payload
                     (.o (family 'community-profiles)
                         (surface 'object-list-accessor)
                         (count
                          +poo-performance-large-runtime-profile-count+))))
                (.o (name 'extend)
                    (payload
                     (.o (family 'community-profiles)
                         (surface 'variant-object-list-accessor)
                         (count
                          +poo-performance-large-runtime-profile-variant-count+))))
                (.o (name 'prove)
                    (payload
                     '(large-runtime-profile-library
                       direct-poo-profile-reuse
                       hook-override-profile-family
                       indexed-poo-profile-lookup
	                       no-macro-expansion-adapter)))))))))))

;; poo-performance-large-runtime-profile-valid-count*
;;   : (-> PooObject Integer Integer)
;;   | doc m%
;;       Validates sample lookups through the large POO profile family and
;;       returns the measured round count only when the composition is coherent.
;;
;;       # Examples
;;       ```scheme
;;       (poo-performance-large-runtime-profile-valid-count*
;;        (poo-performance-large-runtime-profile-composition)
;;        1)
;;       ;; => 1
;;       ```
;;     %
(def (poo-performance-composition-lazy-demand-evidence)
  (def shared-model-route-force-count-value 0)
  (def shared-sandbox-image-force-count-value 0)
  (def unused-model-route-force-count-value 0)
  (def large-library-force-count-value 0)

  (def (force-shared-model-route route-value)
    (set! shared-model-route-force-count-value
      (+ shared-model-route-force-count-value 1))
    route-value)

  (def (force-shared-sandbox-image image-value)
    (set! shared-sandbox-image-force-count-value
      (+ shared-sandbox-image-force-count-value 1))
    image-value)

  (def (force-unused-model-route route-value)
    (set! unused-model-route-force-count-value
      (+ unused-model-route-force-count-value 1))
    route-value)

  (def (force-large-library)
    (set! large-library-force-count-value
      (+ large-library-force-count-value 1))
    (poo-performance-large-runtime-profile-composition))

  (def shared-model-value
    (.o (kind 'model)
        (family 'incident-response-model)
        (route (force-shared-model-route 'triage-fast-path))
        (context-window 'short)
        (cost-class 'interactive)))

  (def shared-sandbox-value
    (.o (kind 'sandbox)
        (family 'incident-response-sandbox)
        (image (force-shared-sandbox-image 'gerbil-runtime))
        (network 'off)
        (cpu 'bounded)))

  (def pull-request-agent-value
    (.o (kind 'agent)
        (family 'incident-response-agent)
        (role 'pull-request-triage)
        (model shared-model-value)
        (sandbox shared-sandbox-value)))

  (def scheduled-audit-agent-value
    (.o (kind 'agent)
        (family 'incident-response-agent)
        (role 'scheduled-audit)
        (model shared-model-value)
        (sandbox shared-sandbox-value)))

  (def unused-candidate-agent-value
    (.o (kind 'agent)
        (family 'incident-response-agent)
        (role 'unused-candidate)
        (model
         (.o (kind 'model)
             (family 'incident-response-model)
             (route (force-unused-model-route 'cold-path))
             (context-window 'long)
             (cost-class 'batch)))
        (sandbox shared-sandbox-value)))

  (def composition-value
    (.o (kind 'composition)
        (family 'poo-composition-lazy-demand)
        (large-library (force-large-library))
        (pull-request pull-request-agent-value)
        (scheduled-audit scheduled-audit-agent-value)
        (unused-candidate unused-candidate-agent-value)))

  (let* ((pull-request-value (.ref composition-value 'pull-request))
         (pull-request-model-value (.ref pull-request-value 'model))
         (selected-route-value (.ref pull-request-model-value 'route))
         (repeated-route-value (.ref pull-request-model-value 'route))
         (scheduled-audit-value (.ref composition-value 'scheduled-audit))
         (scheduled-audit-model-value (.ref scheduled-audit-value 'model))
         (shared-model?-value
          (eq? pull-request-model-value scheduled-audit-model-value))
         (shared-route-value (.ref scheduled-audit-model-value 'route))
         (pull-request-sandbox-value (.ref pull-request-value 'sandbox))
         (selected-image-value (.ref pull-request-sandbox-value 'image))
         (unused-route-force-count-before-full-value
          unused-model-route-force-count-value)
         (shared-model-route-force-count-before-full-value
          shared-model-route-force-count-value)
         (shared-sandbox-image-force-count-before-full-value
          shared-sandbox-image-force-count-value)
         (unused-candidate-value (.ref composition-value 'unused-candidate))
         (unused-candidate-model-value (.ref unused-candidate-value 'model))
         (unused-route-value (.ref unused-candidate-model-value 'route)))
    (.o (kind 'poo-composition-lazy-demand-evidence)
        (family 'poo-composition-lazy-demand)
        (selected-route selected-route-value)
        (repeated-route repeated-route-value)
        (shared-route shared-route-value)
        (selected-image selected-image-value)
        (unused-route unused-route-value)
        (shared-model? shared-model?-value)
        (shared-model-route-force-count-before-full
         shared-model-route-force-count-before-full-value)
        (shared-model-route-force-count-after-full
         shared-model-route-force-count-value)
        (shared-sandbox-image-force-count-before-full
         shared-sandbox-image-force-count-before-full-value)
        (shared-sandbox-image-force-count-after-full
         shared-sandbox-image-force-count-value)
        (large-library-force-count large-library-force-count-value)
        (unused-route-force-count-before-full
         unused-route-force-count-before-full-value)
        (unused-route-force-count-after-full
         unused-model-route-force-count-value))))

(def (poo-performance-large-runtime-profile-valid-count* composition rounds)
  (let* ((family (.ref (car (.ref composition 'modules)) 'value))
         (stage (car (.ref composition 'stages)))
         (clause (car (.ref stage 'clauses)))
         (payload (.ref clause 'payload))
         (count (.ref payload 'count))
         (first-profile
          (poo-performance-large-runtime-profile-family-profile-at family 0))
         (last-profile
          (poo-performance-large-runtime-profile-family-profile-at
           family
           (- count 1))))
    (if (and (= count (.ref family 'count))
             (= (.ref family 'variant-count)
                +poo-performance-large-runtime-profile-variant-count+)
             (eq? (.ref first-profile 'name)
                  (poo-performance-large-runtime-profile-name 0))
             (eq? (.ref last-profile 'name)
                  (poo-performance-large-runtime-profile-name
                   (- count 1))))
      (if (poo-performance-large-runtime-profile-hot-path-pass? family)
        rounds
        0)
      0)))
