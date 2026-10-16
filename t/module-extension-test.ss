;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: generic module extension tests keep POO resolution semantics out
;;; of feature-specific workflow code.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        :poo-flow/modules/workflow/scenario/configuration/interface
        :core/extension-graph/interface
        :core/module-system/schema/interface
        :poo-flow/modules/sandbox-core/shared-object
        :poo-flow/modules/nono-sandbox/objects
        :poo-flow/modules/cubeSandbox/objects)

(export module-extension-test)

;; : (-> PooModuleExtensionNode Symbol MaybeAny)
(def (slot-value node slot-name)
  (let (entry (assoc slot-name (poo-flow-module-extension-node-slots node)))
    (if entry (cdr entry) #f)))

;;; This suite locks extension composition behavior for user-authored modules
;;; without introducing a second module-system surface.
;; : TestSuite
(def module-extension-resolution-test
  (test-suite "poo-flow module extension resolution"
    (poo-flow-test-case "applies slot and child-node operations to a stable object graph"
      (let* ((build-node
              (poo-flow-module-extension-node
               'workflow/pipeline/default/task/build
               '((run . "gxi build.ss")
                 (env . (DEBUG CI))
                 (artifacts . ()))
               '()))
             (legacy-node
              (poo-flow-module-extension-node
               'workflow/pipeline/default/task/legacy
               '((run . "echo legacy"))
               '()))
             (root-node
              (poo-flow-module-extension-node
               'workflow/pipeline/default
               '((needs . (test)))
               (list build-node legacy-node)))
             (package-node
              (poo-flow-module-extension-node
               'workflow/pipeline/default/task/package
               '((run . "tar dist"))
               '()))
             (root-contribution
              (poo-flow-module-extension-contribution
               'workflow/pipeline/default
               (list
                (poo-flow-module-extension-slot-prepend 'needs '(setup))
                (poo-flow-module-extension-slot-append 'needs '(lint test))
                (poo-flow-module-extension-node-remove
                 'workflow/pipeline/default/task/legacy)
                (poo-flow-module-extension-node-extend package-node))))
             (build-contribution
              (poo-flow-module-extension-contribution
               'workflow/pipeline/default/task/build
               (list
                (poo-flow-module-extension-slot-override
                 'run
                 "gxi build.ss --optimized")
                (poo-flow-module-extension-slot-remove 'env '(DEBUG))
                (poo-flow-module-extension-slot-append 'artifacts '("dist")))))
             (result
              (poo-flow-module-extension-resolve
               root-node
               (list root-contribution build-contribution)))
             (resolved-root
              (poo-flow-module-extension-result-root result))
             (resolved-build
              (poo-flow-module-extension-child-ref
               (poo-flow-module-extension-node-children resolved-root)
               'workflow/pipeline/default/task/build))
             (resolved-package
              (poo-flow-module-extension-child-ref
               (poo-flow-module-extension-node-children resolved-root)
               'workflow/pipeline/default/task/package))
             (removed-legacy
              (poo-flow-module-extension-child-ref
               (poo-flow-module-extension-node-children resolved-root)
               'workflow/pipeline/default/task/legacy)))
        (check-equal? (poo-flow-module-extension-result? result) #t)
        (check-equal? (poo-flow-module-extension-result-stable? result) #t)
        (check-equal? (poo-flow-module-extension-result-iterations result) 1)
        (check-equal? (slot-value resolved-root 'needs) '(setup test lint))
        (check-equal? removed-legacy #f)
        (check-equal? (poo-flow-module-extension-node? resolved-package) #t)
        (check-equal? (slot-value resolved-build 'run)
                      "gxi build.ss --optimized")
        (check-equal? (slot-value resolved-build 'env) '(CI))
        (check-equal? (slot-value resolved-build 'artifacts) '("dist"))))

    (poo-flow-test-case "merges module config contributions through POO field contracts"
      (let* ((needs-field
              (poo-flow-module-field-contract
               'needs PooFlowModuleListType 'append '() '((domain . workflow))))
             (features-field
              (poo-flow-module-field-contract
               'features PooFlowModuleListType 'prepend '() '((domain . workflow))))
             (run-field
              (poo-flow-module-field-contract
               'run PooFlowModuleStringType 'override #f '((domain . workflow))))
             (root-node
              (poo-flow-module-extension-node
               'workflow/pipeline/default
               '((needs . (test))
                 (features . (ci)))
               '()))
             (result
              (poo-flow-module-field-contributions-resolve
               root-node
               (list
                (poo-flow-module-field-contribution
                 'workflow/pipeline/default needs-field '(lint test))
                (poo-flow-module-field-contribution
                 'workflow/pipeline/default features-field '(sandbox))
                (poo-flow-module-field-contribution
                 'workflow/pipeline/default run-field "gxi build.ss")
                (poo-flow-module-field-contribution
                 'workflow/pipeline/default run-field
                 "gxi build.ss --optimized"))))
             (resolved-root
              (poo-flow-module-field-resolution-result-root result)))
        (check-equal? (poo-flow-module-field-contract? needs-field) #t)
        (check-equal? (poo-flow-module-field-contract-accepts?
                       needs-field '(lint))
                      #t)
        (check-equal? (poo-flow-module-field-contract-accepts?
                       needs-field 'lint)
                      #f)
        (check-equal? (poo-flow-module-field-resolution-result? result) #t)
        (check-equal? (poo-flow-module-field-resolution-result-stable? result) #t)
        (check-equal? (poo-flow-module-field-resolution-result-iterations result) 1)
        (check-equal? (slot-value resolved-root 'needs) '(test lint))
        (check-equal? (slot-value resolved-root 'features) '(sandbox ci))
        (check-equal? (slot-value resolved-root 'run)
                      "gxi build.ss --optimized")))))

;;; This suite keeps object inheritance and C4 precedence separate from the
;;; slot-level resolution tests above.
;; : TestSuite
(def module-extension-object-inheritance-test
  (test-suite "poo-flow module object inheritance"
    (poo-flow-test-case "inherits shared sandbox module objects for nono and cube"
      (let* ((shared-sandbox-object
              (poo-flow-module-object
               'sandbox/shared
               '()
               (list
                (poo-flow-module-field-contract
                 'backend PooFlowModuleSymbolType 'override 'sandbox '())
                (poo-flow-module-field-contract
                 'flags PooFlowModuleListType 'append '() '())
                (poo-flow-module-field-contract
                 'runtime-args PooFlowModuleListType 'append '() '()))
               '((domain . sandbox))))
             (nono-sandbox-object
              (poo-flow-module-object
               'sandbox/nono
               (list shared-sandbox-object)
               (list
                (poo-flow-module-field-contract
                 'backend PooFlowModuleSymbolType 'override 'nono '())
                (poo-flow-module-field-contract
                 'binding PooFlowModuleSymbolType 'override 'none '()))
               '((backend . nono))))
             (cube-sandbox-object
              (poo-flow-module-object
               'sandbox/cube
               (list shared-sandbox-object)
               (list
                (poo-flow-module-field-contract
                 'backend PooFlowModuleSymbolType 'override 'cube '())
                (poo-flow-module-field-contract
                 'profile PooFlowModuleSymbolType 'override 'default '()))
               '((backend . cube))))
             (root-node
              (poo-flow-module-extension-node
               'sandbox/shared
               '()
               (list
                (poo-flow-module-object-node nono-sandbox-object '() '())
                (poo-flow-module-object-node cube-sandbox-object '() '()))))
             (result
              (poo-flow-module-field-contributions-resolve
               root-node
               (append
                (poo-flow-module-object-contributions
                 nono-sandbox-object
                 '((flags . (doctor nono))
                   (runtime-args . ("--trace-nono"))
                   (binding . c)))
                (poo-flow-module-object-contributions
                 cube-sandbox-object
                 '((flags . (doctor cube))
                   (runtime-args . ("--trace-cube"))
                   (profile . strict))))))
             (resolved-root
              (poo-flow-module-field-resolution-result-root result))
             (resolved-nono
              (poo-flow-module-extension-child-ref
               (poo-flow-module-extension-node-children resolved-root)
               'sandbox/nono))
             (resolved-cube
              (poo-flow-module-extension-child-ref
               (poo-flow-module-extension-node-children resolved-root)
               'sandbox/cube)))
        (check-equal? (poo-flow-module-object? shared-sandbox-object) #t)
        (check-equal? (map poo-flow-module-field-contract-identity
                           (poo-flow-module-object-resolved-fields
                            nono-sandbox-object))
                      '(backend flags runtime-args binding))
        (check-equal? (slot-value resolved-nono 'backend) 'nono)
        (check-equal? (slot-value resolved-nono 'flags) '(doctor nono))
        (check-equal? (slot-value resolved-nono 'runtime-args)
                      '("--trace-nono"))
        (check-equal? (slot-value resolved-nono 'binding) 'c)
        (check-equal? (slot-value resolved-cube 'backend) 'cube)
        (check-equal? (slot-value resolved-cube 'flags) '(doctor cube))
        (check-equal? (slot-value resolved-cube 'runtime-args)
                      '("--trace-cube"))
        (check-equal? (slot-value resolved-cube 'profile) 'strict)))

    (poo-flow-test-case "resolves module object fields through gerbil-poo C4 precedence"
      (let* ((root-object
              (poo-flow-module-object
               'object/root
               '()
               (list
                (poo-flow-module-field-contract
                 'shared PooFlowModuleSymbolType 'override 'root '())
                (poo-flow-module-field-contract
                 'root-only PooFlowModuleSymbolType 'override 'root-only '()))
               '()))
             (right-object
              (poo-flow-module-object
               'object/right
               (list root-object)
               (list
                (poo-flow-module-field-contract
                 'shared PooFlowModuleSymbolType 'override 'right '())
                (poo-flow-module-field-contract
                 'right-only PooFlowModuleSymbolType 'override 'right-only '()))
               '()))
             (left-object
              (poo-flow-module-object
               'object/left
               (list root-object)
               (list
                (poo-flow-module-field-contract
                 'shared PooFlowModuleSymbolType 'override 'left '())
                (poo-flow-module-field-contract
                 'left-only PooFlowModuleSymbolType 'override 'left-only '()))
               '()))
             (child-object
              (poo-flow-module-object
               'object/child
               (list left-object right-object)
               (list
                (poo-flow-module-field-contract
                 'child-only PooFlowModuleSymbolType 'override 'child-only '()))
               '())))
        (check-equal? (map poo-flow-module-field-contract-identity
                           (poo-flow-module-object-fields child-object))
                      '(child-only))
        (check-equal? (map poo-flow-module-field-contract-identity
                           (poo-flow-module-object-resolved-fields
                            child-object))
                      '(shared root-only right-only left-only child-only))
        (check-equal? (poo-flow-module-field-contract-default
                       (poo-flow-module-object-field child-object 'shared))
                      'left)
        (check-equal? (poo-flow-module-field-contract-default
                       (poo-flow-module-object-field child-object 'right-only))
                      'right-only)
        (check-equal? (poo-flow-module-field-contract-default
                       (poo-flow-module-object-field child-object 'root-only))
                      'root-only)))))

;;; This suite keeps inconsistent graph handling and real object namespace
;;; merging apart from the inheritance examples.
;; : TestSuite
(def module-extension-object-merge-test
  (test-suite "poo-flow module object merge"
    (poo-flow-test-case "rejects inconsistent gerbil-poo C4 module object graphs"
      (let* ((root-object
              (poo-flow-module-object
               'object/root
               '()
               (list
                (poo-flow-module-field-contract
                 'shared PooFlowModuleSymbolType 'override 'root '()))
               '()))
             (a-object
              (poo-flow-module-object
               'object/a
               (list root-object)
               '()
               '()))
             (b-object
              (poo-flow-module-object
               'object/b
               (list root-object)
               '()
               '()))
             (x-object
              (poo-flow-module-object
               'object/x
               (list a-object b-object)
               '()
               '()))
             (y-object
              (poo-flow-module-object
               'object/y
               (list b-object a-object)
               '()
               '()))
             (broken-object
              (poo-flow-module-object
               'object/broken
               (list x-object y-object)
               '()
               '()))
             (failure
              (with-catch (lambda (failure) failure)
                          (lambda ()
                            (poo-flow-module-object-resolved-fields
                             broken-object)))))
        (check-equal? (not (not failure)) #t)))

    (poo-flow-test-case "merges real module objects under the objects namespace"
      (let* ((objects
              (append poo-flow-shared-module-objects
                      poo-flow-nono-sandbox-module-objects
                      poo-flow-cubeSandbox-module-objects))
             (result
              (poo-flow-module-objects-resolve-contributions
               objects
               (append
                (poo-flow-module-object-contributions
                 poo-flow-nono-sandbox-object
                 '((flags . (doctor nono))
                   (runtime-args . ("--trace-nono"))
                   (binding . c)))
                (poo-flow-module-object-contributions
                 poo-flow-cubeSandbox-object
                 '((flags . (doctor cube))
                   (runtime-args . ("--trace-cube"))
                   (profile . strict))))))
             (resolved-objects
              (poo-flow-module-field-resolution-result-root result))
             (resolved-shared
              (poo-flow-module-objects-ref
               resolved-objects
               'objects.shared.sandbox))
             (resolved-nono
              (poo-flow-module-objects-ref
               resolved-objects
               'objects.nono-sandbox.sandbox))
             (resolved-cube
              (poo-flow-module-objects-ref
               resolved-objects
               'objects.cubeSandbox.sandbox)))
        (check-equal? (poo-flow-module-extension-node-identity
                       resolved-objects)
                      'objects)
        (check-equal? (slot-value resolved-objects 'namespace) 'objects)
        (check-equal? (slot-value resolved-shared 'backend) 'sandbox)
        (check-equal? (slot-value resolved-nono 'backend) 'nono)
        (check-equal? (slot-value resolved-nono 'flags) '(doctor nono))
        (check-equal? (slot-value resolved-nono 'binding) 'c)
        (check-equal? (slot-value resolved-cube 'backend) 'cube)
        (check-equal? (slot-value resolved-cube 'flags) '(doctor cube))
        (check-equal? (slot-value resolved-cube 'profile) 'strict)))))

;;; Aggregate export preserves the historical module-extension-test symbol while
;;; the parser sees smaller suite owners.
;; : TestSuite
(def module-extension-test
  (test-suite "poo-flow module extension"
    module-extension-resolution-test
    module-extension-object-inheritance-test
    module-extension-object-merge-test))
