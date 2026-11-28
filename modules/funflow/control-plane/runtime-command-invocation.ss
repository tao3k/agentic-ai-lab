;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime command invocation and response normalization.
;;; Invariant: command execution is adapter-owned; descriptors live elsewhere.

(import :tao3k/agentic-ai-lab/modules/funflow/control-plane/projection-syntax
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-protocol
        (only-in :clan/poo/object .cc .get .call .o .ref .slot? object?)
        (only-in :tao3k/yuanxu/ops/objects ProcessScript.)
        (only-in :tao3k/yuanxu/ops/func run-script))

(export RuntimeCommandContract RuntimeArguments
        make-runtime-command
        runtime-command?
        runtime-command-name
        runtime-command-kind
        runtime-command-invoker
        runtime-command-metadata
        make-procedure-runtime-command
        make-process-runtime-command
        runtime-command-read-response
        make-stdout-runtime-command
        runtime-command-call
        runtime-command-result
        runtime-command-failure-response
        runtime-command-field-rows/tail)

;;; Runtime commands describe the replaceable command/IPC boundary behind the
;;; Rust adapter. The current Scheme tests can install a procedure command;
;;; later Rust or process-backed commands should keep this call shape stable.
;; : (-> Symbol Symbol Invoker Alist RuntimeCommand)
(def RuntimeCommandContract
  (Record runtime-command?: (list (Exactly #t)) name: (list Symbol) kind: (list Symbol)
          invoker: (list (Fun RuntimeResponseLike <- RuntimeEnvelope)) metadata: (list RuntimeMetadata)))
(def RuntimeArguments (Union (List String) (Fun (List String) <- RuntimeEnvelope)))
(def (make-runtime-command name kind invoker metadata)
  (validate RuntimeCommandContract
    (.o bind-these: #f runtime-command?: #t name: name kind: kind invoker: invoker metadata: metadata)))
(def (runtime-command? value)
  (and (object? value) (.slot? value 'runtime-command?) (.ref value 'runtime-command?)))
(def (runtime-command-name value) (.ref value 'name))
(def (runtime-command-kind value) (.ref value 'kind))
(def (runtime-command-invoker value) (.ref value 'invoker))
(def (runtime-command-metadata value) (.ref value 'metadata))

;; make-procedure-runtime-command
;;   : (forall (metadata) (-> Symbol Invoker [metadata] RuntimeCommand))
;;   : (-> Symbol Invoker MetadataList RuntimeCommand)
;;   : (-> Symbol Invoker [Alist] RuntimeCommand)
;;   | doc m%
;;       Build a procedure-backed runtime command with optional metadata rows.
;;
;;       # Examples
;;       ```scheme
;;       (runtime-command-kind
;;        (make-procedure-runtime-command 'noop (lambda args 'ok)))
;;       ;; => procedure
;;       ```
;;     %
(def (make-procedure-runtime-command name invoker . maybe-metadata)
  (make-runtime-command name
                        'procedure
                        invoker
                        (if (null? maybe-metadata) '() (car maybe-metadata))))

;; : (-> Symbol Alist Alist)
(defpoo-core-receipt-projection
  runtime-command-error (code detail)
  (bindings ())
  (fields ((code code)
           (detail detail))))

;; : (-> Alist Symbol Value Alist RuntimeResponseLike)
(defpoo-core-receipt-projection
  runtime-command-failure-response (envelope code detail metadata)
  (bindings ())
  (fields ((schema +runtime-response-schema+)
           (request-id (runtime-alist-ref envelope 'request-id #f))
           (status 'failed)
           (value #f)
           (artifact-handle
            (runtime-alist-ref envelope 'artifact-handle #f))
           (error (runtime-command-error code detail))
           (metadata metadata))))

;;; Runtime command row assembly is a projection-only helper. It keeps row
;;; ordering explicit at call sites while avoiding a second runtime adapter DSL.
;; runtime-command-rows/tail
;;   : (forall (k v) (-> [(Pair k v)] [(Pair k v)] [(Pair k v)]))
;;   : (-> List Alist Alist)
;;   | contract: ordered runtime-command projection rows followed by tail rows
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (runtime-command-rows/tail '((name . rust)) '((metadata)))
;;       ;; => ((name . rust) (metadata))
;;       ```
;;     %
(def (runtime-command-rows/tail rows tail)
  (append rows tail))

;; runtime-command-field-rows/tail
;;   : (-> Alist RuntimeCommandFieldRow... Alist)
;;   | contract: lower runtime-command field clauses and append caller-owned tail rows
;;   | result: ordered runtime-command field rows followed by the supplied tail alist
;;   | doc m%
;;       `runtime-command-field-rows/tail` lowers fixed field clauses into
;;       ordered runtime-command rows and appends caller-owned tail metadata
;;       without introducing a second runtime adapter DSL.
;;
;;       # Examples
;;       ```scheme
;;       (runtime-command-field-rows/tail '((tail . value)) (name 'rust))
;;       ;; => ((name . rust) (tail . value))
;;       ```
;;     %
(defrules runtime-command-field-rows/tail ()
  ((_ tail (field value) ...)
   (runtime-command-rows/tail
    (list (cons 'field value) ...)
    tail)))

;; make-process-runtime-command
;;   : (forall (metadata) (-> Symbol Path ArgumentsBuilder ResponseDecoder [metadata] RuntimeCommand))
;;   : (-> Symbol Path ArgumentsBuilder ResponseDecoder MetadataList RuntimeCommand)
;;   : (-> Symbol Path ArgumentsBuilder ResponseDecoder [Alist] RuntimeCommand)
;;   | doc m%
;;       Build a process-backed runtime command with explicit argument and
;;       response decoder boundaries.
;;
;;       # Examples
;;       ```scheme
;;       (runtime-command-kind
;;        (make-process-runtime-command 'cat "/bin/cat" (lambda args args) read))
;;       ;; => process
;;       ```
;;     %
(def (make-process-runtime-command name executable arguments response-decoder . maybe-metadata)
  (def checked-arguments (validate RuntimeArguments arguments))
  (def decode (validate (Fun RuntimeResponseLike <- RuntimeEnvelope String) response-decoder))
  (let (metadata
        (runtime-command-field-rows/tail
         (if (null? maybe-metadata) '() (car maybe-metadata))
         (executable executable)))
    (make-runtime-command
     name
     'process
     (lambda (envelope)
       (let* ((argv (cons executable
                          (if (procedure? checked-arguments)
                            (checked-arguments envelope)
                            checked-arguments)))
              (script (.cc ProcessScript. 'command argv))
              (stdout (.get (run-script script stderr-redirection: #f) output)))
         (decode envelope stdout)))
     metadata)))

;;; Stdout protocol commands print one runtime-response s-expression. This keeps
;;; process-backed tests close to the future Rust CLI contract without forcing
;;; each caller to install a custom decoder.
;; : (forall (response) (-> Alist String response))
;; : (-> Alist String RuntimeResponseLike)
;; : (-> Alist String RuntimeResponseLike)
(def (runtime-command-read-response envelope stdout)
  (with-catch
   (lambda (failure)
     (runtime-command-failure-response envelope
                                       'invalid-runtime-command-stdout
                                       failure
                                       '()))
   (lambda ()
     (call-with-input-string stdout read))))

;; make-stdout-runtime-command
;;   : (forall (metadata) (-> Symbol Path ArgumentsBuilder [metadata] RuntimeCommand))
;;   : (-> Symbol Path ArgumentsBuilder MetadataList RuntimeCommand)
;;   : (-> Symbol Path ArgumentsBuilder [Alist] RuntimeCommand)
;;   | doc m%
;;       Build a process runtime command that decodes stdout as a Scheme value.
;;
;;       # Examples
;;       ```scheme
;;       (runtime-command-kind
;;        (make-stdout-runtime-command 'echo "/bin/echo" (lambda args args)))
;;       ;; => process
;;       ```
;;     %
(def (make-stdout-runtime-command name executable arguments . maybe-metadata)
  (apply make-process-runtime-command
         name
         executable
         arguments
         runtime-command-read-response
         maybe-metadata))

;; : (-> RuntimeCommandCandidate Alist RuntimeResponseLike)
(def (runtime-command-call command envelope)
  ((runtime-command-invoker (validate RuntimeCommandContract command)) envelope))

;;; Runtime command invocation is the narrow process/IPC boundary: the command
;;; sees one stable request envelope and must return a normalizable response.
;; : (forall (result) (-> RuntimeCommand Alist result))
;; : (-> RuntimeCommand Alist AdapterResult)
;; : (-> RuntimeCommand Alist AdapterResult)
(def (runtime-command-result command envelope)
  (with-catch
   (lambda (failure)
     (make-adapter-result
      (runtime-alist-ref envelope 'request-id #f)
      'failed
      #f
      (runtime-alist-ref envelope 'artifact-handle #f)
      (list (cons 'code 'runtime-command-error)
            (cons 'error failure))))
   (lambda ()
     (normalize-runtime-response envelope (runtime-command-call command envelope)))))
