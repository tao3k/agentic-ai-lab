;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only session chunks, lineage, placement, and value objects.
;;; Invariant: this module describes session data; it never executes runtime work.

(import (only-in :clan/poo/object .o .ref object?))

(export agentic-ai-lab-session-require
        agentic-ai-lab-session-every?
        agentic-ai-lab-session-alist-ref
        agentic-ai-lab-session-chunk
        agentic-ai-lab-session-chunk?
        agentic-ai-lab-session-chunk-id
        agentic-ai-lab-session-chunk-role
        agentic-ai-lab-session-chunk-content
        agentic-ai-lab-session-lineage
        agentic-ai-lab-session-lineage?
        agentic-ai-lab-session-lineage-session-id
        agentic-ai-lab-session-lineage-parent-session-ids
        agentic-ai-lab-session-placement
        agentic-ai-lab-session-placement?
        agentic-ai-lab-session-placement-profile-ref
        agentic-ai-lab-session-placement-resolved?
        agentic-ai-lab-session-placement-diagnostics
        agentic-ai-lab-session-placement-runtime-summary
        agentic-ai-lab-session-placement-handoff-summary
        agentic-ai-lab-session-placement-copy
        agentic-ai-lab-session-placement-resolve
        agentic-ai-lab-session-value
        agentic-ai-lab-session?
        agentic-ai-lab-session-id
        agentic-ai-lab-session-chunks
        agentic-ai-lab-session-value-lineage
        agentic-ai-lab-session-value-placement
        agentic-ai-lab-session-metadata)

;;; Validation returns the original value so constructors can keep compact
;;; sequential guard clauses before building report-only session rows.
;; : (forall (a) (-> String Boolean a a))
(def (agentic-ai-lab-session-require message condition value)
  (if condition
    value
    (error message value)))

