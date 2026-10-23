;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .cc .o .ref)
        (only-in :clan/poo/mop TypeError?)
        (only-in :std/test check-equal? check-exception test-suite)
        :yuanxu/module-system/authoring/admission
        (only-in :yuanxu/poo-clos/interface
                 poo-clos-call
                 poo-clos-call-next-method
                 poo-clos-compose-method-bundle
                 poo-clos-compute-applicable-methods
                 poo-clos-generic-function
                 poo-clos-method
                 poo-clos-method-bundle
                 poo-clos-prototype-specializer
                 poo-clos-any-specializer)
        (only-in :yuanxu/module-system/observability/presentation
                 yuanxu-poo-slot-authoring-file-observations
                 yuanxu-poo-slot-authoring-diagnostics)
        (only-in :yuanxu/utilities/algorithms
                 yuanxu-directory-files-recursive)
        (only-in :agentic-ai-lab/modules/module-authoring/module-interface
                 yuanxu-module-interface
                 yuanxu-module-interface-authoring
                 yuanxu-module-interface-prototype)
        (only-in :yuanxu/module-system/source/collection make-yuanxu-module-source-collection make-yuanxu-contribution-module-source yuanxu-module-source-collection-role-entrypoints)
        (only-in :yuanxu/module-system/authoring/roles ModuleAuthoringExecutor. ModuleSourceRole. ObjectsSourceRole. yuanxu-default-module-authoring-profile)
        (only-in :agentic-ai-lab/modules/module-authoring/semantic-module agentic-ai-lab-user-root-module-authoring-profile))

(export module-authoring-contract-test)

