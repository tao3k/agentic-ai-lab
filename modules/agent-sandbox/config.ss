;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user-facing agent sandbox profile declarations.
;;; Invariant: profiles are inert data until a runtime bridge consumes them.

(import (only-in :clan/poo/object .o .ref object<-alist)
        (only-in :clan/poo/mop element?)
        :poo-flow/modules/agent-sandbox/profile
        :poo-flow/modules/agent-sandbox/profile-native-contract
        :poo-flow/modules/agent-sandbox/projection-syntax
        :poo-flow/modules/sandbox-core/profile-support/policy
        :core/utilities/final-projection-syntax)

(export poo-flow-sandbox-profile-kind PooFlowSandboxProfileContract
        poo-flow-sandbox-profile-contract-admission poo-flow-sandbox-profile-contract-admitted?
        poo-flow-sandbox-profile-type-contract->alist poo-flow-require-sandbox-profile-contract!
        poo-flow-sandbox-profiles-presentation-kind poo-flow-sandbox-profile poo-flow-sandbox-profiles
        poo-flow-sandbox-profile-config poo-flow-sandbox-profile? poo-flow-sandbox-profile-name
        poo-flow-sandbox-profile-backend-kind poo-flow-sandbox-profile-backend-ref
        poo-flow-sandbox-profile-network-policy poo-flow-sandbox-profile-capabilities
        poo-flow-sandbox-profile-resource-policy poo-flow-sandbox-profile-metadata
        poo-flow-sandbox-profile-recipe-portable? poo-flow-sandbox-profile->descriptor
        poo-flow-sandbox-profile->profile poo-flow-sandbox-profile->alist
        poo-flow-sandbox-profile-backend-capability/registry poo-flow-sandbox-profile-backend-capability
        poo-flow-sandbox-profile-policy-validation-receipt/registry poo-flow-sandbox-profile-policy-validation-receipt
        poo-flow-sandbox-profile-policy-projection-receipt/registry poo-flow-sandbox-profile-policy-projection-receipt
        poo-flow-sandbox-profile-policy-projections-valid? poo-flow-sandbox-profile-policy-presentation-diagnostics
        poo-flow-sandbox-profile-runtime-intent/registry poo-flow-sandbox-profile-runtime-intent
        poo-flow-sandbox-profile-runtime-summary poo-flow-sandbox-profile-handoff-summary
        poo-flow-sandbox-profile-names poo-flow-sandbox-profile-alists poo-flow-sandbox-profile-by-name
        poo-flow-default-sandbox-profiles poo-flow-default-sandbox-profile-names
        poo-flow-default-sandbox-profile-presentation
        pooFlowSandboxProfilesPresentation/registry pooFlowSandboxProfilesPresentation)

