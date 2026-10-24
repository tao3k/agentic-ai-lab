;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Public value Types own data; Core adds evidence over its selected Context.
(import :clan/poo/object :clan/poo/object-contract
        (only-in :clan/poo/mop define-type)
        (only-in :clan/poo/type True)
        (only-in :yuanxu/modules/json-schema/contracts ProjectionContract.)
        (only-in :agentic-ai-lab/modules/services/opentofu/types OpenTofuScopeContract)
        (only-in :yuanxu/object-types/contracts YuanxuContract. yuanxu-classification-evidence))
(export AWSProfileContract. AWSScenarioContract. AWSAdmissionContract.
        AWSProfileAdmissionContract. AWSInterfaceContract aws-scenario-contract
        OpenTofuScopeContract)

;; AWS fields, optionality and unknown names belong to the actual Provider
;; Schema. Delegate rather than copying its vocabulary into responsibilities.
(define-type (AWSProfileContract. @ ObjectContract. input-type)
  identity: 'aws/profile
  extra-fields: 'delegate
  constraints: (list input-type))

(define-type (AWSScenarioContract. @ ObjectContract. input-type profile-contract)
  identity: 'aws/scenario-value
  profile-contract: (.cc AWSProfileContract. 'input-type input-type)
  responsibilities:
  (.o profile: profile-contract resource: profile-contract)
  ;; This sample projects EC2 input directly, so the actual effective Profile
  ;; must be the projected resource, not merely share one instance_type string.
  obligations:
  (lambda (value location)
    (if (eq? (.get value profile) (.get value resource)) '()
      (list (.o kind: 'stale-resource path: (append location '(resource)))))))

;; The public value Contract is run once by Core's existing .admit producer.
;; There is no extra AWS authorization policy here. Graph/source/Schema
;; currentness is enforced by AdmissionPublication., not by this classifier.
(define-type (AWSAdmissionContract. @ YuanxuContract. identity)
  .classify:
  (lambda (candidate context)
    (yuanxu-classification-evidence identity candidate #t '() context)))

;; The public root Contract already checks all Profile fields. This descriptor
;; requests contextual admission of that final Profile, retaining child evidence
;; and the selected publication's Graph/source/Schema checks without revalidation.
(define-type (AWSProfileAdmissionContract. @ AWSAdmissionContract.)
  identity: 'aws/profile-context)

;; Interface admission checks declared endpoints without forcing their values.
;; Validating exported Profiles or Types during scope linking would eagerly
;; compile their Schemas. Actual contracts are demanded by .for-export.
(def AWSInterfaceShape
  (.cc ProjectionContract.
    'constraint (.cc ObjectContract. responsibilities:
                  (.o Profiles: True Scenario: True types: True provider: True))
    'project
    (lambda (scope)
      (if (not (object? scope)) scope
        (.o Profiles: (.slot? scope 'Profiles)
            Scenario: (.slot? scope 'Scenario)
            types: (.slot? scope 'types)
            provider: (.slot? scope 'provider))))))
(define-type (AWSInterfaceContract @ AWSAdmissionContract.)
  identity: 'aws/interface
  value-contract: AWSInterfaceShape)

(def (aws-scenario-contract input-type)
  (.cc AWSAdmissionContract.
    'identity 'aws/scenario-admission
    'value-contract (.cc AWSScenarioContract. 'input-type input-type)
    'responsibilities (.o profile: AWSProfileAdmissionContract.)))
