;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Pure descriptor composition has no source resolution, diagnostics or runtime
;;; acquisition dependency. The legacy activation owner delegates here.
(import :yuanxu/modules/funflow/control-plane/task
        :yuanxu/modules/funflow/control-plane/flow
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        (only-in :yuanxu/object-family/syntax defpoo-object-family))
(export agentic-ai-lab-module-activation-prototype
        make-agentic-ai-lab-module-activation
        agentic-ai-lab-module-activation?
        agentic-ai-lab-module-activation-modules
        agentic-ai-lab-module-activation-task-registry
        agentic-ai-lab-module-activation-flow-registry
        agentic-ai-lab-module-activation-options
        activate-agentic-ai-lab-modules
        activate-agentic-ai-lab-modules-with-base)

;;; Boundary: activation appends descriptor contributions without mutation.
;; : (-> [PooModuleDescriptor] TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist PooModuleActivation)
(defpoo-object-family
  (prototype agentic-ai-lab-module-activation-prototype
             activation?
             agentic-ai-lab-module-activation?)
  (constructor make-agentic-ai-lab-module-activation
               (modules-value modules)
               (task-registry-value task-registry)
               (flow-registry-value flow-registry)
               (options-value options))
  (accessors
   (agentic-ai-lab-module-activation-modules modules)
   (agentic-ai-lab-module-activation-task-registry task-registry)
   (agentic-ai-lab-module-activation-flow-registry flow-registry)
   (agentic-ai-lab-module-activation-options options))
  (projections))

;;; Boundary: activation validates closure then appends base-first registries.
;;; Intent: runtime-visible registries are deterministic snapshots of module data.
;; : (-> [PooModuleDescriptor] TaskFamilyRegistry FlowDeclarationRegistry ModuleOptionAlist PooModuleActivation)
(def (activate-agentic-ai-lab-modules-with-base modules base-task-registry base-flow-registry base-options)
  (let (closed-modules (agentic-ai-lab-module-closure modules))
    ;; Import validation must see the same closure that registry aggregation uses.
    (validate-yuanxu-module-imports closed-modules)
    (make-agentic-ai-lab-module-activation
     closed-modules
     (make-task-family-registry
      (task-family-registry-name base-task-registry)
      ;; Base descriptors stay first so existing lookup behavior is preserved.
      (append (task-family-registry-descriptors base-task-registry)
              (agentic-ai-lab-module-all-task-descriptors closed-modules)))
     (make-flow-declaration-registry
      (flow-declaration-registry-name base-flow-registry)
      (append (flow-declaration-registry-descriptors base-flow-registry)
             (agentic-ai-lab-module-all-flow-descriptors closed-modules)))
     (append base-options
             (agentic-ai-lab-module-all-options closed-modules)
             (list (cons 'agentic-ai-lab-modules
                         (agentic-ai-lab-module-names closed-modules)))))))

;;; Boundary: default activation uses project default task and flow registries.
;; : (-> [PooModuleDescriptor] PooModuleActivation)
(def (activate-agentic-ai-lab-modules modules)
  (activate-agentic-ai-lab-modules-with-base
   modules
   default-task-family-registry
   default-flow-declaration-registry
   '()))