;;; Local list validation avoids bringing a heavier contract layer into the
;;; user-interface session declaration path.
;; : (-> Procedure List Boolean)
(def (agentic-ai-lab-session-every? predicate values)
  (cond
   ((null? values) #t)
   ((predicate (car values))
    (agentic-ai-lab-session-every? predicate (cdr values)))
   (else #f)))

;;; Alist lookup is shared by chunk rows and tests because chunks remain simple
;;; wire data while session values are POO objects.
;; : (forall (a) (-> Alist Symbol a a))
(def (agentic-ai-lab-session-alist-ref entries key default)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default)))

;;; Compact optional diagnostic rows without depending on a broader list
;;; library in this low-level user-interface module.
;; : (forall (a) (-> (List (U #f a)) (List a)))
(def (agentic-ai-lab-session-compact values)
  (filter (lambda (value) value) values))

;;; Session row assembly is projection-only. It preserves field order without
;;; creating another declaration or runtime adapter language.
;; agentic-ai-lab-session-rows/tail
;;   : (-> Alist Alist Alist)
;;   | contract: ordered session projection rows followed by tail rows
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-session-rows/tail '((kind . session)) '((metadata)))
;;       ;; => ((kind . session) (metadata))
;;       ```
;;     %
(def (agentic-ai-lab-session-rows/tail rows tail)
  (append rows tail))

;; agentic-ai-lab-session-field-rows/tail
;;   : (-> Alist SessionFieldRow... Alist)
;;   | contract: lower fixed field clauses and append caller-owned tail rows
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-session-field-rows/tail '((tail . value)) (kind 'session))
;;       ;; => ((kind . session) (tail . value))
;;       ```
;;     %
(def (agentic-ai-lab-session-field-rows/tail tail . rows)
  (agentic-ai-lab-session-rows/tail rows tail))

;;; Chunks are receipt rows, not extension surfaces. Keeping them as primitive
;;; rows prevents presentation code from repeatedly instantiating child POO
;;; objects while still preserving typed user-visible data.
;; : (-> Symbol Symbol String [Alist] PooSessionChunk)
(def (agentic-ai-lab-session-chunk chunk-id role content . maybe-metadata)
  (agentic-ai-lab-session-require "session chunk id must be a symbol"
                            (symbol? chunk-id)
                            chunk-id)
  (agentic-ai-lab-session-require "session chunk role must be a symbol"
                            (symbol? role)
                            role)
  (agentic-ai-lab-session-require "session chunk content must be a string"
                            (string? content)
                            content)
  (list (cons 'kind 'agentic-ai-lab.session.chunk)
        (cons 'schema 'agentic-ai-lab.modules.session.chunk.v1)
        (cons 'chunk-id chunk-id)
        (cons 'role role)
        (cons 'content content)
        (cons 'visibility 'public)
        (cons 'metadata (if (null? maybe-metadata) '() (car maybe-metadata)))
        (cons 'runtime-executed #f)))

;;; Chunk predicates stay alist-based by design: a session may contain many
;;; chunks, so each row must be cheap to validate inside graph traversals.
;; : (-> SessionDatum Boolean)
;; | type SessionDatum = Any
(def (agentic-ai-lab-session-chunk? value)
  (and (list? value)
       (eq? (agentic-ai-lab-session-alist-ref value 'kind #f)
            'agentic-ai-lab.session.chunk)))

;; : (-> PooSessionChunk Symbol)
(def (agentic-ai-lab-session-chunk-id chunk)
  (agentic-ai-lab-session-alist-ref chunk 'chunk-id #f))

;; : (-> PooSessionChunk Symbol)
(def (agentic-ai-lab-session-chunk-role chunk)
  (agentic-ai-lab-session-alist-ref chunk 'role #f))

;; : (-> PooSessionChunk String)
(def (agentic-ai-lab-session-chunk-content chunk)
  (agentic-ai-lab-session-alist-ref chunk 'content #f))

;;; Lineage is a mixin prototype. Its slots are inherited by the final session
;;; object, so callers inspect direct session slots instead of a nested lineage
;;; child object.
;; : (-> Symbol [Symbol] Symbol [Alist] PooSessionLineage)
(def (agentic-ai-lab-session-lineage session-id parent-session-ids branch-kind
                               . maybe-metadata)
  (agentic-ai-lab-session-require "session lineage id must be a symbol"
                            (symbol? session-id)
                            session-id)
  (agentic-ai-lab-session-require "session lineage parents must be a list"
                            (list? parent-session-ids)
                            parent-session-ids)
  (agentic-ai-lab-session-require
   "session lineage parents must contain only symbols"
   (agentic-ai-lab-session-every? symbol? parent-session-ids)
   parent-session-ids)
  (agentic-ai-lab-session-require "session lineage branch kind must be a symbol"
                            (symbol? branch-kind)
                            branch-kind)
  (let ((lineage-session-id-value session-id)
        (lineage-parent-session-ids-value parent-session-ids)
        (lineage-branch-kind-value branch-kind)
        (lineage-metadata-value
         (if (null? maybe-metadata) '() (car maybe-metadata))))
    (.o lineage-kind: 'agentic-ai-lab.session.lineage
        lineage-schema: 'agentic-ai-lab.modules.session.lineage.v1
        lineage-session-id: lineage-session-id-value
        parent-session-ids: lineage-parent-session-ids-value
        branch-kind: lineage-branch-kind-value
        lineage-metadata: lineage-metadata-value
        lineage-runtime-executed: #f)))

;; : (-> SessionDatum Boolean)
;; | type SessionDatum = Any
(def (agentic-ai-lab-session-lineage? value)
  (and (object? value)
       (eq? (.ref value 'lineage-kind)
            'agentic-ai-lab.session.lineage)))

;;; The lineage id accessor is used before composition to prove the mixin
;;; belongs to the session being built.
;; : (-> PooSessionLineage Symbol)
(def (agentic-ai-lab-session-lineage-session-id lineage)
  (.ref lineage 'lineage-session-id))

;; : (-> PooSessionLineage [Symbol])
(def (agentic-ai-lab-session-lineage-parent-session-ids lineage)
  (.ref lineage 'parent-session-ids))

;;; Placement is also a mixin prototype. Backend resolution remains report-only
;;; here; real sandbox execution is owned by Marlin or a backend runtime.
;; : (-> Symbol [Alist] PooSessionPlacement)
(def (agentic-ai-lab-session-placement profile-ref . maybe-metadata)
  (agentic-ai-lab-session-require "session placement profile ref must be a symbol"
                            (symbol? profile-ref)
                            profile-ref)
  (let ((placement-profile-ref-value profile-ref)
        (placement-metadata-value
         (if (null? maybe-metadata) '() (car maybe-metadata))))
    (.o placement-kind: 'agentic-ai-lab.session.placement
        placement-schema: 'agentic-ai-lab.modules.session.placement.v1
        placement-profile-ref: placement-profile-ref-value
        placement-resolved?: #f
        placement-diagnostics: '()
        placement-runtime-summary: '()
        placement-handoff-summary: '()
        placement-metadata: placement-metadata-value
        placement-runtime-executed: #f)))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-session-placement? value)
  (and (object? value)
       (eq? (.ref value 'placement-kind)
            'agentic-ai-lab.session.placement)))

;; : (-> PooSessionPlacement Symbol)
(def (agentic-ai-lab-session-placement-profile-ref placement)
  (.ref placement 'placement-profile-ref))

;; : (-> PooSessionPlacement Boolean)
(def (agentic-ai-lab-session-placement-resolved? placement)
  (.ref placement 'placement-resolved?))

;; : (-> PooSessionPlacement [Alist])
(def (agentic-ai-lab-session-placement-diagnostics placement)
  (.ref placement 'placement-diagnostics))

;; : (-> PooSessionPlacement Alist)
(def (agentic-ai-lab-session-placement-runtime-summary placement)
  (.ref placement 'placement-runtime-summary))

;; : (-> PooSessionPlacement Alist)
(def (agentic-ai-lab-session-placement-handoff-summary placement)
  (.ref placement 'placement-handoff-summary))

;;; Project the placement slots out of a composed session before reusing them as
;;; a prototype. Re-inheriting a full session object would recursively drag the
;;; source session graph into derived sessions.
;; : (-> PooSessionPlacement PooSessionPlacement)
(def (agentic-ai-lab-session-placement-copy placement)
  (.o placement-kind: (.ref placement 'placement-kind)
      placement-schema: (.ref placement 'placement-schema)
      placement-profile-ref: (.ref placement 'placement-profile-ref)
      placement-resolved?: (.ref placement 'placement-resolved?)
      placement-diagnostics: (.ref placement 'placement-diagnostics)
      placement-runtime-summary: (.ref placement 'placement-runtime-summary)
      placement-handoff-summary: (.ref placement 'placement-handoff-summary)
      placement-metadata: (.ref placement 'placement-metadata)
      placement-runtime-executed: (.ref placement 'placement-runtime-executed)))

;;; Session placement resolves against POO profile recipes without importing the
;;; full sandbox config layer. Strict descriptor validation stays at the sandbox
;;; owner; this object layer only records catalog linkage and report-only slots.
;; : (-> POOObject Symbol Value Value)
(def (agentic-ai-lab-session-profile-slot profile key default-value)
  (with-catch
   (lambda (_failure) default-value)
   (lambda ()
     (.ref profile key))))

;; : (-> POOObject Symbol)
(def (agentic-ai-lab-session-profile-name profile)
  (agentic-ai-lab-session-profile-slot profile 'name #f))

;;; Boundary: session profile by name is the policy-visible edge for object
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [POOObject] Symbol MaybePOOObject)
(def (agentic-ai-lab-session-profile-by-name profiles name)
  (cond
   ((null? profiles) #f)
   ((eq? (agentic-ai-lab-session-profile-name (car profiles)) name)
    (car profiles))
   (else
    (agentic-ai-lab-session-profile-by-name (cdr profiles) name))))

;; : (-> Symbol POOObject Alist Alist)
(def (agentic-ai-lab-session-profile-runtime-summary/tail profile-ref profile tail)
  (agentic-ai-lab-session-rows/tail
   (list
    (cons 'profile-name (agentic-ai-lab-session-profile-name profile))
    (cons 'profile-ref profile-ref)
    (cons 'backend-kind
          (agentic-ai-lab-session-profile-slot profile 'backend-kind 'unknown))
    (cons 'backend-ref
          (agentic-ai-lab-session-profile-slot profile 'backend-ref 'unknown))
    (cons 'network-policy
          (agentic-ai-lab-session-profile-slot profile 'network-policy '()))
    (cons 'capabilities
          (agentic-ai-lab-session-profile-slot profile 'capabilities '()))
    (cons 'resource-policy
          (agentic-ai-lab-session-profile-slot profile 'resource-policy '()))
    (cons 'runtime-owner "marlin-agent-core")
    (cons 'catalog-resolved? #t)
    (cons 'descriptor-realized? #f)
    (cons 'runtime-executed #f))
   tail))

;; : (-> Symbol POOObject Alist)
(def (agentic-ai-lab-session-profile-runtime-summary profile-ref profile)
  (agentic-ai-lab-session-profile-runtime-summary/tail profile-ref profile '()))

;; : (-> Symbol POOObject Alist)
(def (agentic-ai-lab-session-profile-handoff-summary profile-ref profile)
  (agentic-ai-lab-session-profile-runtime-summary/tail
   profile-ref
   profile
   '((handoff-required . #t))))

;; : (-> Symbol Symbol POOObject Alist)
(def (agentic-ai-lab-session-placement-summary-failure profile-ref phase failure)
  (list (cons 'kind 'agentic-ai-lab.session.placement.diagnostic)
        (cons 'status 'summary-failed)
        (cons 'profile-ref profile-ref)
        (cons 'phase phase)
        (cons 'message (object->string failure))))

;; : (-> Symbol Alist)
(def (agentic-ai-lab-session-placement-missing-diagnostic profile-ref)
  (list (cons 'kind 'agentic-ai-lab.session.placement.diagnostic)
        (cons 'status 'missing-profile)
        (cons 'profile-ref profile-ref)
        (cons 'message "placement profile was not found in the catalog")))

;;; Summary projection is report-only. A malformed sandbox profile becomes a
;;; diagnostic row instead of aborting session graph construction.
;; : (-> Symbol Symbol Procedure POOObject Pair)
(def (agentic-ai-lab-session-placement-summary profile-ref phase summarizer profile)
  (with-catch
   (lambda (failure)
     (cons '()
           (agentic-ai-lab-session-placement-summary-failure
            profile-ref
            phase
            failure)))
   (lambda ()
     (cons (summarizer profile-ref profile) #f))))

;;; Resolve a placement ref against an existing sandbox profile catalog. The
;;; returned value is still a placement mixin prototype; it records validation
;;; receipts but never realizes or executes a sandbox runtime.
;; : (-> Symbol [PooSandboxProfile] [Alist] PooSessionPlacement)
(def (agentic-ai-lab-session-placement-resolve profile-ref profiles . maybe-metadata)
  (agentic-ai-lab-session-require "session placement profile ref must be a symbol"
                            (symbol? profile-ref)
                            profile-ref)
  (agentic-ai-lab-session-require "session placement catalog must be a list"
                            (list? profiles)
                            profiles)
  (let* ((profile-ref-value profile-ref)
         (profile (agentic-ai-lab-session-profile-by-name profiles profile-ref-value))
         (placement-metadata-value
          (if (null? maybe-metadata) '() (car maybe-metadata))))
    (if profile
      (let* ((runtime-result
              (agentic-ai-lab-session-placement-summary
               profile-ref-value
               'runtime-summary
               agentic-ai-lab-session-profile-runtime-summary
               profile))
             (handoff-result
              (agentic-ai-lab-session-placement-summary
               profile-ref-value
               'handoff-summary
               agentic-ai-lab-session-profile-handoff-summary
               profile))
             (runtime-summary-value (car runtime-result))
             (handoff-summary-value (car handoff-result))
             (diagnostics-value
              (agentic-ai-lab-session-compact
               (list (cdr runtime-result) (cdr handoff-result))))
             (resolved-value
              (and runtime-summary-value
                   handoff-summary-value
                   (null? diagnostics-value))))
        (.o placement-kind: 'agentic-ai-lab.session.placement
            placement-schema: 'agentic-ai-lab.modules.session.placement.v1
            placement-profile-ref: profile-ref-value
            placement-resolved?: resolved-value
            placement-diagnostics: diagnostics-value
            placement-runtime-summary: runtime-summary-value
            placement-handoff-summary: handoff-summary-value
            placement-metadata: placement-metadata-value
            placement-runtime-executed: #f))
      (.o placement-kind: 'agentic-ai-lab.session.placement
          placement-schema: 'agentic-ai-lab.modules.session.placement.v1
          placement-profile-ref: profile-ref-value
          placement-resolved?: #f
          placement-diagnostics:
          (list (agentic-ai-lab-session-placement-missing-diagnostic
                 profile-ref-value))
          placement-runtime-summary: '()
          placement-handoff-summary: '()
          placement-metadata: placement-metadata-value
          placement-runtime-executed: #f))))

;;; Compose lineage and placement with C4 POO inheritance. Local variable names
;;; intentionally differ from slot names to avoid fixed-point self-reference
;;; such as `chunks: chunks`.
;; : (-> Symbol [PooSessionChunk] PooSessionLineage PooSessionPlacement [Alist] PooSession)
(def (agentic-ai-lab-session-value session-id chunks lineage placement . maybe-metadata)
  (agentic-ai-lab-session-require "session id must be a symbol"
                            (symbol? session-id)
                            session-id)
  (agentic-ai-lab-session-require "session chunks must be a list"
                            (list? chunks)
                            chunks)
  (agentic-ai-lab-session-require "session chunks must contain only session chunks"
                            (agentic-ai-lab-session-every?
                             agentic-ai-lab-session-chunk?
                             chunks)
                            chunks)
  (agentic-ai-lab-session-require "session lineage must match the session id"
                            (and (agentic-ai-lab-session-lineage? lineage)
                                 (eq? (agentic-ai-lab-session-lineage-session-id
                                       lineage)
                                      session-id))
                            lineage)
  (agentic-ai-lab-session-require "session placement must be a session placement"
                            (agentic-ai-lab-session-placement? placement)
                            placement)
  (let ((session-id-value session-id)
        (chunk-values chunks)
        (lineage-prototype lineage)
        (placement-prototype placement)
        (session-metadata-value
         (agentic-ai-lab-session-field-rows/tail
          (if (null? maybe-metadata)
            '()
            (car maybe-metadata))
          (cons 'declared-by 'agentic-ai-lab-session-module)
          (cons 'runtime-executed #f))))
    (.o (:: @ [lineage-prototype placement-prototype])
        kind: 'agentic-ai-lab.session.value
        schema: 'agentic-ai-lab.modules.session.value.v1
        session-id: session-id-value
        chunks: chunk-values
        metadata: session-metadata-value
        runtime-executed: #f)))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-session? value)
  (and (object? value)
       (eq? (.ref value 'kind) 'agentic-ai-lab.session.value)))

;; : (-> PooSession Symbol)
(def (agentic-ai-lab-session-id session)
  (.ref session 'session-id))

;; : (-> PooSession [PooSessionChunk])
(def (agentic-ai-lab-session-chunks session)
  (.ref session 'chunks))

;; : (-> PooSession PooSessionLineage)
(def (agentic-ai-lab-session-value-lineage session)
  session)

;; : (-> PooSession PooSessionPlacement)
(def (agentic-ai-lab-session-value-placement session)
  (agentic-ai-lab-session-placement-copy session))

;; : (-> PooSession Alist)
(def (agentic-ai-lab-session-metadata session)
  (.ref session 'metadata))
