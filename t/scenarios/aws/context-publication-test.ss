;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Real provider packages and maintained AWS publication; no cloud effects.
(import :std/test :clan/poo/object
        (only-in :std/error Error? Error-message)
        (only-in :yuanxu/observability/testing-fixture yuanxu-test-fixture)
        (only-in :yuanxu/observability/testing-case
                 yuanxu-test-checkpoint yuanxu-test-observe)
        (only-in "./fixtures.ss"
                 Workspace prepare-aws-selection! realize-aws-selection write-aws-version!)
        (only-in :yuanxu/admission/publication AdmissionPublication.)
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (prefix-in :clan/poo/declarative-metadata metadata.))
(export aws-context-publication-test)

(def (refused previous evidence next failure)
  (check-equal? evidence #f)
  (check-equal? (eq? previous next) #t)
  (check-equal? (metadata.failure? failure) #t))

(def aws-context-publication-test
  (test-suite "AWS public fields, contextual child admission and publication"
    (yuanxu-test-fixture "real Schema upgrade refuses stale evidence and keeps accepted values"
      (root Workspace)
      (def (phase name) (yuanxu-test-checkpoint name))
      (let ()
        (phase 'start)
        (def fixture (prepare-aws-selection! root phase))
        (phase 'prepared)
        (def project (.get fixture project))
        (def selection
          (realize-aws-selection fixture (path-expand "packages-old" root) phase))
        (phase 'parent-selected)
        ;; Native imports keep their owners in this explicit source policy.
        (check-equal?
          (and (find (lambda (input)
                       (string-suffix? "/modules/funflow/func.ss" (car input)))
                     (.get selection build-graph source-inputs)) #t) #t)
        ;; No Schema list, descriptor reconstruction or handwritten admission paths.
        (def publication (.call AdmissionPublication. .for-export selection 'aws 'Scenario))
        (phase 'parent-bound)
        (def contract (.get publication contract))
        (def child-contract (.get contract responsibilities profile))
        (check-equal? (.get selection modules aws provider version) "5.99.0")
        (check-equal? (eq? contract (.get selection modules aws types Scenario)) #t)
        (check-equal? (.get child-contract value-contract) #f)
        (check-equal? (length (.get publication context schema-inputs)) 3)

        (def WebProfile (.get selection modules aws Profiles Web))
        (def Scenario (.get publication value))
        (def parent-cached (.get Scenario resource))
        (check-equal? (.get parent-cached instance_type) "t3.small")
        (.def (Production @ WebProfile) instance_type: "t3.medium")
        (.def (Release @ Scenario) profile: Production)
        (defvalues (receipt next failure) (.call publication .publish Scenario Release))
        (phase 'parent-published)
        (check-equal? failure #f)
        (check-equal? (yuanxu-validation-evidence-accepted? receipt) #t)
        (check-equal? (.get next resource instance_type) "t3.medium")
        (check-equal? (.get parent-cached instance_type) "t3.small")
        (check-equal? (eq? (.get receipt candidate) next) #t)
        (check-equal? (eq? (.get next profile) (.get next resource)) #t)
        (def child (car (.get receipt responsibility-evidence)))
        (check-equal? (eq? (.get child candidate) (.get next profile)) #t)
        (check-equal? (eq? (.get child admission-contract) child-contract) #t)
        (check-equal? (eq? (.get child context) (.get publication context)) #t)
        ;; This newly present transitive Nix file is intentionally absent from
        ;; Scheme's observation list. Native flake input hashing must refuse the
        ;; old package identity; restoring it may reuse only Nix's own cache.
        (def transitive (path-expand "profile-options.nix" project))
        (dynamic-wind
          (lambda ()
            (call-with-output-file transitive
              (cut display "\"opentofu-artifacts-changed\"" <>)))
          (lambda ()
            (check-exception ((.get selection package-current)) error?)
            (check-equal? (.get next resource instance_type) "t3.medium")
            (phase 'transitive-input-refused))
          (lambda () (delete-file transitive)))
        ((.get selection package-current))
        ;; Exercise the exact gate also used by .publish. Only the source that
        ;; submits the prior receipt is adversarial; no relation is rebuilt here.
        (.def (OtherContract @ publication) contract: (.cc (.get publication contract)))
        (.def (OtherContext @ publication) context: (.cc (.get publication context)))
        (check-equal? (.get OtherContract contract identity) (.get contract identity))
        (check-equal? (eq? (.get OtherContract contract) contract) #f)
        (check-equal? (eq? (.get OtherContract context) (.get publication context)) #t)
        (check-equal? (eq? (.get OtherContext contract) contract) #t)
        (check-equal? (eq? (.get OtherContext context) (.get publication context)) #f)
        (for-each
          (lambda (target)
            (def bound (.call target .bind-evidence next))
            (defvalues (rejected preserved reason)
              (metadata.publish bound next (lambda (checked) (values receipt checked)) next))
            (refused next rejected preserved reason)
            (check-equal? (metadata.failure-phase reason) 'logic)
            (check-equal? (metadata.failure-cause reason) #f))
          (list OtherContract OtherContext))
        (phase 'identity-replay-refused)
        ;; Sharing a label does not grant another descriptor admission authority.
        (check-exception
          (.call (.get publication context) .contract-obligations
                 (.cc child-contract) (.get next profile))
          (lambda (exception)
            (and (Error? exception)
                 (string=? (Error-message exception)
                           "admission descriptor differs from selected publication"))))
        (phase 'descriptor-clone-refused)

        ;; A policy probe extends the actual platform Context, retaining its
        ;; original method and guards. It is not a production AWS authorization rule.
        (def observed '())
        (.def (RejectProfile @ (.get publication context))
          .contract-obligations: =>
          (lambda (previous)
            (lambda (actual candidate)
              (set! observed (cons actual observed))
              (append (previous actual candidate)
                (if (eq? actual child-contract)
                  (list (.o kind: 'test-profile-context-refused)) '())))))
        (defvalues (denied kept rejection)
          (.call (.cc publication context: RejectProfile) .publish next Release))
        (phase 'context-denial-returned)
        (refused next denied kept rejection)
        (check-equal? (and (memq child-contract observed) #t) #t)

        ;; Private Core test data, not a module API or an injection DSL.
        ;; Schema runs first and refreshes the real association; Contract runs
        ;; last because its destructive requirement edit invalidates that Context.
        (def changes
          (list
            (.o name: 'schema
                change: (lambda (_target) (write-aws-version! project "child")))
            (.o name: 'context
                change: (lambda (target)
                          (.put! (.get target context)
                            'graph-generation 'test-stale-generation)))
            (.o name: 'contract
                change: (lambda (target)
                          (.put! (.get target contract responsibilities)
                            'profile (.cc child-contract))))))
        (def active-publication publication)
        (def accepted next)
        (for-each
          (lambda (row)
            (def name (.get row name))
            (def boundaries 0)
            ;; One inherited effect-boundary refinement for every table row.
            ;; Observation is passive; correctness never depends on emit?.
            (.def (Transition @ active-publication)
              context: (if (eq? name 'context)
                         (.cc (.get active-publication context))
                         (.get active-publication context))
              package-current: =>
              (lambda (previous)
                (lambda ()
                  (previous)
                  (set! boundaries (+ boundaries 1))
                  (when (= boundaries 2)
                    (yuanxu-test-observe 'publication-fault-boundary)
                    ((.get row change) Transition)))))
            (phase name)
            (defvalues (changed kept failure)
              (.call Transition .publish accepted Release))
            (refused accepted changed kept failure)
            (check-equal? boundaries 2)
            (yuanxu-test-observe 'publication-fault-refused)

            (when (eq? name 'schema)
              (let ()
                (defvalues (stale kept-old stale-failure)
                  (.call publication .publish accepted Release))
                (refused accepted stale kept-old stale-failure)
                (phase 'old-source-refused)
                (def fresh-selection
                  (realize-aws-selection fixture (path-expand "packages-new" root) phase))
                (def fresh-publication
                  (.call AdmissionPublication. .for-export fresh-selection 'aws 'Scenario))
                (phase 'fresh-publication-bound)
                (check-equal? (.get fresh-selection modules aws provider version) "5.100.0")
                (check-equal? (eq? (.get fresh-publication contract) contract) #f)
                (check-equal? (eq? (.get fresh-publication context) (.get publication context)) #f)
                (def current-binding (.call fresh-publication .bind-evidence accepted))
                (defvalues (replayed kept-replay replay-failure)
                  (metadata.publish current-binding accepted
                    (lambda (checked) (values receipt checked)) accepted))
                (refused accepted replayed kept-replay replay-failure)
                (phase 'fresh-evidence-replay-refused)
                (check-equal? (metadata.failure-phase replay-failure) 'logic)
                (check-equal? (metadata.failure-cause replay-failure) #f)
                (defvalues (fresh latest fresh-failure)
                  (.call fresh-publication .publish accepted Release))
                (phase 'fresh-published)
                (check-equal? fresh-failure #f)
                (check-equal? (.get latest resource instance_type) "t3.medium")
                (check-equal? (eq? (.get fresh context) (.get receipt context)) #f)
                (def fresh-child (car (.get fresh responsibility-evidence)))
                (check-equal? (eq? (.get fresh-child candidate) (.get latest profile)) #t)
                (.def (Typo @ Production) instnace_type: "t3.large")
                (.def (Invalid @ Scenario) profile: Typo)
                (defvalues (bad kept-valid bad-failure)
                  (.call fresh-publication .publish latest Invalid))
                (refused latest bad kept-valid bad-failure)
                (set! active-publication fresh-publication)
                (set! accepted latest))))
          changes)

        ;; The module's exported baseline stays unchanged; the selected Graph
        ;; owns all role-source observations, including configuration. Tests do
        ;; not locate or read implementation files relative to their own path.
        (check-equal? (.get WebProfile instance_type) "t3.small")
        ((.get active-publication graph admit-current))
        (phase 'publication-complete)))))
