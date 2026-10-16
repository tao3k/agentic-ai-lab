;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: executable contracts for the public module/profile macro surface.
;;; Invariant: syntax lowers to ordinary POO objects and pure projection values.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :poo-flow/modules/workflow/scenario/configuration/init-syntax
                 poo-flow-profile-extend)
        (only-in :poo-flow/modules/module-authoring/fragment-syntax
                 poo-flow-load-profile-module-binding)
        (only-in :core/module-system/selection/objects
                 poo-flow-user-module-bundle)
        (only-in :poo-flow/modules/workflow/scenario/configuration/profile-config
                 poo-flow-user-profile-module-bundles
                 poo-flow-user-profile-name)
        (only-in :poo-flow/modules/workflow/profiles/kernel/interface
                 poo-flow-kernel-profile)
        (only-in :core/utilities/final-projection-syntax
                 poo-flow-product-field-rows/tail)
        (only-in :poo-flow/modules/ai-agentic-context/features/memory/durable/artifact-policy
                 artifact-module
                 database-module
                 poo-flow-artifact-profile?
                 poo-flow-artifact-database-profile?)
        :poo-flow/modules/cubeSandbox/config
        :poo-flow/modules/docker-sandbox/config
        :poo-flow/modules/nono-sandbox/config
        (only-in :poo-flow/modules/sandbox-core/profile
                 poo-flow-sandbox-profile-backend-kind
                 poo-flow-sandbox-profile-name))

(export module-macro-surface-test)

;;; The loader identifier macro preserves the call-site binding while using
;;; the canonical fallback module name outside a custom/<name> source tree.
(def poo-flow-custom-module-syntax-probe-module 'syntax-probe-binding)

(def load-profile-binding
  (poo-flow-load-profile-module-binding syntax-probe))

;;; Profile extension remains a POO-native declaration and appends complete
;;; module bundles without flattening individual module selection rows.
(def macro-extra-module-bundles
  (list
   (poo-flow-user-module-bundle
    (custom macro-surface "/tmp/poo-flow-macro-surface" +contract))))

(poo-flow-profile-extend macro-extended-profile
                         macro-extended
                         poo-flow-kernel-profile
  (bundles macro-extra-module-bundles))

;;; Each backend macro is called directly so its public shorthand is covered,
;;; while the collection forms exercise the shared ordered build recursion.
(def cube-direct-profile
  (poo-flow-cubeSandbox-profile cube/direct
    (metadata (declared-by . macro-surface-test))))

(def cube-derived-profile
  (poo-flow-cubeSandbox-profile-derive
   cube-direct-profile
   cube/derived
   ((scope . session))
   (metadata (derived-by . macro-surface-test))))

(def cube-profile-list
  (poo-flow-cubeSandbox-profiles
   (cube/list (metadata (declared-by . collection)))
   (cube/list-derived
    (:derive cube/list (scope . task))
    (metadata (derived-by . collection)))))

(def docker-direct-profile
  (poo-flow-docker-sandbox-profile docker/direct
    (metadata (declared-by . macro-surface-test))))

(def docker-derived-profile
  (poo-flow-docker-sandbox-profile-derive
   docker-direct-profile
   docker/derived
   ((scope . session))
   (metadata (derived-by . macro-surface-test))))

(def docker-profile-list
  (poo-flow-docker-sandbox-profiles
   (docker/list (metadata (declared-by . collection)))
   (docker/list-derived
    (:derive docker/list (scope . task))
    (metadata (derived-by . collection)))))

(def nono-direct-profile
  (poo-flow-nono-sandbox-profile nono/direct
    (metadata (declared-by . macro-surface-test))))

(def nono-derived-profile
  (poo-flow-nono-sandbox-profile-derive
   nono-direct-profile
   nono/derived
   ((scope . session))
   (metadata (derived-by . macro-surface-test))))

(def nono-profile-list
  (poo-flow-nono-sandbox-profiles
   (nono/list (metadata (declared-by . collection)))
   (nono/list-derived
    (:derive nono/list (scope . task))
    (metadata (derived-by . collection)))))

;;; Durable module macros lower their named rows to fixed POO profile values.
(def durable-artifact-module-witness
  (artifact-module
    (profile macro-artifact :scope (session) :storage (file-system))))

(def durable-database-module-witness
  (database-module
    (profile macro-database :kind libsql :storage (file-system))))

;; : (-> [PooSandboxProfile] [Symbol])
(def (profile-names profiles)
  (map poo-flow-sandbox-profile-name profiles))

;; : TestSuite
(def module-macro-surface-test
  (test-suite "poo-flow public module macro surface"
    (poo-flow-test-case "loader identifier macro preserves the generated binding"
      (check-equal? load-profile-binding 'syntax-probe-binding))
    (poo-flow-test-case "profile extension appends bundles to a POO profile"
      (check-equal? (poo-flow-user-profile-name macro-extended-profile)
                    'macro-extended)
      (check-equal?
       (length (poo-flow-user-profile-module-bundles macro-extended-profile))
       (+ (length (poo-flow-user-profile-module-bundles
                   poo-flow-kernel-profile))
          (length macro-extra-module-bundles))))
    (poo-flow-test-case "field-row tail projection preserves fixed-first ordering"
      (check-equal?
       (poo-flow-product-field-rows/tail
        '((tail . value))
        (kind 'module)
        (name 'syntax-surface))
       '((kind . module) (name . syntax-surface) (tail . value))))
    (poo-flow-test-case "durable module macros expose POO-native named profiles"
      (check-equal?
       (poo-flow-artifact-profile?
        (.ref durable-artifact-module-witness 'macro-artifact))
       #t)
      (check-equal?
       (poo-flow-artifact-database-profile?
        (.ref durable-database-module-witness 'macro-database))
       #t))
    (poo-flow-test-case "backend profile macros construct and derive POO profiles"
      (check-equal? (poo-flow-sandbox-profile-backend-kind
                     cube-direct-profile)
                    'cube)
      (check-equal? (poo-flow-sandbox-profile-name cube-derived-profile)
                    'cube/derived)
      (check-equal? (poo-flow-sandbox-profile-backend-kind
                     docker-direct-profile)
                    'docker)
      (check-equal? (poo-flow-sandbox-profile-name docker-derived-profile)
                    'docker/derived)
      (check-equal? (poo-flow-sandbox-profile-backend-kind
                     nono-direct-profile)
                    'nono)
      (check-equal? (poo-flow-sandbox-profile-name nono-derived-profile)
                    'nono/derived))
    (poo-flow-test-case "backend profile collections preserve declaration order"
      (check-equal? (profile-names cube-profile-list)
                    '(cube/list cube/list-derived))
      (check-equal? (profile-names docker-profile-list)
                    '(docker/list docker/list-derived))
      (check-equal? (profile-names nono-profile-list)
                    '(nono/list nono/list-derived)))))
