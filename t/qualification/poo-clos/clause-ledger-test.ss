;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Clause ledger completeness and profile-separation checks.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite check-equal? check)
        (only-in :clan/poo/object .o .ref)
        (only-in :yuanxu/module-system/observability/presentation
                 yuanxu-poo-slot-authoring-datum-observations
                 yuanxu-poo-slot-authoring-file-observations
                 yuanxu-poo-slot-authoring-diagnostics)
        "clause-ledger.ss")

(export clause-ledger-test)

(def (unique-symbols? values)
  (= (length values)
     (length (foldl (lambda (value result)
                      (if (memq value result) result (cons value result)))
                    '() values))))

(def (scheme-files directory predicate)
  (map (lambda (name) (path-expand name directory))
       (filter (lambda (name)
                 (and (string-suffix? ".ss" name) (predicate name)))
               (directory-files directory))))

(def (poo-clos-owned-sources)
  (append
   (scheme-files "yuanxu/poo-clos" (lambda (_name) #t))
   (scheme-files "yuanxu/t"
                 (lambda (name) (string-prefix? "poo-clos-" name)))
   (scheme-files "t"
                 (lambda (name) (string-prefix? "poo-clos-" name)))
   (scheme-files "t/qualification/poo-clos" (lambda (_name) #t))))

(def (poo-clos-authoring-diagnostics path)
  (yuanxu-poo-slot-authoring-diagnostics
   (yuanxu-poo-slot-authoring-file-observations 'poo-clos path)))

(def (read-source-forms path)
  (call-with-input-file
   path
   (lambda (port)
     (let loop ((forms '()))
       (let (form (read port))
         (if (eof-object? form)
           (reverse forms)
           (loop (cons form forms))))))))

(def (source-exports-binding? forms binding)
  (and (find (lambda (form)
               (and (pair? form) (eq? (car form) 'export)
                    (memq binding (cdr form))))
             forms)
       #t))

(def (source-suite-form forms binding)
  (find (lambda (form)
          (and (pair? form) (eq? (car form) 'def)
               (pair? (cdr form)) (eq? (cadr form) binding)
               (pair? (cddr form))
               (pair? (caddr form))
               (eq? (car (caddr form)) 'test-suite)))
        forms))

(def (suite-test-case-forms suite-form)
  (filter (lambda (form)
            (and (pair? form)
                 (memq (car form) '(yuanxu-test-case yuanxu-test-case))
                 (pair? (cdr form)) (string? (cadr form))))
          (cddr (caddr suite-form))))

(def (check-form-count datum)
  (cond
   ((pair? datum)
    (+ (if (and (symbol? (car datum))
                (or (eq? (car datum) 'check)
                    (string-prefix? "check-"
                                    (symbol->string (car datum)))))
         1 0)
       (check-form-count (car datum))
       (check-form-count (cdr datum))))
   ((vector? datum)
    (foldl (lambda (value count) (+ count (check-form-count value)))
           0 (vector->list datum)))
   (else 0)))

(def (poo-clos-evidence-suite-valid? suite)
  (let* ((path (.ref suite 'path))
         (binding (.ref suite 'binding))
         (forms (and (file-exists? path) (read-source-forms path)))
         (suite-form (and forms (source-suite-form forms binding)))
         (cases (and suite-form (suite-test-case-forms suite-form))))
    (and forms
         (source-exports-binding? forms binding)
         suite-form
         (= (length cases) (.ref suite 'caseCount))
         (> (length cases) 0)
         (andmap (lambda (test-case-form)
                   (> (check-form-count test-case-form) 0))
                 cases))))

(def clause-ledger-test
  (test-suite "POO-native CLOS executable clause ledger"
    (yuanxu-test-case "semantic clause rows remain explicit and structurally valid"
      (let (required (poo-clos-required-rows))
        (check (> (length required) 30) => #t)
        (check-equal? (.ref (car required) 'id) 'C43-class-metaobjects)
        (check (andmap poo-clos-ledger-row-valid? required) => #t)
        (check (unique-symbols?
                (map (lambda (row) (.ref row 'id)) required)) => #t)))
    (yuanxu-test-case "the CLHS Objects Dictionary is exhaustive and fail-closed"
      (let* ((operators (poo-clos-required-operators))
             (names (map (lambda (row) (.ref row 'id)) operators))
             (open (poo-clos-open-required-rows)))
        (check-equal? (length operators) 41)
        (check (andmap poo-clos-operator-row-valid? operators) => #t)
        (check-equal?
         names
         '(function-keywords ensure-generic-function allocate-instance
           reinitialize-instance shared-initialize
           update-instance-for-different-class
           update-instance-for-redefined-class change-class slot-boundp
           slot-exists-p slot-makunbound slot-missing slot-unbound slot-value
           method-qualifiers no-applicable-method no-next-method remove-method
           make-instance make-instances-obsolete make-load-form
           make-load-form-saving-slots with-accessors with-slots defclass
           defgeneric defmethod find-class next-method-p
           call-method/make-method call-next-method compute-applicable-methods
           define-method-combination find-method add-method initialize-instance
           class-name (setf class-name) class-of unbound-slot
           unbound-slot-instance))
        (check-equal? open '())))
    (yuanxu-test-case "closed evidence resolves to executable source-owned suites"
      (check (unique-symbols?
              (map (lambda (suite) (.ref suite 'id))
                   poo-clos-evidence-suites))
             => #t)
      (for-each
       (lambda (suite)
         (check-equal? (list (.ref suite 'id) (poo-clos-evidence-suite-valid? suite))
                       (list (.ref suite 'id) #t)))
       poo-clos-evidence-suites)
      (check (andmap
              (lambda (row)
                (poo-clos-evidence-id-resolves? (.ref row 'evidence-id)))
              (poo-clos-required-rows))
             => #t))
    (yuanxu-test-case "evidence binding fails closed on removed or emptied suites"
      (check
       (poo-clos-evidence-suite-valid?
        (.o id: 'removed path: "t/poo-clos-removed-test.ss"
            binding: 'poo-clos-removed-test caseCount: 1))
       => #f)
      (let (dispatch (poo-clos-evidence-suite 'dispatch))
        (check
         (poo-clos-evidence-suite-valid?
          (.o id: 'dispatch path: (.ref dispatch 'path)
              binding: (.ref dispatch 'binding) caseCount: 0))
         => #f)))
    (yuanxu-test-case "all CLOS-owned POO slot initializers pass the source gate"
      (check-equal?
       (apply append (map poo-clos-authoring-diagnostics
                          (poo-clos-owned-sources)))
       '()))
    (yuanxu-test-case "the source gate rejects the observed lazy self-slot leak shape"
      (let (diagnostics
            (yuanxu-poo-slot-authoring-diagnostics
             (yuanxu-poo-slot-authoring-datum-observations
              'poo-clos
              '(def (operator status-name)
                 (.o status: status)))))
        (check (pair? diagnostics) => #t)
        (check-equal? (cdr (assoc 'code (car diagnostics)))
                      'poo-slot-initializer-shadows-slot)
        (check-equal? (cdr (assoc 'slot (car diagnostics))) 'status)))
    (yuanxu-test-case "MOP evidence remains outside the POO CLOS core denominator"
      (let (extended
            (filter (lambda (row) (eq? (.ref row 'profile) 'mop-extended))
                    poo-clos-clause-ledger))
        (check-equal? (length extended) 1)
        (check (not (memq (car extended) (poo-clos-required-rows)))
               => #t)))))
