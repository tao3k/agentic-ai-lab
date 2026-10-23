;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Executable POO-CLOS and separately scoped MOP-EXTENDED clause inventory.

(import (only-in :clan/poo/object .o .ref))

(export poo-clos-clause-ledger poo-clos-operator-ledger
        poo-clos-required-rows poo-clos-required-operators
        poo-clos-open-required-rows poo-clos-ledger-row-valid?
        poo-clos-operator-row-valid?
        poo-clos-evidence-suites poo-clos-evidence-suite
        poo-clos-evidence-id-resolves?)

(def (owner-evidence-id owner)
  (case owner
    ((classes lifecycle) 'lifecycle)
    ((objects dispatch) 'dispatch)
    ((syntax) 'syntax)
    ((method-combination) 'method-combination)
    ((evolution mop) 'evolution)
    ((generic-evolution) 'generic-evolution)
    ((load-form) 'load-form)
    (else #f)))

;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol POOObject)
(def (clause status-name row-id profile-name owner-name positive-name negative-name)
  (.o id: row-id
      profile: profile-name
      status: status-name
      owner: owner-name
      evidence-id: (owner-evidence-id owner-name)
      positive-test: positive-name
      negative-test: negative-name))

(def (closed-clause row-id profile owner positive negative)
  (clause 'closed row-id profile owner positive negative))

(def poo-clos-clause-ledger
  (list
   ;; Class definition, inheritance, slots, and construction.
   (closed-clause 'C43-class-metaobjects 'poo-clos 'classes
           'native-class-metaobjects 'invalid-class)
   (closed-clause 'C432-class-definition 'poo-clos 'syntax
           'defclass-lowering 'duplicate-class-declarations)
   (closed-clause 'C432-slot-options 'poo-clos 'classes
           'slot-option-projection 'invalid-slot-options)
   (closed-clause 'C433-make-instance 'poo-clos 'lifecycle
           'make-instance-initialization 'invalid-initargs)
   (closed-clause 'C434-inheritance 'poo-clos 'classes
           'diamond-inheritance 'duplicate-direct-superclass)
   (closed-clause 'C435-class-precedence 'poo-clos 'classes
           'native-c4-order 'inconsistent-c4)
   (closed-clause 'C436-class-redefinition 'poo-clos 'evolution
           'identity-preserved-generation 'invalid-class-redefinition)
   (closed-clause 'C436-dependent-propagation 'poo-clos 'evolution
           'dependent-generation-cascade 'stale-superclass-generation)
   (closed-clause 'C436-lazy-instance-update 'poo-clos 'lifecycle
           'lazy-instance-convergence 'discarded-slot-property-list)
   (closed-clause 'C436-shared-slot-transition 'poo-clos 'evolution
           'shared-slot-cell-preservation 'allocation-transition)
   (closed-clause 'C436-make-instances-obsolete 'poo-clos 'evolution
           'explicit-layout-generation 'invalid-obsolescence-target)
   (closed-clause 'C437-class-specialized-types 'poo-clos 'dispatch
           'class-specializer-inheritance 'invalid-specializer)

   ;; Creation, reinitialization, class change, and slot protocols.
   (closed-clause 'C71-allocation-initialization 'poo-clos 'lifecycle
           'allocate-initialize-shared 'malformed-initialization-arguments)
   (closed-clause 'C71-default-initargs 'poo-clos 'lifecycle
           'leftmost-default-initargs 'unknown-initarg)
   (closed-clause 'C72-change-class 'poo-clos 'lifecycle
           'identity-preserving-change-class 'invalid-target-class)
   (closed-clause 'C72-update-different-class 'poo-clos 'lifecycle
           'previous-current-hook-views 'invalid-change-initargs)
   (closed-clause 'C73-reinitialize-instance 'poo-clos 'lifecycle
           'reinitialize-supplied-slots 'reinitialize-does-not-run-initforms)
   (closed-clause 'C75-slot-value 'poo-clos 'lifecycle
           'slot-read-write 'slot-missing)
   (closed-clause 'C75-slot-boundp-makunbound 'poo-clos 'lifecycle
           'bound-and-makunbound 'slot-unbound)
   (closed-clause 'C752-generated-accessors 'poo-clos 'syntax
           'reader-writer-method-dispatch 'missing-accessor-slot)
   (closed-clause 'C752-with-slots 'poo-clos 'syntax
           'live-with-slots-read 'invalid-slot-name)
   (closed-clause 'C752-with-accessors 'poo-clos 'syntax
           'live-with-accessors-dispatch 'missing-accessor-method)
   (closed-clause 'C753-slot-inheritance 'poo-clos 'classes
           'effective-slot-option-merge 'duplicate-direct-slot)
   (closed-clause 'C753-class-allocation 'poo-clos 'classes
           'shared-and-shadowed-slots 'invalid-slot-allocation)

   ;; Generic functions, methods, selection, and combination.
   (closed-clause 'C761-generic-function 'poo-clos 'objects
           'generic-function-metaobject 'invalid-generic-function)
   (closed-clause 'C762-method-metaobject 'poo-clos 'objects
           'method-metaobject 'invalid-method)
   (closed-clause 'C763-specializer-qualifier-agreement 'poo-clos 'objects
           'method-replacement-agreement 'invalid-method-qualifier)
   (closed-clause 'C764-lambda-list-congruence 'poo-clos 'objects
           'congruent-lambda-lists 'incongruent-method-lambda-list)
   (closed-clause 'C765-applicable-keyword-union 'poo-clos 'dispatch
           'applicable-method-keyword-union 'invalid-keyword-argument)
   (closed-clause 'C766-no-applicable-first 'poo-clos 'dispatch
           'no-applicable-before-keywords 'no-applicable-method)
   (closed-clause 'C766-applicable-methods 'poo-clos 'dispatch
           'multiple-dispatch-ranking 'changed-applicable-methods)
   (closed-clause 'C766-argument-precedence-order 'poo-clos 'dispatch
           'argument-precedence-order 'invalid-argument-precedence-order)
   (closed-clause 'C766-standard-combination 'poo-clos 'dispatch
           'standard-method-combination 'no-primary-method)
   (closed-clause 'C766-next-method 'poo-clos 'dispatch
           'call-next-method 'no-next-method)
   (closed-clause 'C7663-declarative-combination 'poo-clos 'method-combination
           'short-and-long-combinations 'required-method-group-empty)
   (closed-clause 'C7664-built-in-combinations 'poo-clos 'method-combination
           'all-nine-built-ins 'unsupported-combination-operator)
   (closed-clause 'C767-method-inheritance 'poo-clos 'dispatch
           'superclass-method-applicability 'no-applicable-method)
   (closed-clause 'D-ensure-generic-function 'poo-clos 'generic-evolution
           'ensure-generic-binding 'generic-binding-identity-mismatch)
   (closed-clause 'D-generic-reinitialization 'poo-clos 'generic-evolution
           'atomic-generic-reconfiguration 'method-required-argument-mismatch)

   ;; This row is evidence but cannot satisfy or dilute a POO CLOS requirement.
   (closed-clause 'MOP-portable-read-only-profile 'mop-extended 'mop
           'sealed-capability-profile 'unadmitted-operation)))

;;; Evidence identities resolve to exact source-owned std/test suite bindings.
;;; The ledger test reads these Scheme sources with the native reader and
;;; verifies the export, suite definition, case cardinality, and nonzero checks.
(def (evidence-suite id-value path-value binding-value case-count)
  (.o id: id-value path: path-value binding: binding-value
      caseCount: case-count))

(def poo-clos-evidence-suites
  (list
   (evidence-suite 'dispatch "yuanxu/t/poo-clos-dispatch-test.ss"
                   'poo-clos-dispatch-test 12)
   (evidence-suite 'lifecycle "yuanxu/t/poo-clos-lifecycle-test.ss"
                   'poo-clos-lifecycle-test 15)
   (evidence-suite 'syntax "yuanxu/t/poo-clos-syntax-test.ss"
                   'poo-clos-syntax-test 18)
   (evidence-suite 'method-combination
                   "yuanxu/t/poo-clos-method-combination-test.ss"
                   'poo-clos-method-combination-test 14)
   (evidence-suite 'evolution "yuanxu/t/poo-clos-evolution-test.ss"
                   'poo-clos-evolution-test 8)
   (evidence-suite 'generic-evolution
                   "yuanxu/t/poo-clos-generic-evolution-test.ss"
                   'poo-clos-generic-evolution-test 3)
   (evidence-suite 'load-form "yuanxu/t/poo-clos-load-form-test.ss"
                   'poo-clos-load-form-test 5)))

(def (poo-clos-evidence-suite id)
  (find (lambda (suite) (eq? (.ref suite 'id) id))
        poo-clos-evidence-suites))

(def (poo-clos-evidence-id-resolves? id)
  (and id (if (poo-clos-evidence-suite id) #t #f)))

(def (operator name status-name evidence-name gap-name)
  (.o id: name profile: 'poo-clos status: status-name
      evidence-id: evidence-name gap-id: gap-name))
(def (covered name evidence) (operator name 'closed evidence #f))
(def (missing name gap) (operator name 'open #f gap))

(def poo-clos-operator-ledger
  (list
   (covered 'function-keywords 'dispatch)
   (covered 'ensure-generic-function 'generic-evolution)
   (covered 'allocate-instance 'lifecycle)
   (covered 'reinitialize-instance 'lifecycle)
   (covered 'shared-initialize 'lifecycle)
   (covered 'update-instance-for-different-class 'evolution)
   (covered 'update-instance-for-redefined-class 'evolution)
   (covered 'change-class 'evolution)
   (covered 'slot-boundp 'lifecycle)
   (covered 'slot-exists-p 'lifecycle)
   (covered 'slot-makunbound 'lifecycle)
   (covered 'slot-missing 'lifecycle)
   (covered 'slot-unbound 'lifecycle)
   (covered 'slot-value 'lifecycle)
   (covered 'method-qualifiers 'dispatch)
   (covered 'no-applicable-method 'dispatch)
   (covered 'no-next-method 'dispatch)
   (covered 'remove-method 'dispatch)
   (covered 'make-instance 'lifecycle)
   (covered 'make-instances-obsolete 'evolution)
   (covered 'make-load-form 'load-form)
   (covered 'make-load-form-saving-slots 'load-form)
   (covered 'with-accessors 'syntax)
   (covered 'with-slots 'syntax)
   (covered 'defclass 'syntax)
   (covered 'defgeneric 'syntax)
   (covered 'defmethod 'syntax)
   (covered 'find-class 'lifecycle)
   (covered 'next-method-p 'dispatch)
   (covered 'call-method/make-method 'method-combination)
   (covered 'call-next-method 'dispatch)
   (covered 'compute-applicable-methods 'dispatch)
   (covered 'define-method-combination 'method-combination)
   (covered 'find-method 'dispatch)
   (covered 'add-method 'dispatch)
   (covered 'initialize-instance 'lifecycle)
   (covered 'class-name 'evolution)
   (covered '(setf class-name) 'lifecycle)
   (covered 'class-of 'lifecycle)
   (covered 'unbound-slot 'lifecycle)
   (covered 'unbound-slot-instance 'lifecycle)))

(def (poo-clos-required-operators) poo-clos-operator-ledger)

;; : (-> [POOObject])
(def (poo-clos-required-rows)
  (filter (lambda (row) (eq? (.ref row 'profile) 'poo-clos))
          poo-clos-clause-ledger))

;; : (-> [POOObject])
(def (poo-clos-open-required-rows)
  (filter (lambda (row) (not (eq? (.ref row 'status) 'closed)))
          (append (poo-clos-required-rows)
                  (poo-clos-required-operators))))

;; : (-> POOObject Boolean)
(def (poo-clos-ledger-row-valid? row)
  (and (memq (.ref row 'status) '(closed open))
       (memq (.ref row 'profile) '(poo-clos mop-extended))
       (symbol? (.ref row 'id))
       (symbol? (.ref row 'owner))
       (poo-clos-evidence-id-resolves? (.ref row 'evidence-id))
       (symbol? (.ref row 'positive-test))
       (symbol? (.ref row 'negative-test))))

(def (poo-clos-operator-row-valid? row)
  (let ((status (.ref row 'status))
        (evidence (.ref row 'evidence-id))
        (gap (.ref row 'gap-id)))
    (and (equal? (.ref row 'profile) 'poo-clos)
         (or (symbol? (.ref row 'id)) (pair? (.ref row 'id)))
         (case status
           ((closed) (and (poo-clos-evidence-id-resolves? evidence) (not gap)))
           ((open) (and (not evidence) (symbol? gap)))
           (else #f)))))
