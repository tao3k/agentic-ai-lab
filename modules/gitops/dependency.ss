;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .cc .o)
        (only-in :clan/poo/type Type. define-type element? raise-type-error)
        (only-in :clan/poo/type List Record Symbol))
(export GitOpsModuleDependency gitops-module-dependency
        GitOpsDependencyName GitOpsSelectionReader GitOpsRevisionedBinding)

(define-type (GitOpsSelectionReader @ Type.) .element?: procedure?)
(define-type (GitOpsDependencyName @ Type.)
  .element?: (lambda (value) (and (string? value) (< 0 (string-length value) 257))))
(def GitOpsModuleDependency
  (.cc (Record current-selection: [GitOpsSelectionReader] module-path: [(List Symbol)])
       identity: 'gitops/module-dependency))
(def GitOpsRevisionedBinding
  (Record project: [GitOpsDependencyName] revision: [GitOpsDependencyName]))

;; The owner supplies its current admitted Yuanxu selection. This declaration
;; leaves every Module leaf cold until the consumer requests the path.
(def (gitops-module-dependency selection-reader path)
  (let* ((names (if (list? path) (map values path) path))
         (dependency (.o current-selection: selection-reader module-path: names)))
    (unless (and (element? GitOpsModuleDependency dependency) (pair? names))
      (raise-type-error GitOpsModuleDependency dependency))
    dependency))
