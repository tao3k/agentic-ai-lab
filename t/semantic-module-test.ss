;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite check-equal? check-exception)
        (only-in :clan/poo/object .o .cc .ref .all-slots)
        (only-in :clan/poo/mop element? validate TypeError?)
        (only-in :yuanxu/module-system/schema/relations
                 yuanxu-semantic-identity yuanxu-empty-imports
                 SemanticImports. ModuleImportsContract)
        :yuanxu/module-system/authoring/roles
        (only-in :agentic-ai-lab/modules/module-authoring/semantic-module UserConfigSourceRole. agentic-ai-lab-user-root-module-authoring-profile))
(export semantic-module-test)
(def semantic-module-test
  (test-suite "role-constrained native Module"
    (yuanxu-test-case "construction has five semantic responsibilities and fresh profiles"
      (let* ((identity (yuanxu-semantic-identity 'test 'module))
             (a (yuanxu-semantic-module identity))
             (b (yuanxu-semantic-module identity)))
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
    (yuanxu-test-case "construction does not force import targets or contributions"
      (let* ((imports (yuanxu-empty-imports))
             (lazy-imports (.o (:: @ SemanticImports.)
                              (contributions (error "construction forced imports"))))
             (module (yuanxu-semantic-module
                      (yuanxu-semantic-identity 'test 'lazy) imports: lazy-imports)))
        (check-equal? (element? SemanticModuleContract module) #t)
        (check-equal? (element? ModuleImportsContract imports) #t)))))
