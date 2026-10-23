;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox backend object-family macro contracts.
;;; Invariant: generated backend objects stay POO-native and runtime-free.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-eq?
                 check-equal?
                 test-suite)
        :yuanxu/module-system/schema/interface
        :poo-flow/modules/sandbox-core/objects
        :poo-flow/modules/sandbox-core/profile-support/policy
        :poo-flow/modules/nono-sandbox/objects
        :poo-flow/modules/cubeSandbox/objects
        :poo-flow/modules/docker-sandbox/objects)

;; : (-> Symbol Alist MaybeValue)
(def (alist-ref/default key entries default)
  (let (entry (and (list? entries) (assoc key entries)))
    (if entry (cdr entry) default)))

;; : (-> PooModuleObject Symbol PooModuleFieldContract)
(def (required-field object field)
  (let (contract (yuanxu-module-object-field object field))
    (check-equal? (yuanxu-module-field-contract? contract) #t)
    contract))

;; : (-> PooModuleObject Symbol Value)
(def (field-default object field)
  (yuanxu-module-field-contract-default
   (required-field object field)))

;; : (-> PooModuleObject Symbol Symbol)
(def (field-value-kind object field)
  (yuanxu-module-value-type-kind
   (yuanxu-module-field-contract-value-type
    (required-field object field))))

;; : (-> PooModuleObject Symbol Alist)
(def (field-metadata object field)
  (yuanxu-module-field-contract-metadata
   (required-field object field)))

;; : (-> Object Symbol Object Void)
(def (check-backend-registry registry key capability)
  (check-equal? (poo-flow-sandbox-backend-capability-registry? registry) #t)
  (check-equal? (poo-flow-sandbox-backend-capability-registry-entries registry)
                (list (cons key capability)))
  (check-eq? (poo-flow-sandbox-backend-capability-registry-ref registry key)
             capability)
  (check-eq? (poo-flow-sandbox-backend-capability/backend-kind capability)
             key))

(export sandbox-backend-object-family-test)

(def sandbox-backend-object-family-test
 (test-suite "sandbox backend object family macro contracts"
   (yuanxu-test-case "generates backend object identities and metadata"
     (check-equal? (yuanxu-module-object? poo-flow-nono-sandbox-object) #t)
     (check-equal? (yuanxu-module-object? poo-flow-cubeSandbox-object) #t)
     (check-equal? (yuanxu-module-object? poo-flow-docker-sandbox-object) #t)
     (check-eq? (yuanxu-module-object-identity
                 poo-flow-nono-sandbox-object)
                'objects.nono-sandbox.sandbox)
     (check-eq? (yuanxu-module-object-identity
                 poo-flow-cubeSandbox-object)
                'objects.cubeSandbox.sandbox)
     (check-eq? (yuanxu-module-object-identity
                 poo-flow-docker-sandbox-object)
                'objects.docker-sandbox.sandbox)
     (check-eq? (alist-ref/default
                 'domain
                 (yuanxu-module-object-metadata
                  poo-flow-docker-sandbox-object)
                 #f)
                'sandbox)
     (check-eq? (alist-ref/default
                 'namespace
                 (yuanxu-module-object-metadata
                  poo-flow-docker-sandbox-object)
                 #f)
                'objects.docker-sandbox))
   (yuanxu-test-case "generates backend field contracts"
     (check-eq? (field-value-kind poo-flow-nono-sandbox-object 'backend)
                'Symbol)
     (check-eq? (field-default poo-flow-nono-sandbox-object 'backend)
                'nono)
     (check-eq? (field-value-kind poo-flow-docker-sandbox-object 'image)
                'String)
     (check-equal? (field-default poo-flow-docker-sandbox-object 'image)
                   "ubuntu:latest")
     (check-eq? (alist-ref/default
                 'scope
                 (field-metadata poo-flow-cubeSandbox-object 'profile)
                 #f)
                'cubeSandbox)
     (check-equal? (yuanxu-module-object-field
                    poo-flow-docker-sandbox-object
                    'backend-ref)
                   #f))
   (yuanxu-test-case "generates profile object inheritance and resolved fields"
     (check-equal? (yuanxu-module-object?
                    poo-flow-nono-sandbox-profile-object)
                   #t)
     (check-equal? (yuanxu-module-object?
                    poo-flow-cubeSandbox-profile-object)
                   #t)
     (check-equal? (yuanxu-module-object?
                    poo-flow-docker-sandbox-profile-object)
                   #t)
     (check-eq? (yuanxu-module-object-identity
                 poo-flow-docker-sandbox-profile-object)
                'objects.docker-sandbox.profile)
     (check-equal? (yuanxu-module-object-inherits
                    poo-flow-docker-sandbox-profile-object)
                   (list poo-flow-sandbox-core-profile-object
                         poo-flow-docker-sandbox-object))
     (check-eq? (field-default
                 poo-flow-docker-sandbox-profile-object
                 'backend-kind)
                'docker)
     (check-eq? (field-default
                 poo-flow-docker-sandbox-profile-object
                 'backend)
                'docker)
     (check-equal? (field-default
                    poo-flow-docker-sandbox-profile-object
                    'image)
                   "ubuntu:latest")
     (check-eq? (field-value-kind
                 poo-flow-nono-sandbox-profile-object
                 'metadata)
                'List)
     (check-equal? (field-default
                    poo-flow-cubeSandbox-profile-object
                    'resource-policy)
                   '((filesystem
                      (scope . snapshot)
                      (snapshot . clone)))))
   (yuanxu-test-case "generates backend capability registries"
     (check-backend-registry
      poo-flow-nono-sandbox-backend-capability-registry
      'nono
      poo-flow-nono-sandbox-backend-capability)
     (check-backend-registry
      poo-flow-cubeSandbox-backend-capability-registry
      'cube
      poo-flow-cubeSandbox-backend-capability)
     (check-backend-registry
      poo-flow-docker-sandbox-backend-capability-registry
      'docker
      poo-flow-docker-sandbox-backend-capability))))
