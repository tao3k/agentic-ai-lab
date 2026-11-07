;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure admission relative to an explicitly trusted source-owner snapshot.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element? validate)
        (only-in :std/list/list every)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :agentic-ai-lab/modules/temporal-causality/types
                 agentic-ai-lab-temporal-model? agentic-ai-lab-temporal-query?)
        (only-in :agentic-ai-lab/modules/temporal-causality/funs
                 agentic-ai-lab-temporal-model-replay agentic-ai-lab-temporal-model-classify)
        (only-in :agentic-ai-lab/modules/temporal-causality/conclusions/types
                 agentic-ai-lab-temporal-conclusion-revision?)
        (only-in :agentic-ai-lab/modules/temporal-causality/conclusions/funs
                 agentic-ai-lab-temporal-conclusion-root))
(export AgenticAILabTemporalSourceSnapshot AgenticAILabTemporalFamilyAdmission
        agentic-ai-lab-temporal-source-snapshot? agentic-ai-lab-temporal-family-admission?
        agentic-ai-lab-temporal-source-snapshot agentic-ai-lab-temporal-source-snapshot-replay
        agentic-ai-lab-temporal-family-admit agentic-ai-lab-temporal-family-admission-replay)

(def (text? v) (and (string? v) (< 0 (string-length v) 129)))
(def (slots? v names)
  (and (object? v) (every (lambda (s) (.slot? v s)) names)))
(def metadata '(identity authority-identity subject-identity scope-identity
                       cut-digest projection-digest policy-identity generation))
