;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite check-equal?)
        (only-in :clan/poo/object .o .ref)
        (only-in :yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        (only-in :yuanxu/module-system/authoring/roles yuanxu-semantic-module)
        (only-in :yuanxu/profile-composition/profile-bundle
                 profiles compose yuanxu-profile-export
                 yuanxu-module-profiles)
        :yuanxu/profile-composition/selection-syntax
        :agentic-ai-lab/modules/workflow/scenario/composition-syntax)

(export profile-binding-syntax-test)

(def bounded-profile
  (.o identity: 'bounded name: 'bounded runtime-executed?: #f))

(def SyntaxModule
  (yuanxu-semantic-module
   (yuanxu-semantic-identity 'test 'syntax-module)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'bounded bounded-profile))))

(user-composition syntax-root
  (compose profiles
    (use-module SyntaxModule bounded)))

(def default-selection
  (use-module SyntaxModule bounded))

(def aliased-selection
  (use-module SyntaxModule as secondary bounded))

(def profile-binding-syntax-test
  (test-suite
   "thin Profile composition bindings"
   (yuanxu-test-case "user-composition creates the only root binding"
     (check-equal? (.ref syntax-root 'name) 'syntax-root)
     (check-equal? (.ref syntax-root 'profiles) (list bounded-profile)))
   (yuanxu-test-case "default Module instance is the definition identity"
     (let (proof (car (.ref default-selection 'selection-proofs)))
       (check-equal? (eq? (.ref proof 'module-definition)
                          (.ref proof 'module-instance))
                     #t)))
   (yuanxu-test-case "explicit alias is a distinct instance identity"
     (let (proof (car (.ref aliased-selection 'selection-proofs)))
       (check-equal? (.ref proof 'module-instance) 'secondary)))))
