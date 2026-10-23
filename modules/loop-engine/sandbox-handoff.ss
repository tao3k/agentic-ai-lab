;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine sandbox profile refs and handoff agreement receipts.
;;; Invariant: missing or invalid profiles become diagnostics, never runtime IO.

(import
        (only-in :agentic-ai-lab/modules/agent-sandbox/config
                 agentic-ai-lab-sandbox-profile-by-name
                 agentic-ai-lab-sandbox-profile-handoff-summary
                 agentic-ai-lab-sandbox-profile-runtime-summary)
        "intent-utils.ss")

(export +agentic-ai-lab-user-loop-engine-sandbox-handoff-agreement-contract+
        agentic-ai-lab-user-loop-engine-sandbox-entry-profile-ref
        agentic-ai-lab-user-loop-engine-profile-ref-member?
        agentic-ai-lab-user-loop-engine-profile-ref-add
        agentic-ai-lab-user-loop-engine-sandbox-profile-refs/add
        agentic-ai-lab-user-loop-engine-sandbox-profile-refs
        agentic-ai-lab-user-loop-engine-sandbox-profile-ref->profile
        agentic-ai-lab-user-loop-engine-sandbox-profile-ref->runtime-summary
        agentic-ai-lab-user-loop-engine-sandbox-profile-ref->handoff-summary
        agentic-ai-lab-user-loop-engine-sandbox-runtime-summaries
        agentic-ai-lab-user-loop-engine-sandbox-handoff-summaries
        agentic-ai-lab-user-loop-engine-sandbox-unresolved-profile-refs
        agentic-ai-lab-user-loop-engine-sandbox-handoff-agreement)

