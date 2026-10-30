;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Final inert projection for the existing semantic C ABI. Scheme application
;;; composition installs one native service reference; this is not a Session
;;; registry, a Context factory or a second owner of lifecycle state.
(import (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/ai-agentic-context/runtime-service)
(export semantic-context-install! context-lifecycle-command
        context-lifecycle-inspect context-lifecycle-shutdown)

(def installed-service #f)
(def installed-thread #f)

(def (semantic-context-install! service)
  (unless (and (not installed-service)
               (eq? (.ref service 'kind) 'context.runtime-service.v1))
    (error "Expected one unbound native Context service"))
  ;; Only native application initialization can attach the actual capability.
  ;; No C command reconstructs an observation or installs a service from bytes.
  (set! installed-thread (current-thread))
  (set! installed-service service)
  #t)

(def (current-service)
  (unless (and installed-service (eq? installed-thread (current-thread)))
    (error "Context service is unbound or called from a foreign native thread"))
  installed-service)

(def (field object key)
  (unless (and (hash-table? object) (hash-key? object key))
    (error "Missing Context ABI field" key))
  (hash-ref object key))

(def (fields object names)
  (unless (and (hash-table? object) (= (hash-length object) (length names)))
    (error "Unexpected Context ABI fields"))
  (for-each (lambda (key) (field object key)) names)
  (unless (equal? (field object "schema") "agentic-ai-lab.context-service-request.v1")
    (error "Unsupported Context ABI schema")))

(def (project decision)
  ;; A copied receipt reports the native decision. Historical publication is
  ;; never a current proof, an observation capability or an external effect grant.
  (hash (schema "agentic-ai-lab.context-service-decision.v1")
        (id (.ref decision 'identity)) (accepted (.ref decision 'accepted?))
        (nativeResultPublished (.ref decision 'native-result-published?))
        (historical (.ref decision 'historical?))
        (reason (symbol->string (.ref decision 'reason)))
        (contextState (symbol->string (.ref decision 'context-state)))
        (revision (.ref decision 'revision)) (terminalCount (.ref decision 'terminal-count))
        (actionAuthorized #f)))

(def (context-lifecycle-inspect object)
  (fields object '("schema" "id" "session" "ownerEpoch"))
  (project (context-service-dispatch! (current-service)
    (context-service-command (field object "id") 'inspect (field object "session")
      0 0 (field object "ownerEpoch") #f))))

(def (context-lifecycle-command object)
  (let* ((operation (field object "operation"))
         (command
           (cond
             ((equal? operation "grant-revocation")
              (fields object '("schema" "id" "operation" "grant" "expected" "ownerEpoch"))
              (context-service-grant-command (field object "id") (field object "grant")
                (field object "expected") (field object "ownerEpoch")))
             (else
              (fields object '("schema" "id" "operation" "session" "revision"
                               "generation" "ownerEpoch" "observation"))
              (let (native-operation
                     (cond ((equal? operation "result") 'result)
                           ((equal? operation "cancel") 'cancel)
                           ((equal? operation "recover") 'recover)
                           (else (error "Unsupported Context command"))))
                (context-service-command (field object "id") native-operation
                  (field object "session") (field object "revision")
                  (field object "generation") (field object "ownerEpoch")
                  (field object "observation")))))))
    (project (context-service-dispatch! (current-service) command))))

(def (context-lifecycle-shutdown object)
  (unless (and (hash-table? object) (= (hash-length object) 0))
    (error "Context shutdown takes no replacement state"))
  (when installed-service
    ;; Close/join must succeed before the capability is forgotten or the C
    ;; facade tears down the VM. A failed drain remains available for diagnosis.
    (context-service-close! (current-service))
    (set! installed-service #f)
    (set! installed-thread #f))
  (hash (schema "agentic-ai-lab.context-service-closed.v1")
        (closed #t) (actionAuthorized #f)))
