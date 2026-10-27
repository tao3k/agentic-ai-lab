;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The declaration tree is authoritative before package or process effects.
(import :std/test :clan/poo/object
        (only-in :clan/poo/object-contract ObjectContract.)
        (only-in :clan/poo/mop TypeError?)
        (only-in :clan/poo/type String)
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/module-system/source/admission admit-module-configuration!)
        (only-in :agentic-ai-lab/opentofu-contracts
                 NullContract OpenTofuContract ServicesContract OpenTofuConfigContract)
        (only-in :agentic-ai-lab/modules/services/opentofu/config Config)
        (only-in :agentic-ai-lab/modules/services/opentofu/func opentofu-service-configuration))
(export opentofu-service-contract-test)

;; Exercise the same configuration association used by the actual Module.
(def declaration
  (.o admissions: (.o Config: (.o export-path: '(config) contract-path: '(types config)))))

;; Admission is evidence-bearing. Keep each negative candidate and verify
;; the original native failure, rather than expecting it to escape .admit.
(def (check-refused contract candidate)
  (def refused (.call contract .admit candidate #f))
  (check-equal? (yuanxu-validation-evidence-accepted? refused) #f)
  (check-equal? (pair? (.get refused diagnostics)) #t)
  (check-equal? (TypeError? (.get refused cause)) #t)
  (check-equal? (eq? (.get refused admission-contract) contract) #t))

(def opentofu-service-contract-test
  (test-suite "Services -> OpenTofu -> Null declarations"
    (yuanxu-test-case "enabled service without a Source retains build demand"
      (check-equal? (opentofu-service-configuration Config) #f)
      (.def (Enabled @ Config)
        services: =>.+ (.o opentofu: =>.+ (.o Null: (.o message: "needs preparation"))))
      (check-equal? (.get Enabled source) #f)
      (check-equal? (.get (opentofu-service-configuration Enabled)
                         resource null_resource hello triggers message) "needs preparation"))
    (yuanxu-test-case "declarations and final values correspond without artifacts"
      (check-equal? (eq? (.get ServicesContract responsibilities opentofu) OpenTofuContract) #t)
      (check-equal? (eq? (.get OpenTofuContract responsibilities Null type) NullContract) #t)
      (check-equal? (yuanxu-validation-evidence-accepted? (.call OpenTofuConfigContract .admit Config #f)) #t)
      (.def (Configured @ Config)
        services: =>.+ (.o opentofu: =>.+ (.o Null: (.o message: "configured"))))
      (def scope (.o config: Configured types: (.o config: OpenTofuConfigContract)))
      (check-equal? (.get (admit-module-configuration! scope declaration 'services/opentofu #f)
                         config services opentofu Null message) "configured")
      (check-equal? (.get Config services opentofu Null) #f))
    (yuanxu-test-case "unknown services, recipes and fields have no fallback"
      (def touched? #f)
      (.def (Unknown @ Config)
        services: =>.+ (.o opentofuu: (begin (set! touched? #t) (error "unknown value forced"))))
      (check-refused OpenTofuConfigContract Unknown)
      (check-equal? touched? #f)
      (.def (UnknownRecipe @ Config)
        services: =>.+ (.o opentofu: =>.+ (.o Nul: (.o message: "typo"))))
      (check-refused OpenTofuConfigContract UnknownRecipe)
      (.def (UnknownField @ Config)
        services: =>.+ (.o opentofu: =>.+ (.o Null: (.o message: "ok" messsage: "typo"))))
      (check-refused OpenTofuConfigContract UnknownField))
    (yuanxu-test-case "override cannot discard a field Type or missing Contract"
      (.def (Invalid @ Config)
        services: =>.+ (.o opentofu: =>.+ (.o Null: (.o message: 123))))
      (check-refused OpenTofuConfigContract Invalid)
      (check-exception
        (admit-module-configuration!
          (.o config: Config types: (.o)) declaration 'services/opentofu #f) error?)
      (check-exception
        (admit-module-configuration!
          (.o config: Config types: (.o config: #f)) declaration 'services/opentofu #f) error?))
    (yuanxu-test-case "new services become legal through POO Type extension"
      ;; Force the parent's prepared responsibilities before extending it.
      (.get ServicesContract prepared-responsibilities)
      (.def (Additional @ ObjectContract.) responsibilities: (.o label: String))
      (.def (Extended @ ServicesContract)
        responsibilities: =>.+ (.o additional: Additional))
      (.def (ExtendedConfig @ OpenTofuConfigContract)
        value-contract: =>.+ (.o responsibilities: =>.+ (.o services: Extended)))
      (.def (Values @ Config)
        services: =>.+ (.o additional: (.o label: "declared")))
      (check-refused OpenTofuConfigContract Values)
      (check-equal? (yuanxu-validation-evidence-accepted? (.call ExtendedConfig .admit Values #f)) #t))))