;;; Sandbox handoff agreement is the loop-engine receipt that compares declared
;;; refs, runtime summaries, and bridge-ready handoff summaries without raising.
;; : Symbol
(def +agentic-ai-lab-user-loop-engine-sandbox-handoff-agreement-contract+
  'agentic-ai-lab.loop-engine.sandbox-handoff-agreement.v1)

;;; Sandbox entries accept profile rows and per-use-case shorthand. Returning
;;; `#f` keeps malformed rows visible to unresolved-ref diagnostics.
;; : (-> Value [Symbol] MaybeSymbol)
(def (agentic-ai-lab-user-loop-engine-sandbox-entry-profile-ref entry use-case-names)
  (cond
   ((symbol? entry) entry)
   ((and (pair? entry)
         (eq? (car entry) 'profile)
         (symbol? (cdr entry)))
    (cdr entry))
   ((and (pair? entry)
         (symbol? (car entry))
         (agentic-ai-lab-user-loop-engine-use-case-name? (car entry)
                                                   use-case-names)
         (symbol? (cdr entry)))
    (cdr entry))
   (else #f)))

;;; Profile ref membership is Boolean-normalized for deterministic duplicate
;;; filtering in profile-ref accumulation.
;; : (-> Symbol [Symbol] Boolean)
(def (agentic-ai-lab-user-loop-engine-profile-ref-member? value refs)
  (and (member value refs) #t))

;;; Profile refs preserve first declaration order. Later duplicates do not
;;; change the runtime handoff order.
;; : (forall (a) (-> [a] [a] [a]))
(def (agentic-ai-lab-user-loop-engine-values/tail values tail)
  (foldr cons tail values))

;; : (-> MaybeSymbol [Symbol] [Symbol])
(def (agentic-ai-lab-user-loop-engine-profile-ref-add value refs)
  (if (and value
           (not (agentic-ai-lab-user-loop-engine-profile-ref-member? value refs)))
    (agentic-ai-lab-user-loop-engine-values/tail refs (list value))
    refs))

;;; Sandbox profile refs are collected from user rows without resolving the
;;; profile catalog so missing refs can be reported separately.
;; : (-> [Value] [Symbol] [Symbol] [Symbol])
(def (agentic-ai-lab-user-loop-engine-sandbox-profile-refs/add entries
                                                         use-case-names
                                                         refs)
  (cond
   ((null? entries) refs)
   (else
    (agentic-ai-lab-user-loop-engine-sandbox-profile-refs/add
     (cdr entries)
     use-case-names
     (agentic-ai-lab-user-loop-engine-profile-ref-add
      (agentic-ai-lab-user-loop-engine-sandbox-entry-profile-ref
       (car entries)
       use-case-names)
      refs)))))

;; : (-> Alist [Symbol])
(def (agentic-ai-lab-user-loop-engine-sandbox-profile-refs intent)
  (agentic-ai-lab-user-loop-engine-sandbox-profile-refs/add
   (agentic-ai-lab-user-loop-engine-intent-ref intent 'sandbox '())
   (agentic-ai-lab-user-loop-engine-use-case-names intent)
   '()))

;;; Sandbox profile lookup is intentionally catalog-only here; loop-engine
;;; projection must not construct or repair profiles during presentation.
;; : (-> Symbol [PooSandboxProfile] MaybePooSandboxProfile)
(def (agentic-ai-lab-user-loop-engine-sandbox-profile-ref->profile profile-ref
                                                             profile-catalog)
  (agentic-ai-lab-sandbox-profile-by-name profile-catalog profile-ref))

;;; Runtime summaries are optional evidence rows. Missing profiles are surfaced
;;; by the unresolved-ref scan instead of throwing inside this lookup.
;; : (-> Symbol [PooSandboxProfile] MaybeAlist)
(def (agentic-ai-lab-user-loop-engine-sandbox-profile-ref->runtime-summary
      profile-ref
      profile-catalog)
  (let (profile
        (agentic-ai-lab-user-loop-engine-sandbox-profile-ref->profile
         profile-ref
         profile-catalog))
    (and profile (agentic-ai-lab-sandbox-profile-runtime-summary profile))))

;;; Handoff summaries follow the same optional lookup path as runtime summaries
;;; so presentation can report partial profile catalogs deterministically.
;; : (-> Symbol [PooSandboxProfile] MaybeAlist)
(def (agentic-ai-lab-user-loop-engine-sandbox-profile-ref->handoff-summary
      profile-ref
      profile-catalog)
  (let* ((profile
          (agentic-ai-lab-user-loop-engine-sandbox-profile-ref->profile
           profile-ref
           profile-catalog))
         (runtime-summary
          (and profile (agentic-ai-lab-sandbox-profile-runtime-summary profile))))
    (and profile
         (agentic-ai-lab-user-loop-engine-intent-ref
          runtime-summary
          'valid?
          #f)
         (agentic-ai-lab-sandbox-profile-handoff-summary profile))))

;;; Runtime summary collection preserves reference order and skips missing
;;; profiles; unresolved refs are recorded by a sibling diagnostic pass.
;; : (forall (a b) (-> [a] [b] [Alist]))
;; : (-> [Symbol] [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-user-loop-engine-sandbox-runtime-summaries refs profile-catalog)
  (cond
   ((null? refs) '())
   ((agentic-ai-lab-user-loop-engine-sandbox-profile-ref->runtime-summary
     (car refs)
     profile-catalog)
    => (lambda (summary)
         (cons summary
               (agentic-ai-lab-user-loop-engine-sandbox-runtime-summaries
                (cdr refs)
                profile-catalog))))
   (else
    (agentic-ai-lab-user-loop-engine-sandbox-runtime-summaries
     (cdr refs)
     profile-catalog))))

;;; Handoff summary collection mirrors runtime summary collection so the two
;;; projections stay comparable in tests and presentation traces.
;; : (forall (a b) (-> [a] [b] [Alist]))
;; : (-> [Symbol] [PooSandboxProfile] [Alist])
(def (agentic-ai-lab-user-loop-engine-sandbox-handoff-summaries refs profile-catalog)
  (cond
   ((null? refs) '())
   ((agentic-ai-lab-user-loop-engine-sandbox-profile-ref->handoff-summary
     (car refs)
     profile-catalog)
    => (lambda (summary)
         (cons summary
               (agentic-ai-lab-user-loop-engine-sandbox-handoff-summaries
                (cdr refs)
                profile-catalog))))
   (else
    (agentic-ai-lab-user-loop-engine-sandbox-handoff-summaries
     (cdr refs)
     profile-catalog))))

;;; Unresolved refs are the safety channel for profile catalog holes. This keeps
;;; runtime handoff pure while still rejecting fake completeness in tests.
;; : (-> [Symbol] [PooSandboxProfile] [Symbol])
(def (agentic-ai-lab-user-loop-engine-sandbox-unresolved-profile-refs refs
                                                                profile-catalog)
  (cond
   ((null? refs) '())
   ((agentic-ai-lab-user-loop-engine-sandbox-profile-ref->profile
     (car refs)
     profile-catalog)
    (agentic-ai-lab-user-loop-engine-sandbox-unresolved-profile-refs
     (cdr refs)
     profile-catalog))
   (else
    (cons (car refs)
          (agentic-ai-lab-user-loop-engine-sandbox-unresolved-profile-refs
           (cdr refs)
           profile-catalog)))))

;;; Invalid runtime summaries stay reportable facts. They are not filtered out
;;; of the intent because doctor and handoff agreement need the validation rows.
;; : (-> [Alist] [Alist])
(def (agentic-ai-lab-user-loop-engine-invalid-sandbox-runtime-summaries summaries)
  (filter agentic-ai-lab-user-loop-engine-invalid-sandbox-runtime-summary?
          summaries))

;; : (-> Alist Boolean)
(def (agentic-ai-lab-user-loop-engine-invalid-sandbox-runtime-summary? summary)
  (not (agentic-ai-lab-user-loop-engine-intent-ref summary 'valid? #f)))

;;; Agreement diagnostics are aggregate rows so presentation and Testing Policy
;;; can report one actionable sandbox issue per loop intent, not one per mount.
;; : (-> [Symbol] [Alist] [Alist] [Symbol] [Alist])
(def (agentic-ai-lab-user-loop-engine-sandbox-handoff-agreement-diagnostics
      refs
      runtime-summaries
      handoff-summaries
      unresolved-refs)
  (let ((invalid-runtime-summaries
         (agentic-ai-lab-user-loop-engine-invalid-sandbox-runtime-summaries
          runtime-summaries)))
    (append
     (if (null? unresolved-refs)
       '()
       (list
        (list (cons 'field 'sandbox-profile-refs)
              (cons 'code 'unresolved-sandbox-profile-refs)
              (cons 'profile-refs unresolved-refs))))
     (if (null? invalid-runtime-summaries)
       '()
       (list
        (list (cons 'field 'sandbox-runtime-summaries)
              (cons 'code 'invalid-sandbox-runtime-summaries)
              (cons 'summary-count (length invalid-runtime-summaries))
              (cons 'summaries invalid-runtime-summaries))))
     (if (= (length refs)
            (+ (length handoff-summaries)
               (length unresolved-refs)
               (length invalid-runtime-summaries)))
       '()
       (list
        (list (cons 'field 'sandbox-handoff-summaries)
              (cons 'code 'sandbox-handoff-summary-count-mismatch)
              (cons 'profile-ref-count (length refs))
              (cons 'handoff-summary-count (length handoff-summaries))
              (cons 'unresolved-profile-ref-count
                    (length unresolved-refs))
              (cons 'invalid-runtime-summary-count
                    (length invalid-runtime-summaries))))))))

;;; The agreement is the stable loop-engine view over sandbox readiness. It is
;;; report-only and total; invalid profiles become diagnostics instead of throws.
;; : (-> [Symbol] [Alist] [Alist] [Symbol] Alist)
(def (agentic-ai-lab-user-loop-engine-sandbox-handoff-agreement
      refs
      runtime-summaries
      handoff-summaries
      unresolved-refs)
  (let* ((invalid-runtime-summaries
          (agentic-ai-lab-user-loop-engine-invalid-sandbox-runtime-summaries
           runtime-summaries))
         (diagnostics
          (agentic-ai-lab-user-loop-engine-sandbox-handoff-agreement-diagnostics
           refs
           runtime-summaries
           handoff-summaries
           unresolved-refs)))
    (list
     (cons 'kind 'loop-engine-sandbox-handoff-agreement)
     (cons 'contract
           +agentic-ai-lab-user-loop-engine-sandbox-handoff-agreement-contract+)
     (cons 'profile-refs refs)
     (cons 'profile-ref-count (length refs))
     (cons 'runtime-summary-count (length runtime-summaries))
     (cons 'handoff-summary-count (length handoff-summaries))
     (cons 'unresolved-profile-refs unresolved-refs)
     (cons 'unresolved-profile-ref-count (length unresolved-refs))
     (cons 'invalid-runtime-summaries invalid-runtime-summaries)
     (cons 'invalid-runtime-summary-count
           (length invalid-runtime-summaries))
     (cons 'diagnostic-count (length diagnostics))
     (cons 'diagnostics diagnostics)
     (cons 'valid? (null? diagnostics))
     (cons 'handoff-ready? (null? diagnostics))
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f))))