(def (snapshot-shape? v)
  (and (slots? v (append '(kind semantic-digest model) metadata))
       (eq? (.ref v 'kind) 'agentic-ai-lab.temporal-causality.source-snapshot.v1)
       (every text? (map (lambda (s) (.ref v s)) (reverse (cdr (reverse metadata)))))
       (string? (.ref v 'semantic-digest))
       (exact-integer? (.ref v 'generation)) (>= (.ref v 'generation) 0)
       (agentic-ai-lab-temporal-model? (.ref v 'model))))
(define-type (AgenticAILabTemporalSourceSnapshot @ Type.) .element?: snapshot-shape?)
(def (agentic-ai-lab-temporal-source-snapshot? v) (element? AgenticAILabTemporalSourceSnapshot v))
(def (admission-shape? v)
  (and (slots? v '(kind semantic-digest source-digest model-digest query-identity
                        classification conclusion source model query conclusion-identity
                        source-authenticated? action-authorized?))
       (eq? (.ref v 'kind) 'agentic-ai-lab.temporal-causality.family-admission.v1)
       (every string? (map (lambda (s) (.ref v s))
                          '(semantic-digest source-digest model-digest query-identity)))
       (memq (.ref v 'classification) '(possible necessary refuted))
       (agentic-ai-lab-temporal-conclusion-revision? (.ref v 'conclusion))
       (agentic-ai-lab-temporal-source-snapshot? (.ref v 'source))
       (agentic-ai-lab-temporal-model? (.ref v 'model))
       (agentic-ai-lab-temporal-query? (.ref v 'query))
       (text? (.ref v 'conclusion-identity))
       (eq? (.ref v 'source-authenticated?) #f)
       (eq? (.ref v 'action-authorized?) #f)))
(define-type (AgenticAILabTemporalFamilyAdmission @ Type.) .element?: admission-shape?)
(def (agentic-ai-lab-temporal-family-admission? v) (element? AgenticAILabTemporalFamilyAdmission v))
(def (digest row)
  (string-append "sha256:" (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (p) (write row p))))))))
(def (evidence-row model)
  (let (model (agentic-ai-lab-temporal-model-replay model))
    (list
     (map (lambda (d) (list (.ref d 'identity) (.ref d 'clock-role))) (.ref model 'domains))
     (map (lambda (o)
            (map (lambda (s) (.ref o s))
                 '(identity domain-identity logical-position provenance-identity modality)))
          (.ref model 'observations)))))

;;; The authority assertion is an explicit premise. Runtime must choose this
;;; snapshot from its host control lane, not accept it from a model payload.
(def (agentic-ai-lab-temporal-source-snapshot id authority subject scope cut projection policy generation-value model)
  (unless (and (every text? (list id authority subject scope cut projection policy))
               (exact-integer? generation-value) (>= generation-value 0))
    (error "invalid source snapshot scope"))
  (let* ((canonical (agentic-ai-lab-temporal-model-replay model))
         (binding (digest (list 'agentic-ai-lab.temporal-source-snapshot.v1 id authority
                                subject scope cut projection policy generation-value
                                (evidence-row canonical)))))
    (validate AgenticAILabTemporalSourceSnapshot
      (.o kind: 'agentic-ai-lab.temporal-causality.source-snapshot.v1
          identity: id authority-identity: authority subject-identity: subject
          scope-identity: scope cut-digest: cut projection-digest: projection
          policy-identity: policy generation: generation-value model: canonical
          semantic-digest: binding))))
(def (agentic-ai-lab-temporal-source-snapshot-replay source)
  (unless (agentic-ai-lab-temporal-source-snapshot? source) (error "invalid source snapshot"))
  (let (replayed (apply agentic-ai-lab-temporal-source-snapshot
                       (append (map (lambda (s) (.ref source s)) metadata)
                               (list (.ref source 'model)))))
    (unless (equal? (.ref replayed 'semantic-digest) (.ref source 'semantic-digest))
      (error "source snapshot digest mismatch"))
    replayed))

(def (agentic-ai-lab-temporal-family-admit model query source conclusion-id)
  (unless (and (agentic-ai-lab-temporal-query? query) (text? conclusion-id))
    (error "invalid family admission query"))
  (agentic-ai-lab-temporal-source-snapshot-replay source)
  (unless (equal? (evidence-row model) (evidence-row (.ref source 'model)))
    (error "family observations differ from registered source"))
  (let* ((receipt (agentic-ai-lab-temporal-model-classify model query))
         (classification-value (.ref receipt 'classification))
         (_ (when (eq? classification-value 'unknown)
              (error "unresolved family cannot admit a conclusion")))
         (proof (digest (list 'agentic-ai-lab.temporal-family-proof.v1
                             (.ref source 'semantic-digest) (.ref model 'semantic-digest)
                             (.ref query 'identity) (.ref query 'hypothesis-identity)
                             (.ref query 'exploration-limit) classification-value
                             (.ref receipt 'admissible-hypothesis-ids)
                             (.ref receipt 'refuted-hypothesis-ids)
                             (.ref receipt 'unknown-hypothesis-ids)
                             (.ref receipt 'unexplored-hypothesis-ids)
                             (.ref receipt 'exhausted?))))
         (revision-id
          (digest (list 'agentic-ai-lab.temporal-admitted-conclusion.v1 conclusion-id proof)))
         (conclusion-value
          (agentic-ai-lab-temporal-conclusion-root
           revision-id (.ref source 'subject-identity) (.ref source 'scope-identity)
           (.ref source 'cut-digest) (.ref source 'projection-digest)
           (.ref source 'policy-identity) (number->string (.ref source 'generation))
           proof proof))
         ;; POO slots are lazy: retain lexical inputs under distinct names.
         (source-value source) (model-value model) (query-value query))
    (validate AgenticAILabTemporalFamilyAdmission
      (.o kind: 'agentic-ai-lab.temporal-causality.family-admission.v1
          semantic-digest: (digest (list proof conclusion-id))
          source-digest: (.ref source 'semantic-digest)
          model-digest: (.ref model 'semantic-digest)
          query-identity: (.ref query 'identity) classification: classification-value
          conclusion: conclusion-value source: source-value model: model-value query: query-value
          conclusion-identity: conclusion-id
          source-authenticated?: #f action-authorized?: #f))))

;;; Replay original premises; a caller-authored digest or classification is not proof.
(def (agentic-ai-lab-temporal-family-admission-replay admission)
  (unless (agentic-ai-lab-temporal-family-admission? admission)
    (error "invalid family admission"))
  (let (canonical
        (agentic-ai-lab-temporal-family-admit
         (.ref admission 'model) (.ref admission 'query) (.ref admission 'source)
         (.ref admission 'conclusion-identity)))
    (unless (and
             (every (lambda (slot) (equal? (.ref canonical slot) (.ref admission slot)))
                    '(semantic-digest source-digest model-digest query-identity classification))
             (every (lambda (slot)
                      (equal? (.ref (.ref canonical 'conclusion) slot)
                              (.ref (.ref admission 'conclusion) slot)))
                    '(identity subject-identity scope-identity cut-digest projection-digest
                      policy-identity generation-identity operation predecessor-identity
                      result-identity proof-identity invalidation-index-digest)))
      (error "family admission differs from replayed premises"))
    canonical))
