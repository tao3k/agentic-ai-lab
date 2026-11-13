;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite check-equal? check-exception)
        (only-in :clan/poo/object .o .ref)
        (only-in :clan/poo/mop validate TypeError? define-type Type. .new)
        (only-in :clan/poo/type Record)
        (only-in :tao3k/yuanxu/modules/funflow/scenario Scenario)
        (only-in :tao3k/yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        (only-in :tao3k/yuanxu/module-system/authoring/roles yuanxu-semantic-module)
        (only-in :tao3k/yuanxu/profile-composition/profile-bundle
                 profiles compose yuanxu-profile-export
                 yuanxu-module-profiles)
        :tao3k/yuanxu/profile-composition/selection-syntax
        )

(export profile-binding-syntax-test)

(def bounded-profile
  (.o identity: 'bounded name: 'bounded runtime-executed?: #f))

(def SyntaxModule
  (yuanxu-semantic-module
   (yuanxu-semantic-identity 'test 'syntax-module)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'bounded bounded-profile))))

(def syntax-root
  (.new Scenario name: 'syntax-root
        config: (compose profiles
    (use-module SyntaxModule bounded))))

(def default-selection
  (use-module SyntaxModule bounded))

(def aliased-selection
  (use-module SyntaxModule as secondary bounded))

(def composition-demands 0)
(def demand-root
  (.new Scenario name: 'demand-root
        config: (begin
    (set! composition-demands (+ composition-demands 1))
    (compose profiles bounded-profile))))

(def profile-binding-syntax-test
  (test-suite
   "thin Profile composition bindings"
   (yuanxu-test-case "registration leaves composition cold and first field demand is shared"
     (check-equal? composition-demands 0)
     (check-equal? (.ref demand-root 'name) 'demand-root)
     (check-equal? composition-demands 0)
     (check-equal? (.ref demand-root 'profiles) (list bounded-profile))
     (check-equal? (.ref demand-root 'profiles) (list bounded-profile))
     (check-equal? composition-demands 1))
   (yuanxu-test-case "cached parent fields do not replace a child's final bundle"
     (def child-profile (.o identity: 'child name: 'child))
     (def child (.o (:: @ demand-root)
                   config: (compose profiles child-profile)))
     (check-equal? (.ref child 'profiles) (list child-profile))
     (check-equal? (.ref demand-root 'profiles) (list bounded-profile))
     (def malformed (.o (:: @ demand-root) config: (.o profiles: '())))
     (check-exception (validate Scenario malformed) TypeError?))
   (yuanxu-test-case "ordinary definition creates the typed root binding"
     (check-equal? (.ref syntax-root 'name) 'syntax-root)
     (check-equal? (.ref syntax-root 'profiles) (list bounded-profile)))
   (yuanxu-test-case "derived Record obligations survive an already prepared parent prototype"
     (def parent-proto (.ref Scenario 'proto))
     (def checks 0)
     (define-type Denied
       (.o (:: @ Type.) .element?: (lambda (_) (set! checks (+ checks 1)) #f)))
     (def Derived (Record [Scenario] marker: [Denied]))
     (def child (.new Derived name: 'derived config: (.ref demand-root 'config)
                     marker: 'provided))
     (check-exception (.ref child 'execution-plan) TypeError?)
     (check-equal? (> checks 0) #t))
   (yuanxu-test-case "default Module instance is the definition identity"
     (let (proof (car (.ref default-selection 'selection-proofs)))
       (check-equal? (eq? (.ref proof 'module-definition)
                          (.ref proof 'module-instance))
                     #t)))
   (yuanxu-test-case "explicit alias is a distinct instance identity"
     (let (proof (car (.ref aliased-selection 'selection-proofs)))
       (check-equal? (.ref proof 'module-instance) 'secondary)))))
