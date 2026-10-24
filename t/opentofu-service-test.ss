;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declared configuration -> one selected product -> real Null execution.
(import :std/test :clan/poo/object
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/mop TypeError?)
        (only-in :yuanxu/module-system/source/admission admit-module-configuration!)
        (only-in "./qualification/opentofu/service.ss" call-with-service rejects? empty-state?))
(export opentofu-service-test)

;; Admission, inheritance and successful publication share one real selection.
(def opentofu-service-test
  (test-suite "Declared and selected OpenTofu service"
    (yuanxu-test-case "closed configuration and same-product execution"
      (call-with-service
        (lambda (fixture)
          (def source-scope (.call fixture .source-scope))
          (def unprepared (.get source-scope Null))
          (def work (.call fixture .workspace "work"))
          (check-equal? (not (.ref/cached unprepared 'provider)) #t)
          (check-equal? (rejects? "build-required" (lambda () (.call unprepared .run work))) #t)
          (check-equal? (directory-files work) '())
          (def selected-config (.get source-scope config))
          (for-each
            (lambda (invalid)
              (check-exception
                (.call (.get source-scope types config) .admit invalid #f) TypeError?))
            (list
              (.cc selected-config 'services (.o opentofu: (.o Null: (.o message: 123))))
              (.cc selected-config 'services
                (.cc (.get selected-config services) 'opentofuu (.o)))
              (.cc selected-config 'services
                (.o opentofu: (.cc (.get selected-config services opentofu) 'Nul (.o))))))
          (check-equal?
            (rejects? "Contract path is missing"
              (lambda ()
                (admit-module-configuration! source-scope
                  (.o admissions: (.o Config: (.o export-path: '(config) contract-path: '(types missing))))
                  'services/opentofu #f))) #t)
          (check-equal? (directory-files work) '())
          (displayln "PHASE ready-scope") (force-output)
          (def prepared (.call fixture .prepare))
          (def OpenTofu (.get prepared ready-scope))
          (def Null (.get prepared recipe))
          (check-equal? (not (.ref/cached Null 'publication)) #t)
          (check-equal? (.all-slots (.get OpenTofu modules)) '(null))
          (check-equal? (.get Null command)
            (list (path-expand "engine/bin/tofu" (.get Null provider source value))))
          (check-equal? (.get Null resource triggers message) "configured service")
          (.def (Hello @ Null) message: "selected ${literal} %{literal}")
          (displayln "PHASE apply-output-cleanup") (force-output)
          (def result (.call Hello .run work))
          (check-equal? (eq? (.get Hello publication) (.get Null publication)) #t)
          (check-equal? (.get result output) "selected ${literal} %{literal}")
          (check-equal? (.get result steps destroy status) 0)
          (check-equal? (empty-state? work) #t)
          ;; Product identity is the immutable output and exact manifest;
          ;; distinct POO receivers need not share an allocation address.
          (let ((published (.get Null provider))
                (visible (.get OpenTofu modules null provider)))
            (check-equal? (.get published source value) (.get visible source value))
            (for-each
              (lambda (field) (check-equal? (.ref published field) (.ref visible field)))
              '(provider version schema-digest)))
          (check-equal? (.get Null resource triggers message) "configured service")
          (def rejected (.call fixture .workspace "wrong-command"))
          (.def (WrongCommand @ Hello) command: '("false"))
          (check-equal? (rejects? "must match" (lambda () (.call WrongCommand .run rejected))) #t)
          (check-equal? (directory-files rejected) '())
          ;; The root command check also covers direct Task and cleanup overrides.
          (.def (WrongTask @ Hello)
            tasks: =>.+ (.o output: =>.+ (.o command: '("false"))))
          (.def (WrongCleanup @ Hello)
            tasks: =>.+ (.o destroy: =>.+ (.o command: '("false"))))
          (for-each
            (lambda (recipe)
              (check-equal? (rejects? "selected execution and engine"
                              (lambda () (.call recipe .run rejected))) #t)
              (check-equal? (directory-files rejected) '()))
            (list WrongTask WrongCleanup))
          (displayln "OPENTOFU-SERVICE-OK"))))))
