;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: executable contracts for the public module/profile macro surface.
;;; Invariant: syntax lowers to ordinary POO objects and pure projection values.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/init-syntax
                 agentic-ai-lab-profile-extend)
        (only-in :agentic-ai-lab/modules/module-authoring/fragment-syntax
                 agentic-ai-lab-load-profile-module-binding)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-bundle)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/profile-config
                 yuanxu-user-profile-module-bundles
                 yuanxu-user-profile-name)
        (only-in :agentic-ai-lab/modules/workflow/profiles/kernel/interface
                 agentic-ai-lab-kernel-profile)
        (only-in :yuanxu/utilities/final-projection-syntax
                 yuanxu-product-field-rows/tail)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/artifact-policy
                 artifact-module
                 database-module
                 agentic-ai-lab-artifact-profile?
                 agentic-ai-lab-artifact-database-profile?)
        :agentic-ai-lab/modules/cubeSandbox/config
        :agentic-ai-lab/modules/docker-sandbox/config
        :agentic-ai-lab/modules/nono-sandbox/config
        (only-in :agentic-ai-lab/modules/sandbox-core/profile
                 agentic-ai-lab-sandbox-profile-backend-kind
                 agentic-ai-lab-sandbox-profile-name))

(export module-macro-surface-test)

;;; The loader identifier macro preserves the call-site binding while using
;;; the canonical fallback module name outside a custom/<name> source tree.
(def agentic-ai-lab-custom-module-syntax-probe-module 'syntax-probe-binding)

(def load-profile-binding
  (agentic-ai-lab-load-profile-module-binding syntax-probe))

;;; Profile extension remains a POO-native declaration and appends complete
;;; module bundles without flattening individual module selection rows.
(def macro-extra-module-bundles
  (list
   (yuanxu-user-module-bundle
    (custom macro-surface "/tmp/agentic-ai-lab-macro-surface" +contract))))

(agentic-ai-lab-profile-extend macro-extended-profile
                         macro-extended
                         agentic-ai-lab-kernel-profile
  (bundles macro-extra-module-bundles))

;;; Each backend macro is called directly so its public shorthand is covered,
;;; while the collection forms exercise the shared ordered build recursion.
(def cube-direct-profile
  (agentic-ai-lab-cubeSandbox-profile cube/direct
    (metadata (declared-by . macro-surface-test))))

(def cube-derived-profile
  (agentic-ai-lab-cubeSandbox-profile-derive
   cube-direct-profile
   cube/derived
   ((scope . session))
   (metadata (derived-by . macro-surface-test))))

(def cube-profile-list
  (agentic-ai-lab-cubeSandbox-profiles
   (cube/list (metadata (declared-by . collection)))
   (cube/list-derived
    (:derive cube/list (scope . task))
    (metadata (derived-by . collection)))))

(def docker-direct-profile
  (agentic-ai-lab-docker-sandbox-profile docker/direct
    (metadata (declared-by . macro-surface-test))))

(def docker-derived-profile
  (agentic-ai-lab-docker-sandbox-profile-derive
   docker-direct-profile
   docker/derived
   ((scope . session))
   (metadata (derived-by . macro-surface-test))))

(def docker-profile-list
  (agentic-ai-lab-docker-sandbox-profiles
   (docker/list (metadata (declared-by . collection)))
   (docker/list-derived
    (:derive docker/list (scope . task))
    (metadata (derived-by . collection)))))

(def nono-direct-profile
  (agentic-ai-lab-nono-sandbox-profile nono/direct
    (metadata (declared-by . macro-surface-test))))

(def nono-derived-profile
  (agentic-ai-lab-nono-sandbox-profile-derive
   nono-direct-profile
   nono/derived
   ((scope . session))
   (metadata (derived-by . macro-surface-test))))

(def nono-profile-list
  (agentic-ai-lab-nono-sandbox-profiles
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
  (map agentic-ai-lab-sandbox-profile-name profiles))

;; : TestSuite
(def module-macro-surface-test
  (test-suite "agentic-ai-lab public module macro surface"
    (yuanxu-test-case "loader identifier macro preserves the generated binding"
      (check-equal? load-profile-binding 'syntax-probe-binding))
    (yuanxu-test-case "profile extension appends bundles to a POO profile"
      (check-equal? (yuanxu-user-profile-name macro-extended-profile)
                    'macro-extended)
      (check-equal?
       (length (yuanxu-user-profile-module-bundles macro-extended-profile))
       (+ (length (yuanxu-user-profile-module-bundles
                   agentic-ai-lab-kernel-profile))
          (length macro-extra-module-bundles))))
    (yuanxu-test-case "field-row tail projection preserves fixed-first ordering"
      (check-equal?
       (yuanxu-product-field-rows/tail
        '((tail . value))
        (kind 'module)
        (name 'syntax-surface))
       '((kind . module) (name . syntax-surface) (tail . value))))
    (yuanxu-test-case "durable module macros expose POO-native named profiles"
      (check-equal?
       (agentic-ai-lab-artifact-profile?
        (.ref durable-artifact-module-witness 'macro-artifact))
       #t)
      (check-equal?
       (agentic-ai-lab-artifact-database-profile?
        (.ref durable-database-module-witness 'macro-database))
       #t))
    (yuanxu-test-case "backend profile macros construct and derive POO profiles"
      (check-equal? (agentic-ai-lab-sandbox-profile-backend-kind
                     cube-direct-profile)
                    'cube)
      (check-equal? (agentic-ai-lab-sandbox-profile-name cube-derived-profile)
                    'cube/derived)
      (check-equal? (agentic-ai-lab-sandbox-profile-backend-kind
                     docker-direct-profile)
                    'docker)
      (check-equal? (agentic-ai-lab-sandbox-profile-name docker-derived-profile)
                    'docker/derived)
      (check-equal? (agentic-ai-lab-sandbox-profile-backend-kind
                     nono-direct-profile)
                    'nono)
      (check-equal? (agentic-ai-lab-sandbox-profile-name nono-derived-profile)
                    'nono/derived))
    (yuanxu-test-case "backend profile collections preserve declaration order"
      (check-equal? (profile-names cube-profile-list)
                    '(cube/list cube/list-derived))
      (check-equal? (profile-names docker-profile-list)
                    '(docker/list docker/list-derived))
      (check-equal? (profile-names nono-profile-list)
                    '(nono/list nono/list-derived)))))
