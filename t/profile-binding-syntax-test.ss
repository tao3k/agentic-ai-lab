;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite check-equal?)
        (only-in :clan/poo/object .o .ref)
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        (only-in :core/module-system/authoring/roles poo-flow-semantic-module)
        (only-in :core/profile-composition/profile-bundle
                 profiles compose poo-flow-profile-export
                 poo-flow-module-profiles)
        :core/profile-composition/selection-syntax
        :poo-flow/modules/workflow/scenario/composition-syntax)

(export profile-binding-syntax-test)

(def bounded-profile
  (.o identity: 'bounded name: 'bounded runtime-executed?: #f))

(def SyntaxModule
  (poo-flow-semantic-module
   (poo-flow-semantic-identity 'test 'syntax-module)
   profiles:
   (poo-flow-module-profiles
    (poo-flow-profile-export 'bounded bounded-profile))))

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
   (poo-flow-test-case "user-composition creates the only root binding"
     (check-equal? (.ref syntax-root 'name) 'syntax-root)
     (check-equal? (.ref syntax-root 'profiles) (list bounded-profile)))
   (poo-flow-test-case "default Module instance is the definition identity"
     (let (proof (car (.ref default-selection 'selection-proofs)))
       (check-equal? (eq? (.ref proof 'module-definition)
                          (.ref proof 'module-instance))
                     #t)))
   (poo-flow-test-case "explicit alias is a distinct instance identity"
     (let (proof (car (.ref aliased-selection 'selection-proofs)))
       (check-equal? (.ref proof 'module-instance) 'secondary)))))
