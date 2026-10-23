;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Explicit Ops handoff over a checked publication; importing this file is inert.
(import :clan/poo/object
        (only-in :std/encoding/json write-json read-json)
        (only-in :std/string/misc string-subst)
        (only-in :yuanxu/ops/func run-script)
        (only-in :yuanxu/ops/progress call-with-execution-cancellation)
        (only-in :yuanxu/modules/funflow/objects Task. Job.)
        (only-in :yuanxu/modules/funflow/func run-job job-graph)
        (only-in :yuanxu/admission/publication AdmissionPublication.))
(export OpenTofuExecution. NullExecution. opentofu-execution)

;; POO is the public model; hashes exist only at the JSON output boundary.
(def (wire value)
  (cond ((object? value)
         (let (result (make-hash-table))
           (for-each (lambda (key)
                       (hash-put! result (symbol->string key) (wire (.ref value key))))
                     (.all-slots value))
           result))
        ;; Terraform JSON still interprets template markers in string values.
        ;; User data remains literal; generated reference expressions are separate.
        ((string? value)
         (string-subst (string-subst value "${" "$${") "%{" "%%{"))
        ((list? value) (map wire value))
        ((vector? value) (list->vector (map wire (vector->list value))))
        (else value)))

;; Construct one field at the JSON boundary; configuration remains a POO value.
(def (json-field key value) (list->hash-table (list (cons key value))))

