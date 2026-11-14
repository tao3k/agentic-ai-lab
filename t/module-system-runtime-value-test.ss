;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public module-system data families stay POO values.
;;; Invariant: Loader, resolver, diagnostics, and projection APIs expose
;;; prototype-composable objects rather than parallel Scheme records.

(import (only-in :clan/poo/type Record)
        (only-in :clan/poo/mop Bool make-instance element?)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .o .ref object?)
        (only-in :std/test check-equal? test-suite)
        (only-in :tao3k/agentic-ai-lab/modules/workflow/scenario/configuration/module-diagnostics
                 make-agentic-ai-lab-module-diagnostic)
        :tao3k/yuanxu/module-system/source/imports
        :tao3k/yuanxu/module-system/source/objects
        :tao3k/agentic-ai-lab/modules/module-authoring/module-descriptor
        :tao3k/agentic-ai-lab/modules/workflow/scenario/configuration/module-activation
        :tao3k/agentic-ai-lab/modules/workflow/scenario/configuration/module-runtime-presentation
        :tao3k/yuanxu/module-system/loader/objects
        :tao3k/yuanxu/module-system/catalog/objects
        :tao3k/yuanxu/module-system/projection/option-objects)

(export module-system-runtime-value-test)

;; : (-> POOObject Symbol Boolean)
(def (runtime-family-marker? value marker)
  (and (object? value) (.ref value marker)))

;; : TestSuite
(def module-system-runtime-value-test
  (test-suite "POO module-system value families"
    (yuanxu-test-case "source loader resolver diagnostics and projections compose as POO"
      (let* ((source (yuanxu-local-source "modules/example/config.ss"))
             (module
              (make-empty-agentic-ai-lab-module-descriptor
               'example '() '((owner . runtime-value-test))))
             (loader-entry
              (make-instance ModuleSourceBinding source: source module: module))
             (backend
              (yuanxu-module-static-loader
               'runtime-value-test 'local (list loader-entry)))
             (load-receipt
              (yuanxu-module-load-source-receipt
               (list backend) source))
             (catalog
              (make-instance ModuleCatalog
               name: 'runtime-value-test entries: (list loader-entry)))
             (activation (activate-agentic-ai-lab-modules (list module)))
             (diagnostic
              (make-agentic-ai-lab-module-diagnostic
               'warning 'runtime-value-test 'module '()))
             (option-config
              (.o id: "enabled" value: #t source-module: 'example metadata: '()))
             (option-schema
              (make-instance ModuleOptionSchema
               id: "enabled" source-module: 'example field: (.ref (.ref (Record enabled: [Bool default: #t]) 'effective-slots) 'enabled)))
             (option-receipt
              (.o id: "enabled" source-module: 'example valid?: #t
                  code: 'valid messages: '() metadata: '()))
             (runtime-module (agentic-ai-lab-module-apply module)))
        (check-equal?
         (runtime-family-marker? source 'module-source-ref?) #t)
        (check-equal?
         (element? ModuleSourceBinding loader-entry) #t)
        (check-equal?
         (element? ModuleLoaderBackend backend) #t)
        (check-equal?
         (element? ModuleLoadReceipt load-receipt) #t)
        (check-equal? (eq? (car (.ref catalog 'entries)) loader-entry) #t)
        (check-equal?
         (element? ModuleCatalog catalog) #t)
        (check-equal?
         (runtime-family-marker? activation 'activation?) #t)
        (check-equal?
         (runtime-family-marker? diagnostic 'module-diagnostic?) #t)
        (check-equal?
         (object? option-config) #t)
        (check-equal?
         (element? ModuleOptionSchema option-schema) #t)
        (check-equal?
         (object? option-receipt)
         #t)
        ;; Reporting projections retain explicit attribution and verdict fields.
        (check-equal? (.get option-config source-module) 'example)
        (check-equal? (.get option-config value) #t)
        (check-equal? (.get option-receipt valid?) #t)
        (check-equal? (object? runtime-module) #t)
        (check-equal? (.ref runtime-module 'id) 'example)
        (check-equal?
         (resolve-agentic-ai-lab-module-source catalog source)
         module)))))