(import :poo-flow/modules/agent-sandbox/config-form-support)
;;; Bass-style profile rows are just data recipes. The macro is deliberately a
;;; thin syntax bridge; semantic state lives in the POO profile object slots.
;; poo-flow-sandbox-profile
;;   : (-> Symbol SandboxProfileForm... PooSandboxProfile)
;;   | contract: expands one profile row into inert POO data only
;;   | doc m%
;;       `poo-flow-sandbox-profile` expands one named inert profile recipe.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-sandbox-profile agent/nono
;;         (backend nono)
;;         (network deny-by-default))
;;       ;; => POO profile recipe, not a runtime request
;;       ```
;;     %
(defrules poo-flow-sandbox-profile ()
  ((_ name form ...)
   (poo-flow-sandbox-profile-config 'name '(form ...))))

;; poo-flow-sandbox-profiles
;;   : (-> SandboxProfileRow... [PooSandboxProfile])
;;   | contract: preserves declaration order for agent/tool presentation
;;   | doc m%
;;       `poo-flow-sandbox-profiles` preserves profile declaration order.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-sandbox-profiles
;;         (agent/nono (backend nono))
;;         (agent/cube (backend cubeSandbox cube-local)))
;;       ;; => ordered profile recipes
;;       ```
;;     %
(defrules poo-flow-sandbox-profiles ()
  ((_)
   '())
  ((_ (name form ...) profile-clause ...)
   (cons (poo-flow-sandbox-profile name form ...)
         (poo-flow-sandbox-profiles profile-clause ...))))

;;; Built-in sandbox profiles are upstream defaults, not user init content. A
;;; downstream project can select or override them later without owning backend
;;; policy recipes in its root configuration file.
;; : PooSandboxProfileList
;; | PooSandboxProfileList = [PooSandboxProfile]
(def poo-flow-default-sandbox-profiles
  (poo-flow-sandbox-profiles
   (agent/nono
    (backend nono)
    (network deny-by-default)
    (capabilities process-run filesystem-read filesystem-write tmpdir)
    (resources (filesystem
                (scope . project-workspace)
                (paths
                 ((role . project-workspace)
                  (source . ".")
                  (project-marker . "gerbil.pkg")
                  (mode . read-write)))
                (access . read-write))
               (cpu . 2)
               (memory . "4Gi")
               (timeout-ms . 300000))
    (metadata (intent . coding-agent) (risk . high-demand)))
   (agent/cube
    (backend cube cube-local)
    (network allowlisted "github.com" "crates.io")
    (capabilities process-run filesystem-read cache-mount)
    (resources (filesystem
                (scope . snapshot)
                (snapshot . clone)
                (access . read-only))
               (cpu . 4)
               (memory . "8Gi")
               (timeout-ms . 600000))
    (metadata (intent . ci-agent) (risk . hermetic)))
   (agent/docker
    (backend docker docker-local)
    (network allowlisted "ghcr.io" "docker.io")
    (capabilities process-run filesystem-read filesystem-write tmpdir)
    (resources (filesystem
                (scope . volume)
                (materialized-by . runtime)
                (mounts . runtime)
                (access . read-write))
               (cpu . 2)
               (memory . "4Gi")
               (timeout-ms . 300000))
    (metadata (intent . container-agent) (risk . image-runtime)))))

;;; Kind guards keep downstream tools independent of constructor identity while
;;; still allowing POO slot extension behind the public recipe surface.
;; : (-> PooSandboxProfileCandidate Boolean)
;; | PooSandboxProfileCandidate = POOObject
(def (poo-flow-sandbox-profile? value)
  (element? PooFlowSandboxProfileContract value))

;;; Accessors stay as thin `.ref` wrappers so callers do not reach into the POO
;;; object directly or duplicate slot names across tests and runtime bridges.
;; : (-> PooSandboxProfile Symbol)
(def (poo-flow-sandbox-profile-name profile)
  (.ref profile 'name))

;; : (-> PooSandboxProfile Symbol)
(def (poo-flow-sandbox-profile-backend-kind profile)
  (.ref profile 'backend-kind))

;; : (-> PooSandboxProfile Symbol)
(def (poo-flow-sandbox-profile-backend-ref profile)
  (.ref profile 'backend-ref))

;; : (-> PooSandboxProfile [Value])
(def (poo-flow-sandbox-profile-network-policy profile)
  (.ref profile 'network-policy))

;; : (-> PooSandboxProfile [Symbol])
(def (poo-flow-sandbox-profile-capabilities profile)
  (.ref profile 'capabilities))

;; : (-> PooSandboxProfile Alist)
(def (poo-flow-sandbox-profile-resource-policy profile)
  (.ref profile 'resource-policy))

;; : (-> PooSandboxProfile Alist)
(def (poo-flow-sandbox-profile-metadata profile)
  (.ref profile 'metadata))

;;; Descriptor projection is the boundary where inert user recipes start
;;; participating in the existing sandbox profile validation contract.
;; : (-> Character Boolean)
(def (poo-flow-sandbox-profile-recipe-path-separator? character)
  (or (char=? character #\/)
      (char=? character #\\)))

;; : (-> Character Boolean)
(def (poo-flow-sandbox-profile-recipe-ascii-letter? character)
  (or (and (char>=? character #\a) (char<=? character #\z))
      (and (char>=? character #\A) (char<=? character #\Z))))

;; : (-> String Boolean)
(def (poo-flow-sandbox-profile-recipe-file-uri? value)
  (and (>= (string-length value) 5)
       (char-ci=? (string-ref value 0) #\f)
       (char-ci=? (string-ref value 1) #\i)
       (char-ci=? (string-ref value 2) #\l)
       (char-ci=? (string-ref value 3) #\e)
       (char=? (string-ref value 4) #\:)))

;; : (-> String Boolean)
(def (poo-flow-sandbox-profile-recipe-absolute-path? value)
  (let (length (string-length value))
    (or (and (> length 0)
             (poo-flow-sandbox-profile-recipe-path-separator?
              (string-ref value 0)))
        (and (>= length 3)
             (poo-flow-sandbox-profile-recipe-ascii-letter?
              (string-ref value 0))
             (char=? (string-ref value 1) #\:)
             (poo-flow-sandbox-profile-recipe-path-separator?
              (string-ref value 2)))
        (poo-flow-sandbox-profile-recipe-file-uri? value))))

;; : (-> String Integer Integer Boolean)
(def (poo-flow-sandbox-profile-recipe-source-segment-portable?
      value start end)
  (let (length (- end start))
    (and (> length 0)
         (not (and (= length 1)
                   (char=? (string-ref value start) #\.)))
         (not (and (= length 2)
                   (char=? (string-ref value start) #\.)
                   (char=? (string-ref value (+ start 1)) #\.))))))

;; : (-> Object Boolean)
(def (poo-flow-sandbox-profile-recipe-source-portable? value)
  (and (string? value)
       (not (poo-flow-sandbox-profile-recipe-absolute-path? value))
       (or (string=? value ".")
           (let (length (string-length value))
             (and (> length 0)
                  (let loop ((index 0) (segment-start 0))
                    (cond
                     ((= index length)
                      (poo-flow-sandbox-profile-recipe-source-segment-portable?
                       value segment-start index))
                     ((or (char=? (string-ref value index) #\\)
                          (char=? (string-ref value index) #\:))
                      #f)
                     ((char=? (string-ref value index) #\/)
                      (and
                       (poo-flow-sandbox-profile-recipe-source-segment-portable?
                        value segment-start index)
                       (loop (+ index 1) (+ index 1))))
                     (else
                      (loop (+ index 1) segment-start)))))))))

;; : (-> Object Boolean)
(def (poo-flow-sandbox-profile-recipe-project-marker-portable? value)
  (and (poo-flow-sandbox-profile-recipe-project-marker-name-portable? value)
       (andmap
        poo-flow-sandbox-profile-recipe-project-marker-character-portable?
        (string->list value))))

;; : (-> Object Boolean)
(def (poo-flow-sandbox-profile-recipe-project-marker-name-portable? value)
  (and (string? value)
       (not (member value '("" "." "..")))))

;; : (-> Character Boolean)
(def (poo-flow-sandbox-profile-recipe-project-marker-character-portable? value)
  (and (not (poo-flow-sandbox-profile-recipe-path-separator? value))
       (not (char=? value #\:))))

;; : (-> Object Boolean)
(def (poo-flow-sandbox-profile-recipe-datum-portable? datum)
  (cond
   ((string? datum)
    (not (poo-flow-sandbox-profile-recipe-absolute-path? datum)))
   ((pair? datum)
    (and
     (not (and (symbol? (car datum))
               (eq? (car datum) 'target)))
     (or (not (and (symbol? (car datum))
                   (eq? (car datum) 'source)))
         (poo-flow-sandbox-profile-recipe-source-portable? (cdr datum)))
     (or (not (and (symbol? (car datum))
                   (eq? (car datum) 'project-marker)))
         (poo-flow-sandbox-profile-recipe-project-marker-portable? (cdr datum)))
     (poo-flow-sandbox-profile-recipe-datum-portable? (car datum))
     (poo-flow-sandbox-profile-recipe-datum-portable? (cdr datum))))
   (else #t)))

;; Recipes are portable declarations. Concrete sandbox mount paths belong to
;; the backend materialization boundary, never to the composable POO object.
;; : (-> PooSandboxProfile Boolean)
(def (poo-flow-sandbox-profile-recipe-portable? profile)
  (and (poo-flow-sandbox-profile? profile)
       (poo-flow-sandbox-profile-recipe-datum-portable?
        (poo-flow-sandbox-profile-name profile))
       (poo-flow-sandbox-profile-recipe-datum-portable?
        (poo-flow-sandbox-profile-backend-ref profile))
       (poo-flow-sandbox-profile-recipe-datum-portable?
        (poo-flow-sandbox-profile-network-policy profile))
       (poo-flow-sandbox-profile-recipe-datum-portable?
        (poo-flow-sandbox-profile-capabilities profile))
       (poo-flow-sandbox-profile-recipe-datum-portable?
        (poo-flow-sandbox-profile-resource-policy profile))
       (poo-flow-sandbox-profile-recipe-datum-portable?
        (poo-flow-sandbox-profile-metadata profile))))

(def (poo-flow-sandbox-profile->descriptor profile)
  (let (admitted-profile
        (poo-flow-require-sandbox-profile-contract! profile))
    (unless (poo-flow-sandbox-profile-recipe-portable? admitted-profile)
      (error "sandbox profile recipe contains an absolute path"
             (poo-flow-sandbox-profile-name admitted-profile)))
    (make-agent-sandbox-profile-descriptor
     (poo-flow-sandbox-profile-name admitted-profile)
     (poo-flow-sandbox-profile-backend-kind admitted-profile)
     (poo-flow-sandbox-profile-backend-ref admitted-profile)
     (poo-flow-sandbox-profile-network-policy admitted-profile)
     (poo-flow-sandbox-profile-capabilities admitted-profile)
     (poo-flow-sandbox-profile-resource-policy admitted-profile)
     (poo-flow-sandbox-profile-metadata admitted-profile))))

;;; Profile projection is the last Scheme-side step before the shared sandbox
;;; contract takes over validation and runtime adapter handoff.
;; : (-> PooSandboxProfile AgentSandboxProfile)
(def (poo-flow-sandbox-profile->profile profile)
  (agent-sandbox-profile-descriptor->profile
   (poo-flow-sandbox-profile->descriptor profile)))

;;; Runtime summaries must be report-only: they project enough profile shape for
;;; validation diagnostics without raising the strict handoff failure path.
;; : (-> PooSandboxProfile AgentSandboxProfile)
(def (poo-flow-sandbox-profile->unchecked-profile profile)
  (make-agent-sandbox-backend-profile
   (poo-flow-sandbox-profile-backend-kind profile)
   (poo-flow-sandbox-profile-backend-ref profile)
   (poo-flow-sandbox-profile-network-policy profile)
   (poo-flow-sandbox-profile-capabilities profile)
   (poo-flow-sandbox-profile-resource-policy profile)
   (poo-flow-sandbox-profile-metadata profile)))

;;; Alist conversion is presentation-only. Keeping it separate from the POO
;;; recipe avoids flattening the extension point that nono/cubeSandbox can use.
;; : (-> PooSandboxProfile Alist)
(defpoo-final-projection
  poo-flow-sandbox-profile->alist (profile)
  (bindings ())
  (fields ((kind poo-flow-sandbox-profile-kind)
           (name (poo-flow-sandbox-profile-name profile))
           (backend-kind (poo-flow-sandbox-profile-backend-kind profile))
           (backend-ref (poo-flow-sandbox-profile-backend-ref profile))
           (network-policy (poo-flow-sandbox-profile-network-policy profile))
           (capabilities (poo-flow-sandbox-profile-capabilities profile))
           (resource-policy (poo-flow-sandbox-profile-resource-policy profile))
           (metadata (poo-flow-sandbox-profile-metadata profile)))))

;;; Backend capability receipts are static control-plane facts. They make
;;; OpenRath-style capability boundaries visible without selecting a runtime.
;; : (-> PooSandboxProfile PooSandboxBackendCapabilityRegistry PooSandboxBackendCapability)
(def (poo-flow-sandbox-profile-backend-capability/registry profile registry)
  (poo-flow-sandbox-backend-capability-registry-ref
   registry
   (poo-flow-sandbox-profile-backend-kind profile)))

;; : (-> PooSandboxProfile PooSandboxBackendCapability)
(def (poo-flow-sandbox-profile-backend-capability profile)
  (poo-flow-sandbox-profile-backend-capability/registry
   profile
   poo-flow-sandbox-backend-capability-registry/default))

;;; Policy validation is report-only for public user profiles. Backend profile
;;; objects can hard-gate resolution, while presentation keeps diagnostics
;;; visible for users and agents.
;; : (-> PooSandboxProfile PooSandboxProfilePolicyValidation)
(def (poo-flow-sandbox-profile-policy-validation-receipt/registry profile
                                                                   registry)
  (poo-flow-sandbox-profile-policy-validation
   (poo-flow-sandbox-profile-name profile)
   (poo-flow-sandbox-profile-backend-kind profile)
   (poo-flow-sandbox-profile-backend-ref profile)
   (poo-flow-sandbox-profile-backend-capability/registry profile registry)
   poo-flow-sandbox-profile-policy/default
   (poo-flow-sandbox-profile-capabilities profile)
   (poo-flow-sandbox-profile-resource-policy profile)))

;; : (-> PooSandboxProfile PooSandboxProfilePolicyValidation)
(def (poo-flow-sandbox-profile-policy-validation-receipt profile)
  (poo-flow-sandbox-profile-policy-validation-receipt/registry
   profile
   poo-flow-sandbox-backend-capability-registry/default))

;; : (-> PooSandboxProfile PooSandboxProfilePolicyProjection)
(def (poo-flow-sandbox-profile-policy-projection-receipt/registry profile
                                                                   registry)
  (poo-flow-sandbox-profile-policy-projection
   (poo-flow-sandbox-profile-name profile)
   (poo-flow-sandbox-profile-backend-kind profile)
   (poo-flow-sandbox-profile-backend-ref profile)
   (poo-flow-sandbox-profile-backend-capability/registry profile registry)
   poo-flow-sandbox-profile-policy/default
   (poo-flow-sandbox-profile-capabilities profile)
   (poo-flow-sandbox-profile-resource-policy profile)))

;; : (-> PooSandboxProfile PooSandboxProfilePolicyProjection)
(def (poo-flow-sandbox-profile-policy-projection-receipt profile)
  (poo-flow-sandbox-profile-policy-projection-receipt/registry
   profile
   poo-flow-sandbox-backend-capability-registry/default))

;; : (-> [PooSandboxProfilePolicyProjection] Boolean)
(def (poo-flow-sandbox-profile-policy-projections-valid? projections)
  (cond
   ((null? projections) #t)
   ((poo-flow-sandbox-profile-policy-projection-valid? (car projections))
    (poo-flow-sandbox-profile-policy-projections-valid? (cdr projections)))
   (else #f)))

;; : (-> [PooSandboxProfilePolicyProjection] [PooSandboxProfilePolicyDiagnostic])

;; : (forall (p d) (-> [p] [d] [d]))
;; poo-flow-sandbox-profile-policy-presentation-diagnostics-rev
;; : (-> (List SandboxPolicyProjection)
;;        (List SandboxDiagnosticRow)
;;        (List SandboxDiagnosticRow))
;; | doc m%
;; Accumulates presentation diagnostics in reverse order while preserving the
;; policy projection order at the public boundary.
;; # Examples
;; ```scheme
;; (poo-flow-sandbox-profile-policy-presentation-diagnostics-rev '() '())
;; => '()
;; ```
;; Optimization boundary: the recursive branch accumulates reversed rows so the
;; public projection pays one final reverse instead of appending per projection.
(def (poo-flow-sandbox-profile-policy-presentation-diagnostics-rev
      projections
      diagnostics-rev)
  (if (null? projections)
    diagnostics-rev
    (poo-flow-sandbox-profile-policy-presentation-diagnostics-rev
     (cdr projections)
     (agent-sandbox-rows-into/rev
      (poo-flow-sandbox-profile-policy-projection-diagnostics
       (car projections))
      diagnostics-rev))))

;; : (forall (p d) (-> [p] [d]))
;; poo-flow-sandbox-profile-policy-presentation-diagnostics
;; : (-> (List SandboxPolicyProjection) (List SandboxDiagnosticRow))
;; | doc m%
;; Produces stable presentation diagnostics from sandbox policy projections.
;; # Examples
;; ```scheme
;; (poo-flow-sandbox-profile-policy-presentation-diagnostics '())
;; => '()
;; ```
(def (poo-flow-sandbox-profile-policy-presentation-diagnostics projections)
  (reverse
   (poo-flow-sandbox-profile-policy-presentation-diagnostics-rev
    projections
    '())))

;;; Runtime intent is a receipt shape for agents and CLI tooling. It names the
;;; backend handoff target without manufacturing a runtime command in Scheme.
;; : (-> PooSandboxProfile PooSandboxBackendCapabilityRegistry Alist)
(def (poo-flow-sandbox-profile-runtime-intent/registry profile registry)
  (let ((policy-projection
         (poo-flow-sandbox-profile-policy-projection-receipt/registry
          profile
          registry)))
    (agent-sandbox-field-rows
     (profile-name (poo-flow-sandbox-profile-name profile))
     (backend-kind (poo-flow-sandbox-profile-backend-kind profile))
     (backend-ref (poo-flow-sandbox-profile-backend-ref profile))
     (network-policy
      (poo-flow-sandbox-profile-network-policy profile))
     (capabilities (poo-flow-sandbox-profile-capabilities profile))
     (resource-policy
      (poo-flow-sandbox-profile-resource-policy profile))
     (policy-projection policy-projection)
     (policy-valid?
      (poo-flow-sandbox-profile-policy-projection-valid?
       policy-projection))
     (durable-policy-ref
      (.ref policy-projection 'durable-policy-ref))
     (durable-policy-summary
      (.ref policy-projection 'durable-policy-summary))
     (durable-valid?
      (.ref policy-projection 'durable-valid?))
     (sandbox-handle-class
      (.ref policy-projection 'sandbox-handle-class))
     (runtime-owner "marlin-agent-core")
     (descriptor-realized? #f)
     (runtime-executed #f))))

;; : (-> PooSandboxProfile Alist)
(def (poo-flow-sandbox-profile-runtime-intent profile)
  (poo-flow-sandbox-profile-runtime-intent/registry
   profile
   poo-flow-sandbox-backend-capability-registry/default))

;;; Runtime summaries deliberately cross the validation boundary: callers get
;;; the sandbox-owned summary of the realized agent profile, while the public
;;; POO profile name remains visible for user-interface projections.
;; : (-> PooSandboxProfile Alist)
;; : (forall (k v) (-> [(Pair k v)] [(Pair k v)] [(Pair k v)]))
;; poo-flow-sandbox-profile-runtime-summary
;; : (-> SandboxProfile (List FieldRow))
;; | doc m%
;; Preserves the generic field-row extension law through
;; agent-sandbox-field-rows/tail, then projects a sandbox profile through the
;; unchecked runtime boundary for a runtime consumer.
;; # Examples
;; ```scheme
;; (poo-flow-sandbox-profile-runtime-summary
;;  (car poo-flow-default-sandbox-profiles))
;; => '((profile-name . agent/nono) (descriptor-realized? . #t) ...)
;; ```
(def (poo-flow-sandbox-profile-runtime-summary profile)
  (agent-sandbox-field-rows/tail
   (agent-sandbox-profile-runtime-summary
    (poo-flow-sandbox-profile->unchecked-profile profile))
   (profile-name (poo-flow-sandbox-profile-name profile))
   (descriptor-realized? #t)))

;;; Handoff summaries are the stricter bridge-facing form. Invalid profile rows
;;; fail at the sandbox profile owner before workflow code sees them.
;; : (-> PooSandboxProfile Alist)
;; : (forall (k v) (-> [(Pair k v)] [(Pair k v)] [(Pair k v)]))
;; poo-flow-sandbox-profile-handoff-summary
;; : (-> SandboxProfile (List FieldRow))
;; | doc m%
;; Preserves the generic field-row extension law through
;; agent-sandbox-field-rows/tail, then projects a sandbox profile through the
;; checked handoff boundary for a downstream runtime consumer.
;; # Examples
;; ```scheme
;; (poo-flow-sandbox-profile-handoff-summary
;;  (car poo-flow-default-sandbox-profiles))
;; => '((profile-name . agent/nono) (descriptor-realized? . #t) ...)
;; ```
(def (poo-flow-sandbox-profile-handoff-summary profile)
  (agent-sandbox-field-rows/tail
   (agent-sandbox-profile-handoff-summary
    (poo-flow-sandbox-profile->profile profile))
   (profile-name (poo-flow-sandbox-profile-name profile))
   (descriptor-realized? #t)))

;;; Name projection is kept separate from alist projection so tools can inspect
;;; selectable profiles without forcing full descriptor conversion.
;; : (-> [PooSandboxProfile] [Symbol])
(def (poo-flow-sandbox-profile-names profile-list)
  (map poo-flow-sandbox-profile-name profile-list))

;;; Alist lists are presentation receipts only; runtime bridges consume
;;; descriptors or profile objects instead.
;; : (-> [PooSandboxProfile] [Alist])
(defpoo-final-projection-batch
  poo-flow-sandbox-profile-alists (profile-list)
  (projector poo-flow-sandbox-profile->alist)
  (error-message "sandbox profile alist presentation requires a list"))

;;; Missing profile names are normal during agent negotiation, so lookup returns
;;; `#f` and leaves diagnostics to the caller-facing doctor/presentation path.
;; : (-> [PooSandboxProfile] Symbol MaybePooSandboxProfile)
(def (poo-flow-sandbox-profile-by-name profiles name)
  (cond
   ((null? profiles) #f)
   ((eq? (poo-flow-sandbox-profile-name (car profiles)) name)
    (car profiles))
   (else
    (poo-flow-sandbox-profile-by-name (cdr profiles) name))))

;;; Keep the parameter name distinct from the `profiles:` slot. gerbil-poo lazy
;;; slot resolution can otherwise capture the slot name and recurse on read.
;; : (-> [PooSandboxProfile] PooSandboxBackendCapabilityRegistry [Alist] [Alist] [Alist] [Alist] List)
(def (poo-flow-sandbox-profile-presentation-bundle/rev profile-list
                                                        registry
                                                        policies-rev
                                                        intents-rev
                                                        summaries-rev
                                                        handoffs-rev)
  (if (null? profile-list)
    (list (reverse policies-rev)
          (reverse intents-rev)
          (reverse summaries-rev)
          (reverse handoffs-rev))
    (let (profile (car profile-list))
      (poo-flow-sandbox-profile-presentation-bundle/rev
       (cdr profile-list)
       registry
       (cons (poo-flow-sandbox-profile-policy-projection-receipt/registry
              profile
              registry)
             policies-rev)
       (cons (poo-flow-sandbox-profile-runtime-intent/registry
              profile
              registry)
             intents-rev)
       (cons (poo-flow-sandbox-profile-runtime-summary profile)
             summaries-rev)
       (cons (poo-flow-sandbox-profile-handoff-summary profile)
             handoffs-rev)))))

;; : (-> [PooSandboxProfile] PooSandboxBackendCapabilityRegistry List)
(def (poo-flow-sandbox-profile-presentation-bundle profile-list registry)
  (poo-flow-sandbox-profile-presentation-bundle/rev
   profile-list
   registry
   '()
   '()
   '()
   '()))

;; : (-> [PooSandboxProfile] PooSandboxBackendCapabilityRegistry POOObject)
(def (pooFlowSandboxProfilesPresentation/registry profile-list registry)
  (let* ((presentation-bundle
          (poo-flow-sandbox-profile-presentation-bundle profile-list registry))
         (policy-projections (car presentation-bundle))
         (runtime-intents (cadr presentation-bundle))
         (runtime-summaries (caddr presentation-bundle))
         (handoff-summaries (cadddr presentation-bundle)))
    (object<-alist
     (list
      (cons 'kind poo-flow-sandbox-profiles-presentation-kind)
      (cons 'profile-count (length profile-list))
      (cons 'profile-names (poo-flow-sandbox-profile-names profile-list))
      (cons 'profiles (poo-flow-sandbox-profile-alists profile-list))
      (cons 'runtime-intents runtime-intents)
      (cons 'runtime-summaries runtime-summaries)
      (cons 'handoff-summaries handoff-summaries)
      (cons 'policy-projections policy-projections)
      (cons 'policy-valid?
            (poo-flow-sandbox-profile-policy-projections-valid?
             policy-projections))
      (cons 'policy-diagnostics
            (poo-flow-sandbox-profile-policy-presentation-diagnostics
             policy-projections))
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'package-management? #f)
      (cons 'dependency-installation? #f)
      (cons 'descriptor-realized? #f)
      (cons 'runtime-executed #f)
      (cons 'replayable #t)))))

;; : (-> [PooSandboxProfile] POOObject)
(def (pooFlowSandboxProfilesPresentation profile-list)
  (pooFlowSandboxProfilesPresentation/registry
   profile-list
   poo-flow-sandbox-backend-capability-registry/default))

;; : [Symbol]
(def poo-flow-default-sandbox-profile-names
  (poo-flow-sandbox-profile-names poo-flow-default-sandbox-profiles))

;;; Default profile presentation is a stable upstream receipt for downstream
;;; user interfaces that should not duplicate nono/cube policy recipes.
;; : (-> Unit POOObject)
(def (poo-flow-default-sandbox-profile-presentation)
  (pooFlowSandboxProfilesPresentation poo-flow-default-sandbox-profiles))