;; Render the admitted receiver using the selected Provider's resource metadata.
(def (configuration job checked local?)
  (let* ((provider (.get job provider))
         (kind (.get job resource-kind))
         (resource (.ref (.get provider types resources) kind))
         (input (.get checked resource))
         (fields (wire input))
         (prefix (.get job provider-name))
         (name (.get job resource-name)))
    ;; Only this bounded local example may attach an executable provisioner.
    ;; printf receives message as data, never a shell program.
    (when local?
      (unless (and (eq? kind 'null_resource) (eq? prefix 'null))
        (error "local execution only supports null_resource"))
      (hash-put! fields "provisioner"
        (list (hash ("local-exec"
          (hash ("command" (wire (.get input triggers message)))
                ("interpreter" '("printf" "%s\n"))))))))
    (let (result
      (hash ("terraform" (hash ("required_providers"
              (json-field (symbol->string prefix)
                (hash ("source" (.get resource provider))
                      ("version" (.get resource version)))))))
            ("resource" (json-field (symbol->string kind) (json-field name fields)))))
      (unless local?
        (hash-put! result "provider"
          (json-field (symbol->string prefix) (wire (.get job provider-config)))))
      (when local?
        (hash-put! result "output"
          (hash ("message" (hash ("value"
            (string-append "${null_resource." name ".triggers.message}")))))))
      result)))

;; Task interpretation remains the existing Ops process boundary. The guards
;; protect each forward effect; cleanup uses the previously admitted command
;; even when Schema/source freshness was lost after apply started.
;; The engine belongs to the immutable output that produced this Schema.
;; Missing engines refuse before workspace writes; PATH is never a fallback.
(def (provider-command provider)
  (let (command (path-expand "engine/bin/tofu" (.get provider source value)))
    (unless (file-exists? command)
      (error "build-required: selected Provider artifact has no OpenTofu engine" command))
    (list command)))

;; Recheck package identity and source metadata at every forward-effect boundary.
;; Cleanup bypasses this guard and retains this execution's admitted command.
(def (execution-current! job)
  (when (.get job package-current) ((.get job package-current)))
  ((.get job publication context admit-current)))

;; Interpret one guarded Task through the existing Ops process boundary.
(def (run-opentofu-task task)
  (when (.get task guard-current?) (execution-current! (.get task owner)))
  (let (result (run-script task))
    (when (.get task guard-current?) (execution-current! (.get task owner)))
    result))
;; Bind command, timeout and guards to the final Funflow Task receiver.
(.def (OpenTofuTask. task [Task.])
  owner: #f arguments: '() guard-current?: #t
  command: (append (.get owner command) arguments)
  timeout: (.get owner timeout)
  environment: (.+ (.o TF_IN_AUTOMATION: "1" CHECKPOINT_DISABLE: "1") (.get owner environment))
  .run: (lambda () (run-opentofu-task task)))
;; Specialize Funflow's Task without introducing another execution protocol.
(def (execution-task owner-value arguments-value dependencies)
  (.cc OpenTofuTask. 'owner owner-value 'arguments arguments-value 'needs dependencies))

;; Check the selected closure, including exceptional cleanup, before writes.
;; Arguments may be refined, but Task command/owner overrides cannot silently
;; detach execution from the Provider artifact admitted for this receiver.
(def (admit-execution-tasks! job projection)
  (for-each
    (lambda (name)
      (let (task (.ref (.get job tasks) name))
        (unless (and (.slot? task 'owner) (eq? (.get task owner) job)
                     (.slot? task 'arguments)
                     (equal? (.get task command)
                       (append (.get job command) (.get task arguments))))
          (error "OpenTofu Task must use the selected execution and engine" name))))
    (append (.get projection order) (.get projection finalizers))))

;; One publication-bound Job owns all forward Tasks and its cleanup Task.
(.def (OpenTofuExecution. execution [Job.])
  name: 'opentofu
  publication: #f previous: (.o)
  command: (if provider (provider-command provider) '())
  package-current: #f
  ;; Linking captures identities only. Resolving publication here would re-enter
  ;; the active scope; its lazy slot is first demanded after linking completes.
  .bind-publication:
  (lambda (selection owner name current!)
    ;; Derived executions share this binding's selected export metadata. The
    ;; promise caches construction only: publish and every forward Task still
    ;; run their live source/package guards and validate the current receiver.
    ;; A different selection/binding receives a different promise.
    (let (selected-publication
           (delay
             (begin
               (unless current!
                 (error "build-required: selected OpenTofu packages are not prepared"))
               (.call AdmissionPublication. .for-export selection owner name))))
      (.o (:: @ execution)
        package-current: current!
        publication: (force selected-publication))))
  timeout: 20 environment: (.o)
  provider: #f provider-name: #f provider-config: (.o)
  resource-kind: #f resource-name: "example"
  selected: (if (eq? provider-name 'null) '(output) '(validate))
  finalizers: (if (eq? provider-name 'null) '(destroy) '())
  tasks:
  (.o init: (execution-task execution '("init" "-backend=false" "-input=false" "-no-color") '())
      validate: (execution-task execution '("validate" "-no-color") '(init))
      plan: (execution-task execution '("plan" "-input=false" "-no-color" "-out=hello.tfplan") '(validate))
      apply: (execution-task execution '("apply" "-input=false" "-no-color" "hello.tfplan") '(plan))
      output: (execution-task execution '("output" "-json" "message") '(apply))
      destroy: (.cc (execution-task execution '("destroy" "-auto-approve" "-input=false" "-no-color") '())
                 'after-start 'apply 'guard-current? #f))
  ;; One Ops cancellation extent owns preflight, Tasks and finalizers. Nested
  ;; process calls reuse its registration, including cleanup after a refusal.
  .run:
  (lambda (workspace)
    (call-with-execution-cancellation
      (lambda () (run-execution execution workspace)))))

;; Null is a bounded recipe of the same execution protocol, not a service Module.
(.def (NullExecution. @ OpenTofuExecution. message)
  message: "hello from Agentic AI Lab"
  resource: (let (text message) (.o triggers: (.o message: text)))
  provider-name: 'null resource-kind: 'null_resource resource-name: "hello")

;; Admit the final derived receiver before rendering or starting any process.
(def (run-execution job work-directory)
  (def publication (.get job publication))
  (unless publication (error "selected publication must be bound before execution"))
  (let (baseline (.get publication value))
    (unless (and (eq? (.get job provider) (.get baseline provider))
                 (eq? (.get job resource-kind) (.get baseline resource-kind))
                 (eq? (.get job provider-name) (.get baseline provider-name))
                 (equal? (.get job command) (.get baseline command)))
      (error "execution provider must match the selected publication")))
  ;; Reject detached Tasks before expensive live package admission. This is
  ;; pure preflight, not approval; publication still validates and guards the
  ;; candidate. If validation returns another receiver, check its closure too.
  (def input-projection (job-graph job))
  (admit-execution-tasks! job input-projection)
  (defvalues (admission-evidence checked failure)
    (.call publication .publish (.get job previous) job))
  (when failure (error "OpenTofu input admission refused" failure))
  (def local? (eq? (.get checked provider-name) 'null))
  (def projection (if (eq? checked job) input-projection (job-graph checked)))
  (unless (eq? checked job) (admit-execution-tasks! checked projection))
  ;; This AWS example performs configuration validation, never plan or apply.
  (unless (or local? (every (cut memq <> '(init validate)) (.get projection order)))
    (error "AWS example only permits init and validate"))
  (def document (configuration checked checked local?))
  (unless (and (string? work-directory) (file-exists? work-directory)
               (pair? (.get checked command)))
    (error "execution requires an existing workspace and selected OpenTofu command"))
  (unless (null? (directory-files work-directory))
    (error "OpenTofu example workspace must be empty" work-directory))
  (execution-current! checked)
  (call-with-output-file (path-expand "main.tf.json" work-directory)
    (lambda (port) (write-json port document)))
  (def outcome (run-job checked work-directory))
  (execution-current! checked)
  (def final-steps (.get outcome steps))
  (def output-value
    (and local? (.slot? final-steps 'output)
      (call-with-input-string (.get final-steps output output) read-json)))
  (.o kind: (if local? 'local-execution-completed 'configuration-validated)
      value: checked evidence: admission-evidence steps: final-steps
      graph: projection flow-receipt: (.get outcome flow-receipt) output: output-value))

;; Existing platform binding: workspaces are supplied only to Job.run.
(def (opentofu-execution selection owner name)
  (let (publication (.call AdmissionPublication. .for-export selection owner name))
    (.cc (.get publication value) 'publication publication
         'package-current (.get selection package-current))))
