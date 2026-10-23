;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Agentic AI Lab integration with Core's native module-schema admission.

(import :gerbil/core
        (only-in :clan/poo/object .ref object?)
        (only-in :std/test test-suite check-equal? check-exception)
        (only-in :yuanxu/observability/testing-case
                 yuanxu-test-case)
        :yuanxu/module-system/schema/interface
        :yuanxu/module-system/schema/validation)

(export module-object-validation-test)

(def validation-shared-sandbox-object
  (yuanxu-module-object
   'objects.validation.shared
   '()
   (list
    (yuanxu-module-field-contract
     'flags YuanxuModuleListType 'override '() '((scope . validation)))
    (yuanxu-module-field-contract
     'runtime-args YuanxuModuleListType 'override '() '((scope . validation))))
   '((domain . validation))))

(def validation-nono-sandbox-object
  (yuanxu-module-object
   'objects.validation.nono
   (list validation-shared-sandbox-object)
   (list
    (yuanxu-module-field-contract
     'backend YuanxuModuleSymbolType 'override 'nono '((scope . validation)))
    (yuanxu-module-field-contract
     'binding YuanxuModuleSymbolType 'override 'native-ffi
     '((scope . validation))))
   '((domain . validation))))

(def module-object-validation-test
  (test-suite "agentic-ai-lab native module object validation"
    (yuanxu-test-case "admits inherited module objects through native Type and C4"
      (let* ((validation
              (yuanxu-module-object-validation validation-nono-sandbox-object))
             (field-validations (.ref validation 'fieldContractValidations))
             (field-origins (.ref validation 'field-origins)))
        (check-equal? (yuanxu-module-object-validation? validation) #t)
        (check-equal? (eq? validation
                          (yuanxu-module-object-validation
                           validation-nono-sandbox-object))
                      #t)
        (check-equal? (and (object? validation)
                           (andmap object? field-validations)
                           (andmap object? field-origins))
                      #t)
        (check-equal? (yuanxu-module-object-validation-valid? validation) #t)
        (check-equal? (.ref validation 'inheritance-chain)
                      '(objects.validation.nono objects.validation.shared))
        (check-equal? (.ref validation 'direct-field-identities)
                      '(backend binding))
        (check-equal? (.ref validation 'resolved-field-identities)
                      '(flags runtime-args backend binding))
        (check-equal? (map (lambda (origin)
                             (cons (.ref origin 'field) (.ref origin 'provider)))
                           field-origins)
                      '((flags . objects.validation.shared)
                        (runtime-args . objects.validation.shared)
                        (backend . objects.validation.nono)
                        (binding . objects.validation.nono)))
        (check-equal? (map (lambda (entry) (.ref entry 'valueKind))
                           field-validations)
                      '(List List Symbol Symbol))
        (check-equal? (andmap yuanxu-module-field-contract-validation-valid?
                              field-validations)
                      #t)
        (check-equal? (yuanxu-module-object-validation-diagnostics validation)
                      '())))

    (yuanxu-test-case "rejects symbolic field kinds at the native Type boundary"
      (check-exception
       (yuanxu-module-field-contract
        'broken 'Unknown 'override #f '((scope . validation)))
       true))

    (yuanxu-test-case "reports native field contract diagnostics"
      (let* ((broken-object
              (yuanxu-module-object
               'objects.validation.broken
               '()
               (list (yuanxu-module-field-contract
                      'broken YuanxuModuleStringType 'merge-strategy 42
                      'not-an-alist))
               '((domain . validation))))
             (validation (yuanxu-module-object-validation broken-object))
             (field-validation
              (car (.ref validation 'fieldContractValidations))))
        (check-equal? (yuanxu-module-object-validation-valid? validation) #f)
        (check-equal? (map (lambda (diagnostic) (.ref diagnostic 'code))
                           (yuanxu-module-object-validation-diagnostics
                            validation))
                      '(unsupported-merge metadata-not-association-list
                        default-not-in-native-type))
        (check-equal? (yuanxu-module-field-contract-validation-valid?
                       field-validation)
                      #f)
        (check-equal?
         (with-catch
          (lambda (_) #t)
          (lambda ()
            (yuanxu-require-module-object-validation! broken-object)
            #f))
         #t)))

    (yuanxu-test-case "requires every catalog object to pass native admission"
      (check-equal?
       (yuanxu-require-module-objects-validation!
        (list validation-shared-sandbox-object
              validation-nono-sandbox-object))
       (list validation-shared-sandbox-object
             validation-nono-sandbox-object)))))
