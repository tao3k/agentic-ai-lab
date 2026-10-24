;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (only-in :std/text/pregexp pregexp-match)
        (only-in :yuanxu/object-types/contracts yuanxu-predicate-contract))
(export NixSourceContract NixFlakeSourceContract NixScopeContract)
(def (nix-arguments? value)
  (and (object? value)
       (every (lambda (key)
                (and (symbol? key) (pregexp-match "^[A-Za-z][A-Za-z0-9_-]*$" (symbol->string key))
                     (string? (.ref value key)))) (.all-slots value))))
(def (source-inputs? value)
  (and (list? value)
       (every (lambda (row) (and (pair? row) (string? (car row))
                                 (or (not (cdr row)) (string? (cdr row))))) value)))
(def NixSourceContract
  (yuanxu-predicate-contract 'nix/source
    (lambda (value)
      (and (object? value) (.slot? value 'expression) (.slot? value 'arguments)
           (string? (.get value expression))
           (nix-arguments? (.get value arguments))))
    (lambda (_v _c) '())))

(def NixFlakeSourceContract
  (yuanxu-predicate-contract 'nix/flake-source
    (lambda (value)
      (and (object? value)
           (.slot? value 'reference) (string? (.get value reference))
           (pregexp-match "^(/|path:/|github:|gitlab:|git\\+|https://)" (.get value reference))
           (not (string-index (.get value reference) #\#))
           (.slot? value 'attribute) (string? (.get value attribute))
           (pregexp-match "^[A-Za-z_][A-Za-z0-9_-]*(\\.[A-Za-z_][A-Za-z0-9_-]*)*$" (.get value attribute))
           ;; Empty arguments select a package; nonempty string arguments apply
           ;; an exported native Nix function through --apply, never --argstr.
           (.slot? value 'arguments) (nix-arguments? (.get value arguments))
           (.slot? value 'inputs) (nix-arguments? (.get value inputs))
           (or (not (.slot? value 'evaluator)) (not (.get value evaluator))
               (let (evaluator (.get value evaluator))
                 (and (object? evaluator) (.slot? evaluator '.instantiate)
                      (procedure? (.get evaluator .instantiate)))))
           (every (lambda (key) (string-prefix? "/" (.ref (.get value inputs) key)))
                  (.all-slots (.get value inputs)))
           (.slot? value 'source-inputs) (source-inputs? (.get value source-inputs))))
    (lambda (_v _c) '())))

(def NixScopeContract
  (yuanxu-predicate-contract 'nix/scope
    (lambda (scope)
      (and (object? scope) (.slot? scope 'config) (.slot? scope 'types)
           (.slot? (.get scope types) 'Source)
           (.slot? scope 'prototypes) (.slot? (.get scope prototypes) 'Source)
           (.slot? (.get scope types) 'FlakeSource)
           (.slot? (.get scope prototypes) 'FlakeSource)
           (.slot? scope 'admit-generation) (procedure? (.get scope admit-generation))
           (.slot? scope 'source-inputs) (procedure? (.get scope source-inputs))))
    (lambda (_v _c) '())))
