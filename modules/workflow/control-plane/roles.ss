;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product workflow/task/runtime roles. Shared composition lives in Core.
(import (only-in :clan/poo/object .o)
        (only-in :core/composition/roles control-plane-role))

(export flow-role
        branch-role
        task-role
        strategy-role
        execution-policy-role
        run-config-role
        runner-role
        runtime-adapter-role
        receipt-role
        replay-role)

(def flow-role
  (.o (:: @ control-plane-role)
      (name 'flow)
      (kind 'declaration)
      (responsibility 'workflow-composition)
      (flow-capability 'workflow-composition)))

(def branch-role
  (.o (:: @ control-plane-role)
      (name 'branch)
      (kind 'composition)
      (responsibility 'dag-fanout-join)
      (branch-capability 'dag-fanout-join)))

(def task-role
  (.o (:: @ control-plane-role)
      (name 'task)
      (kind 'declaration)
      (responsibility 'work-intent)
      (task-capability 'work-intent)))

(def strategy-role
  (.o (:: @ control-plane-role)
      (name 'strategy)
      (kind 'policy)
      (responsibility 'execution-selection)))

(def execution-policy-role
  (.o (:: @ control-plane-role)
      (name 'execution-policy)
      (kind 'policy-envelope)
      (responsibility 'runtime-policy-handoff)
      (policy-capability 'runtime-policy-handoff)))

(def run-config-role
  (.o (:: @ control-plane-role)
      (name 'run-config)
      (kind 'configuration)
      (responsibility 'configured-runner-assembly)))

(def runner-role
  (.o (:: @ control-plane-role)
      (name 'runner)
      (kind 'interpreter)
      (responsibility 'plan-interpretation)))

(def runtime-adapter-role
  (.o (:: @ control-plane-role)
      (name 'runtime-adapter)
      (kind 'boundary)
      (responsibility 'heavy-runtime-delegation)
      (runtime-capability 'heavy-runtime-delegation)
      (runtime-owner 'rust-or-external-runtime)))

(def receipt-role
  (.o (:: @ control-plane-role)
      (name 'receipt)
      (kind 'evidence)
      (responsibility 'execution-explanation)))

(def replay-role
  (.o (:: @ control-plane-role)
      (name 'replay)
      (kind 'policy)
      (responsibility 'audit-validation)))
