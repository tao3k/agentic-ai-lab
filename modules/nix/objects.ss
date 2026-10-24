;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object "./config.ss" "./types.ss" "./func.ss" "./build-publication.ss"
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (only-in :yuanxu/module-system/source/admission module-source-admit-current! module-source-type module-source-read
                 module-source-checked-operation module-source-operation-procedure))
(export NixSource. NixFlakeSource. agentic-ai-lab-nix-admit-generation
        agentic-ai-lab-nix-flake-admit-generation)
(.def (NixSource. source [])
  .restore-build:
  (lambda (graph)
    (agentic-ai-lab-nix-restore-build-publication! source graph))
  expression: #f
  ;; A configured Source owns its byte observations. Flake Sources override this
  ;; with their lock/source closure; expression callers may refine it upstream.
  source-inputs: (if (and (string? expression) (eq? (module-source-type expression) 'regular))
                  (list (cons expression (module-source-read expression))) '())
  arguments: (.o)
  config: NixConfig
  .instantiate:
  (lambda ()
    (unless (yuanxu-validation-evidence-accepted? (.call NixSourceContract .admit source #f))
      (error "invalid Nix Source"))
    (agentic-ai-lab-nix-instantiate
      (.get config instantiate) expression arguments
      ;; Readonly guards do not need the realization capability.
      (lambda () (.get config realize))))
  .realize:
  (lambda (derivation)
    (agentic-ai-lab-nix-realize (.get config realize) derivation))
  .guard-form:
  (lambda (expected)
    (let ((rows (map (lambda (name) (cons name (.ref arguments name))) (.all-slots arguments)))
          (tools (map (lambda (name) (cons name (.ref config name))) '(instantiate realize))))
      `(agentic-ai-lab-nix-admit-generation ,expression ',rows ,expected ',tools)))
  ;; A native phase object: derivation and realization are receiver-local lazy
  ;; slots. Core may write its guarded entry between preparation and validation.
  ;; This is a candidate until admit-current succeeds; .build keeps the eager
  ;; public publication boundary for standalone callers.
  .prepare:
  (lambda (check-current!)
    (let (source-value source)
      (.o (:: publication) source: source-value
          preflight: (check-current!)
          derivation: (begin preflight (.call source-value .instantiate))
          artifact: (.call source-value .realize derivation)
          %source-operation:
          (module-source-checked-operation check-current!
            (lambda ()
              ;; A cached artifact read has no realization effect. The cold path
              ;; still brackets realization; warm calls retain the pre-query and
              ;; post-query checks without repeating that same source-only guard.
              (unless (.ref/cached publication 'artifact)
                artifact
                (check-current!))
              (admit-derivation! source-value derivation)))
          ;; The paired native continuation can omit just this operation's
          ;; entry guard when its caller has immediately run that exact guard.
          ;; Tail checks and all external effect boundaries remain unchanged.
          admit-current: (module-source-operation-procedure %source-operation)
          guard-imports: '(:agentic-ai-lab/modules/nix/objects)
          guard-forms:
          (list (.call source-value .guard-form derivation)))))
  .build:
  (lambda (check-current!)
    (let (publication (.call source .prepare check-current!))
      ((.get publication admit-current))
      publication)))
(.def (NixFlakeSource. source NixSource. config arguments)
  reference: #f
  attribute: #f
  ;; Explicit local data inputs are hashed by Nix on every query. They are not
  ;; Scheme argument/result caches and never permit implicit lock-file updates.
  inputs: (.o)
  ;; An optional explicitly owned evaluator scope. Native POO receiver copies
  ;; retain configuration, not an admission verdict or a selected flake output.
  evaluator: #f
  source-inputs: (agentic-ai-lab-nix-flake-source-inputs reference)
  .instantiate:
  (lambda ()
    (unless (yuanxu-validation-evidence-accepted?
              (.call NixFlakeSourceContract .admit source #f))
      (error "invalid Nix Flake Source"))
    (module-source-admit-current! source-inputs)
    (let (result (if evaluator
                   (.call evaluator .instantiate reference attribute arguments inputs (.get config nix))
                   (agentic-ai-lab-nix-flake-instantiate
                     (.get config nix) reference attribute arguments inputs)))
      (module-source-admit-current! source-inputs)
      result))
  .guard-form:
  (lambda (expected)
    `(agentic-ai-lab-nix-flake-admit-generation
       ,reference ,attribute ,expected ,(.get config nix)
       ',(map (lambda (key) (cons key (.ref arguments key))) (.all-slots arguments))
       ',source-inputs
       ',(map (lambda (key) (cons key (.ref inputs key))) (.all-slots inputs)))))

(def (admit-derivation! source expected)
  (unless (equal? (call-with-nix-derivation-query (lambda () (.call source .instantiate))) expected)
    (error "stale external package derivation; regenerate the selected build graph" expected)))

;; Serialized generated build guard: rows are a private wire boundary, not a DSL.
(def (agentic-ai-lab-nix-admit-generation expression-path argument-rows expected (tools #f))
  (let (source (.cc NixSource. 'expression expression-path 'arguments (object<-alist argument-rows)
                    'config (if tools (object<-alist tools) NixConfig)))
    (admit-derivation! source expected)))
(def (agentic-ai-lab-nix-flake-admit-generation reference attribute expected executable
        (argument-rows '()) (observations '()) (input-rows '()))
  (admit-derivation!
    (.cc NixFlakeSource. 'reference reference 'attribute attribute
      'config (.cc NixConfig 'nix executable)
      'arguments (object<-alist argument-rows) 'source-inputs observations
      'inputs (object<-alist input-rows))
    expected))
