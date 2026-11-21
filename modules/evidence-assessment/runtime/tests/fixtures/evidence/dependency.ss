;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(defrules transitive-dependencies ()
  ((_ edge path)
   (ascent-fragment
    (relation path (from to))
    ((path from to) <-- (edge from to))
    ((path from to) <-- (edge from middle) (path middle to)))))

(def (make-dependency-relations)
  (ascent-fragment
   (relation dependency (from to))
   (transitive-dependencies dependency ancestry)))

(def (native-copy-rule from to)
  (let (terms (list (gerbil-ascent-variable 'from) (gerbil-ascent-variable 'to)))
    (gerbil-ascent-rule
     (list (gerbil-ascent-atom to terms))
     (list (gerbil-ascent-atom from terms)))))

(def (make-dependency-transform)
  (relational-op-function
   2 (lambda (edge)
       (relational-op-fix
        2 (lambda (path)
            (relational-op-union
             edge (relational-op-project
                   (relational-op-join path edge 1 0) '(0 3))))))))

(def (make-dependency-updater rows)
  (let (retained (relational-op-open-retained
                 (make-dependency-transform) (dependency-label-rows rows) +inf.0 +inf.0 +inf.0))
    (lambda (replacements)
      (relational-op-retained-replace! retained (dependency-label-rows replacements)))))

;; Checked operators use immutable scalar atoms; catalog path labels are strings.
;; This scenario binds their exact labels as Scheme symbols, not Python IDs.
(def (dependency-label-rows rows)
  (map (lambda (row) (map string->symbol row)) rows))

(def (dependency-update-summary updater rows expected)
  (let-values (((before after added removed) (updater rows)))
    (unless (and (= (length after) (length expected))
                 (andmap (lambda (row) (member row (dependency-label-rows expected))) after))
      (error "operator closure differs from the recursive evidence rules"))
    (values after (length added) (length removed))))

(def (make-typed-dependency-transform atoms)
  (let (type (relational-relation-type 2 (map string->symbol atoms)))
    (relational-typed-function
     type (lambda (edge)
            (relational-typed-fix
             (relational-typed-function
              type (lambda (path)
                     (relational-typed-union
                      edge (relational-typed-project
                            (relational-typed-join path edge 1 0) '(0 3))))))))))

(def (typed-dependency-summary atoms rows expected)
  (let* ((type (relational-relation-type 2 (map string->symbol atoms)))
         (input (relational-typed-source 'contracts type (dependency-label-rows rows)))
         (term (relational-typed-apply (make-typed-dependency-transform atoms) input)))
    (let-values (((program output) (relational-typed-compile term +inf.0 +inf.0 +inf.0)))
      (let (after (relational-query-name (relational-solve (relational-admit program)) output))
        (unless (and (= (length after) (length expected))
                     (andmap (lambda (row) (member row (dependency-label-rows expected))) after))
          (error "typed closure differs from the recursive evidence rules"))
        (values after (relational-type-height-expression
                       (relational-arrow-type type type)))))))

(def (make-dependency-actor rows workers)
  (let* ((declaration
          (ascent
           (relation dependency (from to) (dependency-label-rows rows))
           (transitive-dependencies dependency ancestry)))
         (program
          (gerbil-ascent-program
           (.ref declaration 'relations) (.ref declaration 'rules)
           +inf.0 +inf.0 +inf.0 '(dependency)))
         (session (gerbil-ascent-open-actor-session program workers: workers)))
    (lambda (operation replacements)
      (cond
       ((string=? operation "run")
        ((.ref (gerbil-ascent-session-run session) 'rows-of) 'ancestry))
       ((string=? operation "replace")
        (gerbil-ascent-session-replace-source! session 'dependency
                                              (dependency-label-rows replacements)))
       ((string=? operation "state") (gerbil-ascent-session-state session))
       ((string=? operation "cancel") (gerbil-ascent-session-cancel! session))
       ((string=? operation "close") (gerbil-ascent-session-close! session))
       (else (error "unknown dependency actor request" operation))))))

(def (dependency-actor-summary actor rows expected)
  (actor "replace" rows)
  (let (after (actor "run" []))
    (unless (and (= (length after) (length expected))
                 (andmap (lambda (row) (member row (dependency-label-rows expected))) after))
      (error "actor closure differs from the recursive evidence rules"))
    (values after (actor "state" []))))
