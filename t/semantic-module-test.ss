;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite check-equal? check-exception)
        (only-in :clan/poo/object .o .cc .ref .all-slots)
        (only-in :clan/poo/mop element? validate TypeError?)
        (only-in :core/module-system/schema/relations
                 poo-flow-semantic-identity poo-flow-empty-imports
                 SemanticImports. ModuleImportsContract)
        :core/module-system/authoring/roles
        (only-in :poo-flow/modules/module-authoring/semantic-module UserConfigSourceRole. poo-flow-user-root-module-authoring-profile))
(export semantic-module-test)
(def semantic-module-test
  (test-suite "role-constrained native Module"
    (poo-flow-test-case "construction has five semantic responsibilities and fresh profiles"
      (let* ((identity (poo-flow-semantic-identity 'test 'module))
             (a (poo-flow-semantic-module identity))
             (b (poo-flow-semantic-module identity)))
        (check-equal? (element? SemanticModuleContract a) #t)
        (check-equal? (length (.all-slots a)) 5)
        (check-equal? (eq? (.ref a 'identity) identity) #t)
        (check-equal? (eq? (.ref a 'imports) (.ref b 'imports)) #f)
        (check-equal? (eq? (.ref a 'profiles) (.ref b 'profiles)) #f)
        (check-equal? (eq? (.ref a 'authoring) (.ref b 'authoring)) #f)
        (check-equal? (.ref (.ref (.ref a 'authoring) 'objects) 'freedom)
                      'open-native-poo)
        (check-equal? (element? ModuleImportsContract (.ref a 'profiles)) #f)
        (check-equal? (element? SemanticModuleContract
                              (.o identity: identity imports: (.ref a 'imports)
                                  capabilities: (.ref a 'capabilities) profiles: (.ref a 'profiles))) #f)
        (check-exception (validate SemanticModuleContract (.cc a 'identity 'raw-symbol)) TypeError?)
        (check-exception (validate SemanticModuleContract (.cc a 'imports '())) TypeError?)
        (check-exception (validate SemanticModuleContract (.cc a 'authoring '())) TypeError?)))
    (poo-flow-test-case "construction does not force import targets or contributions"
      (let* ((imports (poo-flow-empty-imports))
             (lazy-imports (.o (:: @ SemanticImports.)
                              (contributions (error "construction forced imports"))))
             (module (poo-flow-semantic-module
                      (poo-flow-semantic-identity 'test 'lazy) imports: lazy-imports)))
        (check-equal? (element? SemanticModuleContract module) #t)
        (check-equal? (element? ModuleImportsContract imports) #t)))))
