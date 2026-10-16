;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public module-system data families stay native POO values.
;;; Invariant: Loader, resolver, diagnostics, and projection APIs expose
;;; prototype-composable objects rather than parallel Scheme records.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :clan/poo/object .ref object?)
        (only-in :std/test check-equal? test-suite)
        (only-in :poo-flow/modules/workflow/scenario/configuration/module-diagnostics
                 make-poo-flow-module-diagnostic)
        :core/module-system/source/imports
        :core/module-system/source/objects
        :poo-flow/modules/module-authoring/module-descriptor
        :poo-flow/modules/workflow/scenario/configuration/module-activation
        :poo-flow/modules/workflow/scenario/configuration/module-runtime-presentation
        :core/module-system/loader/objects
        :core/module-system/catalog/objects
        :core/module-system/projection/option-objects)

(export module-system-native-value-test)

;; : (-> POOObject Symbol Boolean)
(def (native-family-marker? value marker)
  (and (object? value) (.ref value marker)))

;; : TestSuite
(def module-system-native-value-test
  (test-suite "native POO module-system value families"
    (poo-flow-test-case "source loader resolver diagnostics and projections compose as POO"
      (let* ((source (poo-flow-local-source "modules/example/config.ss"))
             (module
              (make-empty-poo-flow-module-descriptor
               'example '() '((owner . native-value-test))))
             (loader-entry
              (make-poo-flow-module-loader-entry source module))
             (backend
              (poo-flow-module-static-loader
               'native-value-test 'local (list loader-entry)))
             (load-receipt
              (poo-flow-module-load-source-receipt
               (list backend) source))
             (catalog-entry
              (make-poo-flow-module-catalog-entry source module))
             (catalog
              (make-poo-flow-module-catalog
               'native-value-test (list catalog-entry)))
             (activation (activate-poo-flow-modules (list module)))
             (diagnostic
              (make-poo-flow-module-diagnostic
               'warning 'native-value-test 'module '()))
             (option-config
              (make-poo-flow-module-option-config
               "enabled" #t 'example '()))
             (option-schema
              (make-poo-flow-module-option-schema
               "enabled" 'example 'Boolean 'default #t '()))
             (option-receipt
              (make-poo-flow-module-option-validation-receipt
               "enabled" 'example #t 'valid '() '()))
             (runtime-module (poo-flow-module-apply module)))
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
         (resolve-poo-flow-module-source catalog source)
         module)))))
