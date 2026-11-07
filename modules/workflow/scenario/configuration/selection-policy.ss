;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product module routing is an input to Core selection admission.
(import (only-in :clan/poo/object .o object<-alist)
        (only-in :yuanxu/module-system/selection/objects current-module-selection-policy)
        (rename-in (only-in :yuanxu/module-system/selection/contract
                            yuanxu-use-module-contract-validation
                            yuanxu-require-use-module-contract!
                            yuanxu-modules-system-use-module/contract)
                   (yuanxu-use-module-contract-validation core-validation)
                   (yuanxu-require-use-module-contract! core-admit!)
                   (yuanxu-modules-system-use-module/contract core-use-module)))
(export AgenticAILabSelectionPolicy agentic-ai-lab-product-selection-validation
        agentic-ai-lab-product-selection-admit! agentic-ai-lab-product-use-module
        agentic-ai-lab-module-configs agentic-ai-lab-module-inherited-config)
(def AgenticAILabSelectionPolicy
  (.o groups:
      (.o funflow: 'flow loop-engine: 'flow workflow: 'flow custom-task: 'flow text: 'flow
          session: 'session tool-core: 'session ai-agentic-context: 'agentic model-core: 'session
          governor: 'loop sandbox-core: 'sandbox agent-sandbox: 'sandbox nono-sandbox: 'sandbox
          docker: 'sandbox cubeSandbox: 'sandbox docker-sandbox: 'sandbox)))
(def (agentic-ai-lab-product-selection-validation module selections)
  (parameterize ((current-module-selection-policy AgenticAILabSelectionPolicy))
    (core-validation module selections)))
(def (agentic-ai-lab-product-selection-admit! module selections)
  (parameterize ((current-module-selection-policy AgenticAILabSelectionPolicy))
    (core-admit! module selections)))
(def (agentic-ai-lab-product-use-module module flags)
  (parameterize ((current-module-selection-policy AgenticAILabSelectionPolicy))
    (core-use-module module flags)))

;;; One runtime lowering owns inherited external execution declarations.
;;; Values remain inert module-selection facts; no sandbox or command runs here.
(def (agentic-ai-lab-module-inherited-config module-key
                                       inherited-profile
                                       isolation
                                       environment
                                       command
                                       backend)
  (agentic-ai-lab-product-use-module
   module-key
   (list (cons ':inherits inherited-profile)
         (cons ':isolation isolation)
         (cons ':environment environment)
         (cons ':command command)
         (cons ':nono backend))))

(begin-syntax
  (def (agentic-ai-lab-config-syntax-keyword-slots/elements ctx elements)
    (match elements
      ([] '())
      ([slot-key slot-value . more]
       (let (key (syntax->datum slot-key))
         (and (keyword? key)
              (let (rest
                    (agentic-ai-lab-config-syntax-keyword-slots/elements ctx more))
                (and rest
                     (cons (list (datum->syntax
                                  ctx
                                  (string->symbol (keyword->string key)))
                                 slot-value)
                           rest))))))
      (else #f)))

  (def (agentic-ai-lab-config-syntax-keyword-slots ctx slot-specs)
    (let (elements (syntax->list slot-specs))
      (and elements
           (agentic-ai-lab-config-syntax-keyword-slots/elements ctx elements))))

  (def (agentic-ai-lab-config-syntax-keyword-slot-groups ctx slot-def-groups)
    (map (lambda (slot-specs)
           (agentic-ai-lab-config-syntax-keyword-slots ctx slot-specs))
         (syntax->list slot-def-groups)))

  (def (agentic-ai-lab-config-syntax-all? values)
    (not (member #f values)))

  (def (agentic-ai-lab-config-syntax-definition-heads? heads)
    (andmap (lambda (head)
              (eq? (syntax->datum head) '.def))
            (syntax->list heads))))

;;; One lowering owns POO prototype config declarations for every module.
;;; Module-specific syntax supplies only its module key and config projector.
(defsyntax (agentic-ai-lab-module-configs stx)
  (syntax-case stx (quoted)
    ((ctx module-key config-flags
          (quoted quoted-form ...)
          (definition-head
           (prototype-name prototype-self prototype-super prototype-slot ...)
           slot-def ...)
          ...)
     (let* ((definition-heads?
             (agentic-ai-lab-config-syntax-definition-heads?
              (syntax (definition-head ...))))
            (slot-groups
             (agentic-ai-lab-config-syntax-keyword-slot-groups
              (syntax ctx)
              (syntax ((slot-def ...) ...)))))
       (unless definition-heads?
         (error "agentic-ai-lab module config expects .def forms"))
       (if (agentic-ai-lab-config-syntax-all? slot-groups)
         (with-syntax (((((slot-name slot-value) ...) ...) slot-groups))
           (syntax
            (let* ((prototype-name
                    (object<-alist
                     (list (cons 'slot-name slot-value) ...)
                     supers: prototype-super))
                   ...)
              (agentic-ai-lab-product-use-module
               'module-key
               (config-flags
                (list prototype-name ...)
                '(quoted-form ...))))))
         (syntax
          (let* ((prototype-name
                  (.o (:: prototype-self prototype-super prototype-slot ...)
                      slot-def ...))
                 ...)
            (agentic-ai-lab-product-use-module
             'module-key
             (config-flags
              (list prototype-name ...)
              '(quoted-form ...))))))))))
