;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Small structural controls; real AWS Schema is exercised by the Ops gate.
(import :std/test :clan/poo/object :clan/poo/object-contract
        (only-in :clan/poo/mop validate TypeError?)
        (only-in :yuanxu/modules/json-schema/contracts schema-value-contract)
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/module-system/source/publication module-publication?)
        (only-in :agentic-ai-lab/scenarios/aws/types AWSProfileContract.
          AWSInterfaceContract aws-scenario-contract))
(export aws-scenario-contract-test)
;; Deliberately a tiny Schema fixture, never claimed to be the AWS export.
(def Input
  (schema-value-contract 'fixture/ec2
    '((type . "object") (additionalProperties . #f)
      (required . ("instance_type"))
      (properties . ((instance_type . ((type . "string"))))))))
(def Fields (.cc AWSProfileContract. 'input-type Input))
(def (paths type value) (map (cut .get <> path) (diagnose type value)))
(def aws-scenario-contract-test
  (test-suite "AWS public ObjectContract layering"
    (yuanxu-test-case "delegate field closure and diagnostics to Schema"
      (check-equal? (diagnose Fields (.o instance_type: "t3.small")) '())
      (check-equal? (paths Fields (.o instance_type: 3)) '((instance_type)))
      (check-equal? (paths Fields (.o instance_type: "t3.small" instnace_type: "typo"))
        '((instnace_type)))
      (check-exception (validate Fields (.o)) TypeError?))
    (yuanxu-test-case "nominal identity is opt-in and rejects before getters"
      (.def Parent instance_type: "t3.small")
      (.def (Child @ Parent) instance_type: "t3.medium")
      (def Nominal (.cc Fields 'required-prototype Parent))
      (check-equal? (diagnose Nominal Child) '())
      (check-equal? (paths Nominal (.o instance_type: (error "must remain lazy"))) '(())))
    (yuanxu-test-case "checked final receiver and full projected identity"
      (.def (Parent @ [] profile)
        profile: (.o instance_type: "t3.small") resource: profile)
      (def parent-cached (.get Parent resource))
      (.def (Child @ Parent) profile: (.o instance_type: "t3.medium"))
      (def Contract (aws-scenario-contract Input))
      (def evidence (.call Contract .admit Child #f))
      (check-equal? (yuanxu-validation-evidence-accepted? evidence) #t)
      (check-equal? (.get evidence candidate resource instance_type) "t3.medium")
      (check-equal? (.get parent-cached instance_type) "t3.small")
      (.def (Stale @ Child) resource: parent-cached)
      (check-exception (.call Contract .admit Stale #f) TypeError?)
      ;; Equal scalar fields alone do not authorize an independently cached object.
      (.def (Copied @ Child) resource: (.o instance_type: "t3.medium"))
      (check-exception (.call Contract .admit Copied #f) TypeError?))
    (yuanxu-test-case "interface declaration inspection leaves payloads cold"
      (def signature (.get AWSInterfaceContract value-contract))
      (check-equal? (diagnose signature
        (.o Profiles: (error "cold Profiles") Scenario: (error "cold Scenario")
            types: (error "cold Types") provider: (error "cold Provider"))) '())
      (check-equal? (paths signature (.o Profiles: #f Scenario: #f provider: #f)) '((types))))
    (yuanxu-test-case "publication admits paths without linking payloads"
      (def (publication declarations)
        (.o identity: 'test features: (.o)
            core: (.o requires: (.o) scope-contract: AWSInterfaceContract
                      admissions: declarations
                      link: (lambda (_) (error "metadata inspection must not link")))))
      (check-equal? (module-publication? (publication
        (.o Scenario: (.o export-path: '(Scenario) contract-path: '(types Scenario))))) #t)
      (check-equal? (module-publication? (publication
        (.o Scenario: (.o export-path: '() contract-path: '(types Scenario))))) #f)
      (check-equal? (module-publication? (publication
        (.o Scenario: (.o export-path: '(Scenario) contract-path: '("types" Scenario))))) #f)
      (check-equal? (module-publication? (publication
        (.o Scenario: (.o export-path: '(Scenario))))) #f))))
