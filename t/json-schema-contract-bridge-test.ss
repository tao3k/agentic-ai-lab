;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: JSON Schema bridge emits executable Agentic AI Lab slot contracts.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/mop element?)
        (only-in :yuanxu/module-system/schema/slot-contracts
                 yuanxu-contract-slot-name
                 yuanxu-contract-slot-predicate-key
                 yuanxu-contract-slot-report-kind
                 yuanxu-contract-slot-type
                 yuanxu-object-contract-slots)
        (only-in :yuanxu/modules/json-schema/json-schema-receipt
                 yuanxu-json-schema->contract-artifact
                 yuanxu-json-schema-contract-artifact-object-contract
                 yuanxu-json-schema-contract-artifact->alist)
        (only-in :yuanxu/modules/json-schema/json-schema-validate
                 yuanxu-json-schema-contract-artifact-validate
                 yuanxu-json-schema-object-contract-validation->alist))

(export json-schema-contract-bridge-test)

;; json-schema-bridge-test-ref
;;   : (-> Alist Symbol Object)
;;   | result: row value for KEY
;;   | doc m%
;;       Read projected receipt rows in focused JSON Schema bridge tests.
;;       # Examples
;;       ```scheme
;;       (json-schema-bridge-test-ref '((valid? . #t)) 'valid?)
;;       ;; => #t
;;       ```
;;     %
(def (json-schema-bridge-test-ref rows key)
  (cdr (assoc key rows)))

;; json-schema-bridge-test-slot
;;   : (-> YuanxuObjectTypeContract Symbol YuanxuSlotContract)
;;   | result: generated slot contract whose slot matches SLOT-NAME
;;   | doc m%
;;       Find one generated slot contract by slot name so assertions exercise
;;       the public contract record instead of internal normalized nodes.
;;       # Examples
;;       ```scheme
;;       (json-schema-bridge-test-slot object-contract 'tags)
;;       ;; => slot contract
;;       ```
;;     %
(def (json-schema-bridge-test-slot object-contract slot-name)
  (let (slot (find (lambda (candidate)
                     (eq? (yuanxu-contract-slot-name candidate)
                          slot-name))
                   (yuanxu-object-contract-slots object-contract)))
    (if slot
      slot
      (error "missing generated JSON Schema slot" slot-name))))

(def (json-schema-bridge-test-slot-predicate slot-contract)
  (lambda (value)
    (element? (yuanxu-contract-slot-type slot-contract) value)))

;; json-schema-bridge-test-schema
;;   : JsonLikeSchema
;;   | doc m%
;;       Fixture covering the first useful JSON Schema contract bridge surface:
;;       object fields, homogeneous array items, local references, nullable
;;       anyOf, oneOf, and scalar/array constraints.
;;     %
(def json-schema-bridge-test-schema
  '((type . "object")
    (required . ("tags" "choice"))
    (properties
     . ((tags . ((type . "array")
                 (minItems . 1)
                 (maxItems . 2)
                 (items . (($ref . "#/definitions/Tag")))))
        (name . ((type . "string")
                 (minLength . 3)
                 (maxLength . 8)))
        (label . (($ref . "#/$defs/Label")))
        (bucket . ((type . "object")
                   (minProperties . 1)
                   (maxProperties . 2)))
        (score . ((type . "number")
                  (minimum . 0)
                  (exclusiveMaximum . 10)))
        (choice . ((oneOf . (((type . "string"))
                             ((type . "integer"))))))
        (numeric . ((oneOf . (((type . "number"))
                              ((type . "integer"))))))
        (maybe . ((anyOf . (((type . "null"))
                            ((type . "string"))))))))
    (definitions
     . ((Tag . ((type . "string")))))
    ($defs
     . ((Label . ((type . "string")
                  (pattern . "^ci-[a-z]+$")))))))

