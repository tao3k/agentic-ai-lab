;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Final inert projection for the existing semantic C ABI. Scheme application
;;; composition installs one runtime service reference; this is not a Session
;;; registry, a Context factory or a second owner of lifecycle state.
(import (only-in :clan/poo/object .o .ref .call)
        (only-in :agentic-ai-lab/modules/durable/agenda durable-agenda-start)
        (only-in :agentic-ai-lab/modules/query/org-agenda org-agenda-occurrences)
        :agentic-ai-lab/modules/ai-agentic-context/runtime-service)
(export semantic-context-install! context-lifecycle-command
        context-lifecycle-inspect context-lifecycle-shutdown)

(def installed-service #f)
(def installed-thread #f)

(def (semantic-context-install! service)
  (unless (and (not installed-service)
               (eq? (.ref service 'kind) 'context.runtime-service.v1))
    (error "Expected one unbound runtime Context service"))
  ;; Only runtime application initialization can attach the actual capability.
  ;; No C command reconstructs an observation or installs a service from bytes.
  (set! installed-thread (current-thread))
  (set! installed-service service)
  #t)

(def (current-service)
  (unless (and installed-service (eq? installed-thread (current-thread)))
    (error "Context service is unbound or called from a foreign runtime thread"))
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
  ;; A copied receipt reports the runtime decision. Historical publication is
  ;; never a current proof, an observation capability or an external effect grant.
  (hash (schema "agentic-ai-lab.context-service-decision.v1")
        (id (.ref decision 'identity)) (accepted (.ref decision 'accepted?))
        (runtimeResultPublished (.ref decision 'runtime-result-published?))
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

(def (agenda-permission ids)
  (unless (and (list? ids) (<= (length ids) 256)
               (andmap (lambda (id) (and (string? id) (< 0 (string-length id) 257))) ids))
    (error "Invalid Agenda authorization snapshot"))
  (lambda (item) (member (.ref item 'identity) ids)))

(def (agenda-command object)
  (let (operation (field object "operation"))
    (cond
      ((equal? operation "open")
       (unless (and (= (hash-length object) 7) (not installed-service))
         (error "Expected an unopened Agenda and exact input fields"))
       (let ((source (field object "source")) (journal (field object "journal"))
             (offset (field object "offsetMinutes")) (action (field object "action"))
             (authorized? (agenda-permission (field object "authorizedIds"))))
         (unless (and (string? source) (string? journal) (exact-integer? offset) (<= -840 offset 840)
                      (string? action) (< 0 (string-length action) 129))
           (error "Invalid Agenda deployment"))
         (let (service (durable-agenda-start
                         (.o (source) journal-path: journal (offset)
                             (authorized?) (action) query: org-agenda-occurrences)))
           (semantic-context-install! service)
           (hash (scheduled (context-service-agenda! service (lambda (agenda) (.call agenda .refresh! agenda #f))))))))
      ((and (= (hash-length object) 3) (equal? operation "refresh"))
       (let (allowed (agenda-permission (field object "authorizedIds")))
         (hash (scheduled (context-service-agenda! (current-service)
                            (lambda (agenda) (.call agenda .refresh! agenda allowed)))))))
      ((and (= (hash-length object) 2) (equal? operation "take"))
       (let (handoff (context-service-agenda! (current-service) (lambda (agenda) (.call agenda .take! agenda))))
         (if handoff
           (hash (dispatch #t) (key (.ref handoff 'key)) (identity (.ref handoff 'identity)) (due (.ref handoff 'due)) (action (.ref handoff 'action)))
           (hash (dispatch #f)))))
      (else (error "Unsupported Agenda command")))))

(def (context-lifecycle-command object)
  (if (equal? (field object "schema") "agentic-ai-lab.agenda-request.v1")
    (agenda-command object)
    (session-lifecycle-command object)))

(def (session-lifecycle-command object)
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
              (let (runtime-operation
                     (cond ((equal? operation "result") 'result)
                           ((equal? operation "cancel") 'cancel)
                           ((equal? operation "recover") 'recover)
                           (else (error "Unsupported Context command"))))
                (context-service-command (field object "id") runtime-operation
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
