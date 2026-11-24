;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: workflow CI/CD POO check and check-map values.
;;; Invariant: constructors admit declared values but never execute commands.

(import (only-in :clan/poo/object .o .ref object? object<-alist)
        (only-in :std/list/list every)
        "check-types.ss"
        "projection-syntax.ss")

(export yuanxu-cicd-check
        yuanxu-cicd-check?
        yuanxu-cicd-check-map
        yuanxu-cicd-check-map?
        yuanxu-cicd-check-name
        yuanxu-cicd-check-profile
        yuanxu-cicd-check-command
        yuanxu-cicd-check-dependency-refs
        yuanxu-cicd-check-durable-task-id
        yuanxu-cicd-check-action-class
        yuanxu-cicd-check-compensation-refs
        yuanxu-cicd-check-artifact-retention
        yuanxu-cicd-check-artifacts
        yuanxu-cicd-check-cache
        yuanxu-cicd-check-secrets
        yuanxu-cicd-check-runtime
        yuanxu-cicd-check-map-name
        yuanxu-cicd-check-map-checks)

(def (yuanxu-cicd-require-list field value)
  (yuanxu-cicd-require
   (string-append "cicd check " field " must be a list")
   (list? value)
   value))

(def (yuanxu-cicd-check name profile command inputs config artifacts cache
                          secrets result runtime . maybe-metadata)
  (yuanxu-cicd-require "cicd check name must be a symbol" (symbol? name) name)
  (yuanxu-cicd-require
   "cicd check profile must be a symbol, POO object, or non-empty list of refs"
   (yuanxu-cicd-profile-ref? profile) profile)
  (yuanxu-cicd-require "cicd check command must be a non-empty string list"
                         (yuanxu-cicd-command-vector? command) command)
  (yuanxu-cicd-require-list "inputs" inputs)
  (yuanxu-cicd-require-list "config" config)
  (yuanxu-cicd-require-list "artifacts" artifacts)
  (yuanxu-cicd-require-list "cache" cache)
  (yuanxu-cicd-require-list "secrets" secrets)
  (yuanxu-cicd-require-list "result" result)
  (yuanxu-cicd-require "cicd check runtime must be a symbol"
                         (symbol? runtime) runtime)
  (object<-alist
   (yuanxu-cicd-field-rows
    (kind (yuanxu-cicd-check-kind))
    (schema +yuanxu-cicd-check-map-schema+)
    (check-name name)
    (profile-ref profile)
    (command-vector command)
    (input-bindings inputs)
    (config-sources config)
    (artifact-outputs artifacts)
    (cache-intents cache)
    (secret-requirements secrets)
    (result-protocol result)
    (runtime-mode runtime)
    (runtime-executed #f)
    (metadata (if (null? maybe-metadata) '() (car maybe-metadata))))))

(def (yuanxu-cicd-check? value)
  (and (object? value)
       (eq? (.ref value 'kind) (yuanxu-cicd-check-kind))))
(def (yuanxu-cicd-check-name check) (.ref check 'check-name))
(def (yuanxu-cicd-check-profile check) (.ref check 'profile-ref))
(def (yuanxu-cicd-check-command check) (.ref check 'command-vector))

(def (yuanxu-cicd-check-metadata-ref check key default)
  (let (entry (assoc key (.ref check 'metadata)))
    (if entry (cdr entry) default)))

(def (yuanxu-cicd-check-dependency-refs check)
  (let (refs (yuanxu-cicd-check-metadata-ref check 'dependency-refs '()))
    (yuanxu-cicd-require
     "cicd check dependency-refs must be a list of symbols"
     (yuanxu-cicd-symbol-list? refs) refs)
    refs))

(def (yuanxu-cicd-check-durable-task-id check)
  (let (task-id (yuanxu-cicd-check-metadata-ref
                 check 'durable-task-id (yuanxu-cicd-check-name check)))
    (yuanxu-cicd-require "cicd check durable-task-id must be a symbol"
                           (symbol? task-id) task-id)
    task-id))

(def (yuanxu-cicd-check-action-class check)
  (let (action-class
        (yuanxu-cicd-check-metadata-ref check 'action-class 'idempotent))
    (yuanxu-cicd-require
     "cicd check action-class must be a known durable action class"
     (and (symbol? action-class)
          (member action-class +yuanxu-durable-action-classes+))
     action-class)
    action-class))

(def (yuanxu-cicd-check-compensation-refs check)
  (let (refs (yuanxu-cicd-check-metadata-ref check 'compensation-refs '()))
    (yuanxu-cicd-require
     "cicd check compensation-refs must be a list of symbols"
     (yuanxu-cicd-symbol-list? refs) refs)
    refs))

(def (yuanxu-cicd-check-artifact-retention check)
  (let (retention
        (yuanxu-cicd-check-metadata-ref
         check 'artifact-retention 'workflow-retained))
    (yuanxu-cicd-require "cicd check artifact-retention must be a symbol"
                           (symbol? retention) retention)
    retention))

(def (yuanxu-cicd-check-artifacts check) (.ref check 'artifact-outputs))
(def (yuanxu-cicd-check-cache check) (.ref check 'cache-intents))
(def (yuanxu-cicd-check-secrets check) (.ref check 'secret-requirements))
(def (yuanxu-cicd-check-runtime check) (.ref check 'runtime-mode))

(def (yuanxu-cicd-check-map name checks . maybe-metadata)
  (yuanxu-cicd-require "cicd check-map name must be a symbol"
                         (symbol? name) name)
  (yuanxu-cicd-require "cicd check-map checks must be a list"
                         (list? checks) checks)
  (yuanxu-cicd-require "cicd check-map checks must contain only cicd checks"
                         (every yuanxu-cicd-check? checks) checks)
  (.o kind: (yuanxu-cicd-check-map-kind)
      schema: +yuanxu-cicd-check-map-schema+
      map-name: name
      check-objects: checks
      runtime-executed: #f
      metadata: (if (null? maybe-metadata) '() (car maybe-metadata))))

(def (yuanxu-cicd-check-map? value)
  (and (object? value)
       (eq? (.ref value 'kind) (yuanxu-cicd-check-map-kind))))
(def (yuanxu-cicd-check-map-name check-map) (.ref check-map 'map-name))
(def (yuanxu-cicd-check-map-checks check-map) (.ref check-map 'check-objects))