;; json-schema-bridge-invalid-constraint-schema
;;   : JsonLikeSchema
;;   | doc m%
;;       Fixture proving supported constraint keywords still validate their
;;       value shape before entering executable contract metadata.
;;     %
(def json-schema-bridge-invalid-constraint-schema
  '((type . "object")
    (properties
     . ((name . ((type . "string")
                 (minLength . "bad-bound")))))))

;; json-schema-bridge-recursive-map-schema
;;   : JsonLikeSchema
;;   | doc m%
;;       User-stage fixture proving recursive map-value contracts are generic:
;;       `stages.<stage_id>.tasks.<task_id>` is not a GitHub jobs special case.
;;     %
(def json-schema-bridge-task-config-schema
  '((type . "object")
    (additionalProperties . #t)))

(def json-schema-bridge-task-schema
  `((type . "object")
    (required . ("command"))
    (properties
     . ((command . ((type . "string")
                    (minLength . 1)))
        (config . ,json-schema-bridge-task-config-schema)))
    (additionalProperties . #f)))

(def json-schema-bridge-tasks-map-schema
  `((type . "object")
    (minProperties . 1)
    (patternProperties
     . (("^[a-z][a-z0-9_-]*$" . ,json-schema-bridge-task-schema)))
    (additionalProperties . #f)))

(def json-schema-bridge-stage-schema
  `((type . "object")
    (required . ("tasks"))
    (properties
     . ((tasks . ,json-schema-bridge-tasks-map-schema)))
    (additionalProperties . #f)))

(def json-schema-bridge-recursive-map-schema
  `((type . "object")
    (required . ("stages"))
    (properties
     . ((stages
         . ((type . "object")
            (minProperties . 1)
            (patternProperties
             . (("^stage-[a-z]+$" . ,json-schema-bridge-stage-schema)))
            (additionalProperties . #f)))))))

;; : Alist
(def json-schema-bridge-recursive-map-valid-value
  '((stages
     . ((stage-build
         . ((tasks
             . ((compile
                 . ((command . "gxc")
                    (config . ((threads . 4)
                               (cache . #t)))))))))))))

;; : Alist
(def json-schema-bridge-recursive-map-missing-command
  '((stages
     . ((stage-build
         . ((tasks
             . ((compile
                 . ((config . ((threads . 4)))))))))))))

;; : Alist
(def json-schema-bridge-recursive-map-invalid-stage-key
  '((stages
     . ((build
         . ((tasks
             . ((compile
                 . ((command . "gxc")))))))))))

;; json-schema-bridge-additional-recursive-map-schema
;;   : JsonLikeSchema
;;   | doc m%
;;       User-profile fixture proving recursive map-value contracts also work
;;       for `additionalProperties`, not just named slots or pattern keys.
;;     %
(def json-schema-bridge-limit-schema
  '((type . "object")
    (required . ("value"))
    (properties
     . ((value . ((type . "integer")
                  (minimum . 1)))))
    (additionalProperties . #f)))

(def json-schema-bridge-limit-map-schema
  `((type . "object")
    (minProperties . 1)
    (additionalProperties . ,json-schema-bridge-limit-schema)))

(def json-schema-bridge-profile-schema
  `((type . "object")
    (required . ("limits"))
    (properties
     . ((limits . ,json-schema-bridge-limit-map-schema)))
    (additionalProperties . #f)))

(def json-schema-bridge-additional-recursive-map-schema
  `((type . "object")
    (required . ("profiles"))
    (properties
     . ((profiles
         . ((type . "object")
            (minProperties . 1)
            (additionalProperties . ,json-schema-bridge-profile-schema)))))
    (additionalProperties . #f)))

;; : Alist
(def json-schema-bridge-additional-recursive-map-valid-value
  '((profiles
     . ((default
         . ((limits
             . ((cpu . ((value . 2)))
                (memory . ((value . 4096)))))))))))

;; : Alist
(def json-schema-bridge-additional-recursive-map-missing-value
  '((profiles
     . ((default
         . ((limits
             . ((cpu . ((unit . "core")))))))))))

;; : TestSuite
(def json-schema-contract-bridge-test
  (test-suite "json schema contract bridge"
    (yuanxu-test-case "emits executable slot predicates for items and oneOf"
      (let* ((artifact
              (yuanxu-json-schema->contract-artifact
               json-schema-bridge-test-schema
               '((source-ref . json-schema-contract-bridge-test)
                 (owner . contract)
                 (object-kind . AgenticAILabJsonSchemaBridgeTest)
                 (object-key . json-schema/bridge-test))))
             (receipt
              (yuanxu-json-schema-contract-artifact->alist artifact))
             (object-contract
              (yuanxu-json-schema-contract-artifact-object-contract artifact))
             (tags-slot
              (json-schema-bridge-test-slot object-contract 'tags))
             (name-slot
              (json-schema-bridge-test-slot object-contract 'name))
             (label-slot
              (json-schema-bridge-test-slot object-contract 'label))
             (bucket-slot
              (json-schema-bridge-test-slot object-contract 'bucket))
             (score-slot
              (json-schema-bridge-test-slot object-contract 'score))
             (choice-slot
              (json-schema-bridge-test-slot object-contract 'choice))
             (numeric-slot
              (json-schema-bridge-test-slot object-contract 'numeric))
             (maybe-slot
              (json-schema-bridge-test-slot object-contract 'maybe))
             (tags?
              (json-schema-bridge-test-slot-predicate tags-slot))
             (name?
              (json-schema-bridge-test-slot-predicate name-slot))
             (label?
              (json-schema-bridge-test-slot-predicate label-slot))
             (bucket?
              (json-schema-bridge-test-slot-predicate bucket-slot))
             (score?
              (json-schema-bridge-test-slot-predicate score-slot))
             (choice?
              (json-schema-bridge-test-slot-predicate choice-slot))
             (numeric?
              (json-schema-bridge-test-slot-predicate numeric-slot))
             (maybe?
              (json-schema-bridge-test-slot-predicate maybe-slot)))
        (check-equal? (json-schema-bridge-test-ref receipt 'valid?) #t)
        (check-equal? (json-schema-bridge-test-ref receipt 'diagnostic-count) 0)
        (check-equal? (length (json-schema-bridge-test-ref receipt 'type-facts)) 8)
        (check-equal? (yuanxu-contract-slot-report-kind tags-slot) 'List)
        (check-equal?
         (yuanxu-contract-slot-predicate-key choice-slot)
         'yuanxu-json-schema-one-of-generated?)
        (check-equal? (tags? '("a" "b")) #t)
        (check-equal? (tags? '("a" 1)) #f)
        (check-equal? (tags? '((name . "object-shaped"))) #f)
        (check-equal? (tags? '()) #f)
        (check-equal? (tags? '("a" "b" "c")) #f)
        (check-equal? (name? "flow") #t)
        (check-equal? (name? "go") #f)
        (check-equal? (name? "workflow!") #f)
        (check-equal? (label? "ci-build") #t)
        (check-equal? (label? "build") #f)
        (check-equal? (bucket? '((one . 1))) #t)
        (check-equal? (bucket? '()) #f)
        (check-equal? (bucket? '((one . 1) (two . 2) (three . 3))) #f)
        (check-equal? (score? 0) #t)
        (check-equal? (score? 9.5) #t)
        (check-equal? (score? -1) #f)
        (check-equal? (score? 10) #f)
        (check-equal? (choice? "x") #t)
        (check-equal? (choice? 7) #t)
        (check-equal? (choice? #t) #f)
        (check-equal? (numeric? 1.5) #t)
        (check-equal? (numeric? 7) #f)
        (check-equal? (numeric? "x") #f)
        (check-equal? (maybe? 'json-null) #t)
        (check-equal? (maybe? "ok") #t)
        (check-equal? (maybe? 7) #f)))
    (yuanxu-test-case "reports invalid supported constraint values"
      (let* ((artifact
              (yuanxu-json-schema->contract-artifact
               json-schema-bridge-invalid-constraint-schema
               '((source-ref . json-schema-invalid-constraint-test)
                 (owner . contract)
                 (object-kind . AgenticAILabJsonSchemaInvalidConstraintTest)
                 (object-key . json-schema/invalid-constraint-test))))
             (receipt
              (yuanxu-json-schema-contract-artifact->alist artifact))
             (diagnostics
              (json-schema-bridge-test-ref receipt 'diagnostics))
             (diagnostic
              (car diagnostics)))
        (check-equal? (json-schema-bridge-test-ref receipt 'valid?) #t)
        (check-equal? (json-schema-bridge-test-ref receipt 'diagnostic-count) 1)
        (check-equal?
         (json-schema-bridge-test-ref diagnostic 'reason)
         'invalid-constraint-value)))
    (yuanxu-test-case "recursively validates generic map-value contracts"
      (let* ((artifact
              (yuanxu-json-schema->contract-artifact
               json-schema-bridge-recursive-map-schema
               '((source-ref . json-schema-recursive-map-test)
                 (owner . funflow)
                 (object-kind . AgenticAILabCustomStageContract)
                 (object-key . funflow/custom-stage))))
             (valid-receipt
              (yuanxu-json-schema-object-contract-validation->alist
               (yuanxu-json-schema-contract-artifact-validate
                artifact
                json-schema-bridge-recursive-map-valid-value)))
             (missing-command-receipt
              (yuanxu-json-schema-object-contract-validation->alist
               (yuanxu-json-schema-contract-artifact-validate
                artifact
                json-schema-bridge-recursive-map-missing-command)))
             (invalid-stage-key-receipt
              (yuanxu-json-schema-object-contract-validation->alist
               (yuanxu-json-schema-contract-artifact-validate
                artifact
                json-schema-bridge-recursive-map-invalid-stage-key))))
        (check-equal?
         (json-schema-bridge-test-ref valid-receipt 'valid?)
         #t)
        (check-equal?
         (json-schema-bridge-test-ref missing-command-receipt 'valid?)
         #f)
        (check-equal?
         (json-schema-bridge-test-ref missing-command-receipt 'missing-required)
         '(stages/stage-build/tasks/compile/command))
        (check-equal?
         (json-schema-bridge-test-ref invalid-stage-key-receipt 'valid?)
         #f)
        (check-equal?
         (json-schema-bridge-test-ref invalid-stage-key-receipt 'invalid-slots)
         '(stages/build))))
    (yuanxu-test-case "recursively validates generic additionalProperties maps"
      (let* ((artifact
              (yuanxu-json-schema->contract-artifact
               json-schema-bridge-additional-recursive-map-schema
               '((source-ref . json-schema-recursive-additional-map-test)
                 (owner . funflow)
                 (object-kind . AgenticAILabCustomProfileContract)
                 (object-key . funflow/custom-profile))))
             (valid-receipt
              (yuanxu-json-schema-object-contract-validation->alist
               (yuanxu-json-schema-contract-artifact-validate
                artifact
                json-schema-bridge-additional-recursive-map-valid-value)))
             (missing-value-receipt
              (yuanxu-json-schema-object-contract-validation->alist
               (yuanxu-json-schema-contract-artifact-validate
                artifact
                json-schema-bridge-additional-recursive-map-missing-value))))
        (check-equal?
         (json-schema-bridge-test-ref valid-receipt 'valid?)
         #t)
        (check-equal?
         (json-schema-bridge-test-ref missing-value-receipt 'valid?)
         #f)
        (check-equal?
         (json-schema-bridge-test-ref missing-value-receipt 'missing-required)
         '(profiles/default/limits/cpu/value))))))