(def test-module-interface
  (yuanxu-module-interface
   "test-module"
   (.o)
   '((owner . module-authoring-contract-test))))

(def user-root-module-interface
  (yuanxu-module-interface
   "user-root-config"
   (.o)
   '((owner . user))
   authoring: (agentic-ai-lab-user-root-module-authoring-profile)))

(def (first-diagnostic admission)
  (car (yuanxu-module-authoring-admission-diagnostics admission)))

(def (user-interface-source-role path)
  (cond
   ((equal? path "user-interface/config.ss")
    'user-config)
   ((string-suffix? "/config.ss" path) 'config)
   ((string-suffix? "/interface.ss" path) 'interface)
   ((string-suffix? "/types.ss" path) 'types)
   ((string-suffix? "/funs.ss" path) 'funs)
   (else 'objects)))

(def (user-interface-source-admission path)
  (call-with-input-file path
    (lambda (port)
      (yuanxu-module-authoring-admit-port
       (if (eq? (user-interface-source-role path) 'user-config)
         user-root-module-interface
         test-module-interface)
       (if (eq? (user-interface-source-role path) 'user-config)
         'config
         (user-interface-source-role path))
       port))))

;;; A vertical package refines native prototypes and contributes one CLOS
;;; method bundle.  It does not register a parallel role table or evaluator.
(def ClinicalAuthoringExecutor.
  (.o (:: @ ModuleAuthoringExecutor.)
      identity: 'module-authoring/clinical-executor))

(def ClinicalObjectsSourceRole.
  (.o (:: @ ObjectsSourceRole.)
      identity: 'clinical-objects))

(def ClinicalModuleInterface.
  (.o (:: @ yuanxu-module-interface-prototype)))

(def ClinicalAuthoringMethod
  (poo-clos-method
   'module-authoring/clinical
   (list (poo-clos-prototype-specializer ClinicalAuthoringExecutor.)
         (poo-clos-prototype-specializer ClinicalObjectsSourceRole.)
         (poo-clos-prototype-specializer ClinicalModuleInterface.)
         (poo-clos-any-specializer))
   (lambda (frame _executor _role _interface _datum)
     (.cc (poo-clos-call-next-method frame)
          'vertical-owner 'clinical))))

(def TestAuthoringCommonMethod
  (poo-clos-method
   'module-authoring/test-common
   (list (poo-clos-prototype-specializer ModuleAuthoringExecutor.)
         (poo-clos-prototype-specializer ModuleSourceRole.)
         (poo-clos-prototype-specializer yuanxu-module-interface-prototype)
         (poo-clos-any-specializer))
   (lambda (_frame _executor role interface _datum)
     (.o kind: 'agentic-ai-lab.module-authoring.admission.v1
         module: (.ref interface 'id)
         role: (.ref role 'identity)
         accepted?: #t
         diagnostics: '()
         runtime-executed?: #f))))

(def TestAuthoringCoreMethods
  (poo-clos-method-bundle
   'module-authoring/test-core
   ModuleAuthoringAdmissionProtocol
   (list TestAuthoringCommonMethod)))

(def ClinicalAuthoringMethods
  (poo-clos-method-bundle
   'module-authoring/clinical
   ModuleAuthoringAdmissionProtocol
   (list ClinicalAuthoringMethod)))

(def module-authoring-contract-test
  (test-suite
   "POO Module Interface role authoring Contract"

   (yuanxu-test-case "native Interface, executor, and role axes are CLOS-applicable"
     (let* ((authoring (yuanxu-module-interface-authoring
                        test-module-interface))
            (arguments
             (list (.ref authoring 'executor)
                   (yuanxu-module-authoring-role
                    test-module-interface 'objects)
                   test-module-interface
                   '(.o))))
       (check-equal?
        (length
         (apply poo-clos-compute-applicable-methods
                ModuleAuthoringAdmissionGeneric arguments))
        1)))

   (yuanxu-test-case "a vertical method bundle refines all three native POO axes"
     (let* ((authoring
             (.cc (yuanxu-default-module-authoring-profile)
                  'executor (.o (:: @ ClinicalAuthoringExecutor.))
                  'objects (.o (:: @ ClinicalObjectsSourceRole.))))
            (interface
             (.o (:: @ ClinicalModuleInterface.)
                 id: "clinical-module"
                 schemas: (.o)
                 authoring: authoring
                 metadata: '()))
            (generic
             (poo-clos-generic-function
              'module-authoring-admit/clinical 4
              protocol: ModuleAuthoringAdmissionProtocol)))
       (poo-clos-compose-method-bundle generic TestAuthoringCoreMethods)
       (poo-clos-compose-method-bundle generic ClinicalAuthoringMethods)
       (let (admission
             (poo-clos-call
              generic
              (.ref authoring 'executor)
              (.ref authoring 'objects)
              interface
              '(.def ClinicalCase (events =>.+ (.o review: required)))))
         (check-equal?
          (yuanxu-module-authoring-admission-accepted? admission) #t)
         (check-equal? (.ref admission 'vertical-owner) 'clinical))))

   (yuanxu-test-case "Interface rejects an invalid authoring Profile immediately"
     (check-exception
      (yuanxu-module-interface
       "invalid-authoring" (.o) '() authoring: (.o))
      TypeError?))

   (yuanxu-test-case "admits native noun slots and leaves algorithms open"
     (let (admission
           (yuanxu-module-authoring-admit-datum
            test-module-interface
            'objects
            '(.def (ReviewedCase @ PrescriptionCase)
               (events =>.+ (.o review: ClinicalReviewEvent)))))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission) #t)
       (check-equal?
        (yuanxu-module-authoring-admission-diagnostics admission) '())))

   (yuanxu-test-case "admits named POO Query values and provider projections"
     (let (admission
           (yuanxu-module-authoring-admit-datum
            test-module-interface
            'objects
            '(.def (ClinicalQueries @ BaseQueries)
               (queries =>.+
                 (.o impact: PrescriptionImpactQuery))
               (gql-source GqlPrescriptionImpactProjection))))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission) #t)
       (check-equal?
        (yuanxu-module-authoring-admission-diagnostics admission) '())))

   (yuanxu-test-case "rejects a raw Query language hidden in a POO slot"
     (let* ((admission
             (yuanxu-module-authoring-admit-datum
              test-module-interface
              'objects
              '(.def BrokenQuery
                 (impact-query "MATCH (prescription)-[:AFFECTS]->(patient)"))))
            (diagnostic (first-diagnostic admission)))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission) #f)
       (check-equal? (.ref diagnostic 'code)
                     'poo-query-must-be-native-object)
       (check-equal? (.ref diagnostic 'subject) 'impact-query)
       (check-equal? (.ref diagnostic 'rule) 'single-poo-semantic-model)
       (check-equal? (.ref diagnostic 'recommendation)
                     'bind-named-poo-query-or-provider-projection)))

   (yuanxu-test-case "rejects an anonymous Query evaluator but leaves funs open"
     (let* ((admission
             (yuanxu-module-authoring-admit-datum
              test-module-interface
              'objects
              '(.def BrokenQuery
                 (query (lambda (elements) (filter selected? elements))))))
            (diagnostic (first-diagnostic admission)))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission) #f)
       (check-equal? (.ref diagnostic 'code)
                     'poo-query-must-be-native-object)
       (check-equal? (.ref diagnostic 'subject) 'query))
     (check-equal?
      (yuanxu-module-authoring-admission-accepted?
       (yuanxu-module-authoring-admit-datum
        test-module-interface
        'funs
        '(def (select-elements elements)
           (filter selected? elements))))
      #t))

   (yuanxu-test-case "rejects a command-shaped domain slot with an actionable repair"
     (let* ((admission
             (yuanxu-module-authoring-admit-datum
              test-module-interface
              'objects
              '(.def BrokenCase
                 (.add-event (.o prescription: PrescriptionEvent)))))
            (diagnostic (first-diagnostic admission)))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission) #f)
       (check-equal? (.ref diagnostic 'code)
                     'poo-domain-slot-must-be-noun)
       (check-equal? (.ref diagnostic 'role) 'objects)
       (check-equal? (.ref diagnostic 'subject) '.add-event)
       (check-equal? (.ref diagnostic 'repair-operators)
                     '(? => =>.+ override))
       (check-equal? (.ref diagnostic 'freedom) 'open-native-poo)))

   (yuanxu-test-case "config role adds its own composition-only method"
     (let* ((admission
             (yuanxu-module-authoring-admit-datum
              test-module-interface
              'config
              '(stage production)))
            (diagnostic (first-diagnostic admission)))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission) #f)
       (check-equal? (.ref diagnostic 'code)
                     'poo-config-must-compose-maintained-values)
       (check-equal? (.ref diagnostic 'subject) 'stage)
       (check-equal? (.ref diagnostic 'freedom) 'composition-only)))

   (yuanxu-test-case "user-root refinement reports an agent-repairable nested object"
     (let* ((admission
             (yuanxu-module-authoring-admit-datum
              user-root-module-interface
              'config
              '(user-composition broken
                 (compose profiles
                   (.o production: maintained-profile)))))
            (diagnostic (first-diagnostic admission)))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission) #f)
       (check-equal? (.ref diagnostic 'role) 'user-config)
       (check-equal? (.ref diagnostic 'subject) '.o)
       (check-equal? (.ref diagnostic 'rule)
                     'root-config-composition-only)
       (check-equal? (.ref diagnostic 'recommendation)
                     'move-responsibility-to-selected-profile-owner)
       (check-equal? (.ref diagnostic 'repair-operators)
                     '(? => =>.+ override))
       (check-equal? (.ref diagnostic 'freedom)
                     'maintained-value-composition-only)))

   (yuanxu-test-case "user-root rejects raw MOP imports with an owned repair"
     (let* ((admission
             (yuanxu-module-authoring-admit-datum
              user-root-module-interface
              'config
              '(import (only-in :clan/poo/mop validate))))
            (diagnostic (first-diagnostic admission)))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission) #f)
       (check-equal? (.ref diagnostic 'code)
                     'poo-user-surface-forbids-meta-import)
       (check-equal? (.ref diagnostic 'subject) ':clan/poo/mop)
       (check-equal? (.ref diagnostic 'recommendation)
                     'move-meta-extension-to-maintained-module-owner)))

   (yuanxu-test-case "user-root rejects direct CLOS declarations"
     (let* ((admission
             (yuanxu-module-authoring-admit-datum
              user-root-module-interface
              'config
              '(def UserGeneric
                 (poo-clos-generic-function 'user-generic 1))))
            (diagnostic (first-diagnostic admission)))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission) #f)
       (check-equal? (.ref diagnostic 'code)
                     'poo-user-surface-forbids-direct-clos)
       (check-equal? (.ref diagnostic 'subject)
                     'poo-clos-generic-function)))

   (yuanxu-test-case "user-root rejects raw self/super behavior hooks"
     (let* ((admission
             (yuanxu-module-authoring-admit-datum
              user-root-module-interface
              'config
              '(user-composition broken
                 (compose profiles
                   (lambda (self super) (super self))))))
            (diagnostic (first-diagnostic admission)))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission) #f)
       (check-equal? (.ref diagnostic 'code)
                     'poo-user-surface-forbids-raw-behavior-hook)
       (check-equal? (.ref diagnostic 'subject) 'lambda)
       (check-equal? (.ref diagnostic 'recommendation)
                     'move-behavior-to-named-maintained-operation)))

   (yuanxu-test-case "maintained roles retain advanced extension freedom"
     (check-equal?
      (yuanxu-module-authoring-admission-accepted?
       (yuanxu-module-authoring-admit-datum
        test-module-interface
        'objects
        '(def MaintainedGeneric
           (poo-clos-generic-function 'maintained-generic 1))))
      #t))

   (yuanxu-test-case "maintained user-interface Scheme sources satisfy their role Contracts"
     (let (failures '())
       (for-each
        (lambda (path)
          ;; init.ss is a distinct yuanxu! declaration surface qualified by
          ;; user-interface-root-config-test; Module config roles do not own it.
          (when (and (string-suffix? ".ss" path)
                     (not (equal? path "user-interface/init.ss")))
            (let (admission (user-interface-source-admission path))
              (unless (yuanxu-module-authoring-admission-accepted? admission)
                (set! failures
                      (cons (cons path
                                  (yuanxu-module-authoring-admission-diagnostics
                                   admission))
                            failures))))))
        (yuanxu-directory-files-recursive "user-interface"))
       (check-equal?
        (map (lambda (failure)
               (cons (car failure)
                     (map (lambda (diagnostic) (.ref diagnostic 'code))
                          (cdr failure))))
             (reverse failures))
        '())))

   (yuanxu-test-case "a lazy POO slot cannot refer to its own binding"
     (let (admission
           (yuanxu-module-authoring-admit-datum
            test-module-interface 'objects
            '(def BrokenProfile (.o identity: identity))))
       (check-equal?
        (yuanxu-module-authoring-admission-accepted? admission)
        #f)
       (check-equal?
        (map (lambda (diagnostic) (.ref diagnostic 'code))
             (yuanxu-module-authoring-admission-diagnostics admission))
        '(poo-slot-initializer-shadows-slot))))

   (yuanxu-test-case ".cc overrides evaluate their values before constructing slots"
     (let ((base (.o identity: 'original))
           (identity 'lexical))
       (check-equal? (.ref (.cc base identity: identity) 'identity)
                     'lexical)
       (check-equal?
        (yuanxu-module-authoring-admission-accepted?
         (yuanxu-module-authoring-admit-datum
          test-module-interface 'objects
          '(def RefinedProfile (.cc base identity: identity))))
        #t)))

   (yuanxu-test-case "unknown roles fail at the Interface Profile boundary"
     (check-equal?
      (with-catch
       (lambda (_failure) #t)
       (lambda ()
         (yuanxu-module-authoring-admit-datum
          test-module-interface 'unknown '(.o))
         #f))
      #t))

   (yuanxu-test-case "loader blocks a command-slot module before exposing its Interface"
     (let (collection
           (make-yuanxu-module-source-collection
            'invalid-authoring-fixture 'test
            "t/fixtures/module-authoring-invalid" "modules"))
       (check-exception
        (yuanxu-module-source-collection-role-entrypoints
         collection 'interface)
        true)))

   (yuanxu-test-case "contribution and Lambda sources inherit the same authoring Contract"
     (let (collection
           (make-yuanxu-contribution-module-source
            'invalid-lambda-fixture "t/fixtures/module-authoring-invalid"))
       (check-exception
        (yuanxu-module-source-collection-role-entrypoints
         collection 'interface)
        true)))

   (yuanxu-test-case "the authoring Contract passes its own lazy-slot observation"
     (check-equal?
      (yuanxu-poo-slot-authoring-diagnostics
       (yuanxu-poo-slot-authoring-file-observations
        'module-authoring-contract
        "yuanxu/module-system/authoring/admission.ss"))
      '()))

   (yuanxu-test-case "Core slot presentation blocks lazy self-reference regression"
     (check-equal?
      (yuanxu-poo-slot-authoring-diagnostics
       (yuanxu-poo-slot-authoring-file-observations
        'core-slot-presentation
        "yuanxu/observability/slot-presentation.ss"))
      '()))

   (yuanxu-test-case "profile composition conflict receipts have no lazy self-reference"
     (check-equal?
      (yuanxu-poo-slot-authoring-diagnostics
       (yuanxu-poo-slot-authoring-file-observations
        'profile-composition
        "yuanxu/profile-composition/profile-bundle.ss"))
      '()))))
