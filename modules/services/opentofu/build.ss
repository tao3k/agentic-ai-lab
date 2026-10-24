;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Phase-isolated Build role for the single OpenTofu Module publication.
(import :clan/poo/object
        (only-in :std/encoding/json write-json)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :yuanxu/module-system/building/configuration-source yuanxu-configuration-source)
        (only-in :yuanxu/module-system/source/admission call-with-module-source-read-cache
                 module-source-admit-current!)
        ;; Build-tool native owners, not a second runtime facade or Loader.
        (only-in :agentic-ai-lab/modules/nix/types NixFlakeSourceContract)
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (only-in :agentic-ai-lab/modules/nix/func agentic-ai-lab-nix-source-inputs))
;; The native outer module slot keeps source/config refinements receiver-local.
(.def Build
  module: OpenTofuScope.
  configuration-projection: (lambda (configuration) configuration)
  kind: 'module/external-package identity: 'opentofu
  .prepare:
  (lambda (root context-current! publication)
    (unless (yuanxu-validation-evidence-accepted?
              (.call OpenTofuConfigContract .admit (.get module config) #f))
      (error "invalid OpenTofu upstream Config; expected a native Nix Source"))
    (unless (.get module config source)
      (error "build-required: OpenTofu Config.source must supply a Nix Source"))
    (let* ((source (.cc (.get module config source)))
           (flake? (yuanxu-validation-evidence-accepted?
                     (.call NixFlakeSourceContract .admit source #f)))
           (selection-input (and (.slot? (.get module config) 'selection-input)
                                 (.get module config selection-input)))
           (path (path-expand "config.ss" root))
           (configuration-input (yuanxu-configuration-source path 'Config context-current!
                                  role-sources: (.get publication role-sources)))
           (observed (append (.get configuration-input source-inputs) (.get source source-inputs)))
           (source-text (cdr (assoc path observed)))
           (source-digest (hex-encode (sha256 (string->utf8 source-text))))
           (configuration-value (configuration-projection (.get configuration-input value)))
           (projected-demand (.call module .build-inputs configuration-value))
           (wire (call-with-output-string
                  (lambda (port)
                    (write-json port
                      (list->hash-table
                       (list (cons 'providers (list->vector (.get projected-demand providers)))
                             (cons 'configuration-source path)
                             (cons 'configuration-sha256 source-digest)
                             (cons 'binding "Config")
                             (cons 'source-inputs (agentic-ai-lab-nix-source-inputs observed)))))))))
      (def (current!)
        ;; Both are source-only observations of this same prepared request.
        ;; Keep its full requirements while sharing bytes inside this check;
        ;; Nix realization and validators remain outside the window.
        (call-with-module-source-read-cache
          (lambda ()
            ((.get configuration-input admit-current))
            (module-source-admit-current! observed))))
      (current!)
      (.o identity: 'opentofu source-inputs: observed
          configuration: configuration-value demand: projected-demand
          input-files: (list (cons "selection.json" wire))
          admit-current: current!
          .realize:
          (lambda (directory check-current!)
            (let* ((selection (path-expand "selection.json" directory))
                   (nix-source
                     (if selection-input
                       (begin
                         (unless (and flake? (symbol? selection-input)
                                      (null? (.all-slots (.get source arguments))))
                           (error "final OpenTofu package requires a flake data input, not function arguments"))
                         (.cc source 'source-inputs observed
                           'inputs (.cc (.get source inputs) selection-input directory)))
                       (.cc source 'source-inputs observed
                         'arguments (.cc (.get source arguments) 'selection (if flake? wire selection)))))
                   (publication (.call nix-source .prepare check-current!)))
              ;; The complete package scope remains inspectable. Its only
              ;; direct override is config; Core reuses the selected source's
              ;; declarations when binding that override to a ready scope.
              (.+ publication
                (.o (:: @ [] artifact)
                    scope: (.o (:: @ module)
                             config: (.cc (.get module config) 'artifact artifact))
                    configuration: configuration-value
                    ;; Value evidence over the immutable realized artifact is
                    ;; candidate-only. SelectedPackages checks package identity
                    ;; after ALL value validators, before publishing its result.
                    admission: (.call (.get scope types configuration) .admit configuration-value #f)))))))))
