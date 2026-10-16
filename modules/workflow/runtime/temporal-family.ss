;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Inert wire projection onto the existing POO-native finite family engine.
(import (only-in :std/list/list every)
        (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :poo-flow/modules/temporal-causality/objects
                 poo-flow-temporal-clock-domain
                 poo-flow-temporal-model-observation
                 poo-flow-temporal-constraint poo-flow-temporal-hypothesis
                 poo-flow-temporal-query)
        (only-in :poo-flow/modules/temporal-causality/funs
                 poo-flow-temporal-model poo-flow-temporal-overlapping-model
                 poo-flow-temporal-model-classify))
(export temporal-family-values temporal-family-task temporal-family-call temporal-family-observe)

(def (field object key)
  (unless (and (hash-table? object) (hash-key? object key))
    (error "missing temporal family field" key))
  (hash-ref object key))
(def (text value)
  (unless (and (string? value) (< 0 (string-length value) 129))
    (error "invalid temporal family identity"))
  value)
(def (choice value allowed)
  (unless (and (string? value) (member value allowed))
    (error "unsupported temporal family enumeration" value))
  (string->symbol value))
(def (inventory value maximum)
  (unless (and (list? value) (<= (length value) maximum))
    (error "temporal family inventory exceeds bounds"))
  value)
(def (exact-fields object keys)
  (unless (and (hash-table? object) (= (hash-length object) (length keys)))
    (error "invalid temporal family fields"))
  (for-each (lambda (key) (field object key)) keys)
  object)

(def (temporal-family-values task)
  (exact-fields task ["profile" "model" "query"])
  (unless (equal? (field task "profile") "finite-hypothesis-family")
    (error "unsupported temporal semantic profile"))
  (let* ((m (exact-fields (field task "model")
             ["identity" "domains" "observations" "hypotheses" "complete" "mode"]))
         (q (exact-fields (field task "query") ["identity" "target" "limit"]))
         (domains
          (map (lambda (d)
                 (exact-fields d ["identity" "role"])
                 (poo-flow-temporal-clock-domain
                  (text (field d "identity")) (string->symbol (text (field d "role")))))
               (inventory (field m "domains") 32)))
         (observations
          (map (lambda (o)
                 (exact-fields o ["identity" "domain" "position" "provenance" "modality"])
                 (poo-flow-temporal-model-observation
                  (text (field o "identity")) (text (field o "domain"))
                  (field o "position") (text (field o "provenance"))
                  (choice (field o "modality") ["observed" "declared" "missing"])))
               (inventory (field m "observations") 128)))
         (constraint-count 0)
         (hypotheses
          (map (lambda (h)
                 (exact-fields h ["identity" "cause" "effect" "constraints"])
                 (poo-flow-temporal-hypothesis
                  (text (field h "identity")) (text (field h "cause"))
                  (text (field h "effect"))
                  (map (lambda (c)
                         (set! constraint-count (+ constraint-count 1))
                         (when (> constraint-count 256)
                           (error "temporal family constraint bounds exceeded"))
                         (exact-fields c ["identity" "relation" "left" "right"])
                         (poo-flow-temporal-constraint
                          (text (field c "identity"))
                          (choice (field c "relation") ["before" "not-after"])
                          (text (field c "left")) (text (field c "right"))))
                       (inventory (field h "constraints") 256))))
               (inventory (field m "hypotheses") 128)))
         (builder (case (choice (field m "mode")
                                ["exclusive-explanations" "overlapping-mechanisms"])
                    ((exclusive-explanations) poo-flow-temporal-model)
                    (else poo-flow-temporal-overlapping-model)))
         (model (builder (text (field m "identity")) domains observations
                         hypotheses (field m "complete")))
         (query (poo-flow-temporal-query
                 (text (field q "identity")) (text (field q "target"))
                 (field q "limit")))
         )
    (list model query)))

(def (temporal-family-call task)
  (let* ((values (temporal-family-values task))
         (model (car values)) (query (cadr values))
         (receipt (poo-flow-temporal-model-classify model query))
         (binding
          (hex-encode
           (sha256 (string->utf8
                    (call-with-output-string
                     (lambda (port)
                       (write (list 'poo-flow.temporal-family.binding.v1
                                    (.ref model 'semantic-digest)
                                    (.ref query 'identity)
                                    (.ref query 'hypothesis-identity)
                                    (.ref query 'exploration-limit)) port))))))))
    (hash (schema "poo-flow.temporal-family-result.v1")
          (profile "finite-hypothesis-family")
          (modelDigest (.ref model 'semantic-digest)) (bindingDigest binding)
          (classification (symbol->string (.ref receipt 'classification)))
          (admissible (.ref receipt 'admissible-hypothesis-ids))
          (refuted (.ref receipt 'refuted-hypothesis-ids))
          (unknown (.ref receipt 'unknown-hypothesis-ids))
          (unexplored (.ref receipt 'unexplored-hypothesis-ids))
          (exhausted (.ref receipt 'exhausted?))
          (familyComplete (.ref receipt 'family-complete?))
          (assumption (symbol->string (.ref receipt 'assumption)))
          (sourceAuthenticated #f) (actionAuthorized #f))))

;;; Replay current model/query, then compare the entire result envelope.
;;; A consistent observation proves finite-family result fidelity only.
(def (temporal-family-observe object)
  (exact-fields object ["task" "candidate"])
  (let* ((expected (temporal-family-call (field object "task")))
         (candidate (field object "candidate"))
         (matches
          (and (hash-table? candidate)
               (= (hash-length candidate) (hash-length expected))
               (every (lambda (key)
                         (and (hash-key? candidate (symbol->string key))
                              (equal? (hash-get expected key)
                                      (hash-get candidate (symbol->string key)))))
                       (hash-keys expected)))))
    (hash (schema "poo-flow.temporal-family-observation.v1")
          (verdict (if matches "consistent" "contradicted"))
          (claim "finite-family-result-fidelity")
          (bindingDigest (hash-get expected 'bindingDigest))
          (modelDigest (hash-get expected 'modelDigest))
          (sourceAuthenticated #f) (actionAuthorized #f))))

;;; Reify the original native premises, never a derived classification DTO.
(def (temporal-family-task model query)
  (hash (profile "finite-hypothesis-family")
        (model (hash (identity (.ref model 'identity))
          (mode (symbol->string (.ref model 'family-semantics)))
          (complete (.ref model 'family-complete?))
          (domains (map (lambda (d) (hash (identity (.ref d 'identity))
                                         (role (symbol->string (.ref d 'clock-role))))) (.ref model 'domains)))
          (observations (map (lambda (o) (hash (identity (.ref o 'identity))
             (domain (.ref o 'domain-identity)) (position (.ref o 'logical-position))
             (provenance (.ref o 'provenance-identity)) (modality (symbol->string (.ref o 'modality)))))
             (.ref model 'observations)))
          (hypotheses (map (lambda (h) (hash (identity (.ref h 'identity))
             (cause (.ref h 'cause-observation-id)) (effect (.ref h 'effect-observation-id))
             (constraints (map (lambda (c) (hash (identity (.ref c 'identity))
                 (relation (symbol->string (.ref c 'relation))) (left (.ref c 'left-observation-id))
                 (right (.ref c 'right-observation-id)))) (.ref h 'constraints))))) (.ref model 'hypotheses)))))
        (query (hash (identity (.ref query 'identity)) (target (.ref query 'hypothesis-identity))
                     (limit (.ref query 'exploration-limit))))))
