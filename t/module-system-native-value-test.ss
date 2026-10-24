;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public module-system data families stay native POO values.
;;; Invariant: Loader, resolver, diagnostics, and projection APIs expose
;;; prototype-composable objects rather than parallel Scheme records.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .ref object?)
        (only-in :std/test check-equal? test-suite)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/module-diagnostics
                 make-agentic-ai-lab-module-diagnostic)
        :yuanxu/module-system/source/imports
        :yuanxu/module-system/source/objects
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-activation
        :agentic-ai-lab/modules/workflow/scenario/configuration/module-runtime-presentation
        :yuanxu/module-system/loader/objects
        :yuanxu/module-system/catalog/objects
        :yuanxu/module-system/projection/option-objects)

(export module-system-native-value-test)

;; : (-> POOObject Symbol Boolean)
(def (native-family-marker? value marker)
  (and (object? value) (.ref value marker)))

;; : TestSuite
(def module-system-native-value-test
  (test-suite "native POO module-system value families"
    (yuanxu-test-case "source loader resolver diagnostics and projections compose as POO"
      (let* ((source (yuanxu-local-source "modules/example/config.ss"))
             (module
              (make-empty-agentic-ai-lab-module-descriptor
               'example '() '((owner . native-value-test))))
             (loader-entry
              (make-yuanxu-module-loader-entry source module))
             (backend
              (yuanxu-module-static-loader
               'native-value-test 'local (list loader-entry)))
             (load-receipt
              (yuanxu-module-load-source-receipt
               (list backend) source))
             (catalog-entry
              (make-yuanxu-module-catalog-entry source module))
             (catalog
              (make-yuanxu-module-catalog
               'native-value-test (list catalog-entry)))
             (activation (activate-agentic-ai-lab-modules (list module)))
             (diagnostic
              (make-agentic-ai-lab-module-diagnostic
               'warning 'native-value-test 'module '()))
             (option-config
              (make-yuanxu-module-option-config
               "enabled" #t 'example '()))
             (option-schema
              (make-yuanxu-module-option-schema
               "enabled" 'example 'Boolean 'default #t '()))
             (option-receipt
              (make-yuanxu-module-option-validation-receipt
               "enabled" 'example #t 'valid '() '()))
             (runtime-module (agentic-ai-lab-module-apply module)))
        (check-equal?
         (native-family-marker? source 'module-source-ref?) #t)
        (check-equal?
         (native-family-marker? loader-entry 'loader-entry?) #t)
        (check-equal?
         (native-family-marker? backend 'loader-backend?) #t)
        (check-equal?
         (native-family-marker? load-receipt 'load-receipt?) #t)
        (check-equal?
         (native-family-marker? catalog-entry 'catalog-entry?) #t)
        (check-equal?
         (native-family-marker? catalog 'catalog?) #t)
        (check-equal?
         (native-family-marker? activation 'activation?) #t)
        (check-equal?
         (native-family-marker? diagnostic 'module-diagnostic?) #t)
        (check-equal?
         (native-family-marker? option-config 'option-config?) #t)
        (check-equal?
         (native-family-marker? option-schema 'option-schema?) #t)
        (check-equal?
         (native-family-marker?
          option-receipt 'option-validation-receipt?)
         #t)
        (check-equal? (object? runtime-module) #t)
        (check-equal? (.ref runtime-module 'id) 'example)
        (check-equal?
         (resolve-agentic-ai-lab-module-source catalog source)
         module)))))
