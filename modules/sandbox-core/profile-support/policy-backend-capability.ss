;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: backend capability policy describes sandbox provider capabilities
;;; before nano, docker, cube, or native runtime adapters consume them.
;;; Invariant: capability objects must stay parser-visible and POO-native for
;;; shared sandbox profile inheritance.

(import :gerbil/core
        (only-in :clan/poo/object object<-alist object? .slot? .ref)
        :agentic-ai-lab/modules/sandbox-core/profile-support/projection-syntax
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-core)

(export agentic-ai-lab-sandbox-backend-capability
        agentic-ai-lab-sandbox-backend-capability?
        agentic-ai-lab-sandbox-backend-capability/backend-kind
        agentic-ai-lab-sandbox-backend-capability/capabilities
        agentic-ai-lab-sandbox-backend-capability-supports?
        agentic-ai-lab-sandbox-backend-capability-registry
        agentic-ai-lab-sandbox-backend-capability-registry?
        agentic-ai-lab-sandbox-backend-capability-registry-entries
        agentic-ai-lab-sandbox-backend-capability-registry-aliases
        agentic-ai-lab-sandbox-backend-capability-registry-default
        agentic-ai-lab-sandbox-backend-capability-registry-extend
        agentic-ai-lab-sandbox-backend-capability-registry-merge
        agentic-ai-lab-sandbox-backend-capability-registry-canonical-kind
        agentic-ai-lab-sandbox-backend-capability-registry-ref
        agentic-ai-lab-sandbox-backend-capability/sandbox
        agentic-ai-lab-sandbox-backend-capability/nono
        agentic-ai-lab-sandbox-backend-capability/cube
        agentic-ai-lab-sandbox-backend-capability/docker
        agentic-ai-lab-sandbox-backend-capability-registry/sandbox-core
        agentic-ai-lab-sandbox-backend-capability-registry/default
        agentic-ai-lab-sandbox-backend-capability-registry-put-entries
        agentic-ai-lab-sandbox-backend-capability-registry-put-entries/index
        agentic-ai-lab-sandbox-backend-capability-registry-put-entries/kept
        agentic-ai-lab-sandbox-backend-capability-registry-put-entries/materialize
        agentic-ai-lab-sandbox-backend-capability-ref)

;; agentic-ai-lab-sandbox-backend-capability
;;   : (-> Symbol [Symbol] [Alist] PooSandboxBackendCapability)
;;   | contract: build a POO backend capability descriptor from normalized slots
;;   | result: backend capability policy object used by registry validation
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability 'nono '(read) '())
;;       ;; => sandbox backend capability object
;;       ```
;;     %
;; : (-> Symbol [CapabilitySymbol] [Alist] PooSandboxBackendCapability)
;;; Backend capability objects are the sandbox policy extension boundary.
;;; - Keep registry aliases and default backend resolution explicit before profile validation consumes them.
;; : (-> Symbol List List Object)
(def (agentic-ai-lab-sandbox-backend-capability backend-kind
                                          capabilities
                                          . maybe-options)
  (let (options (if (null? maybe-options) '() (car maybe-options)))
    (object<-alist
     (agentic-ai-lab-sandbox-profile-field-rows
      (kind agentic-ai-lab-sandbox-backend-capability-kind)
      (backend-kind backend-kind)
      (isolation
       (agentic-ai-lab-sandbox-profile-policy-option options 'isolation 'process))
      (capabilities capabilities)
      (supports-command
       (agentic-ai-lab-sandbox-profile-policy-option options 'supports-command #t))
      (supports-filesystem
       (agentic-ai-lab-sandbox-profile-policy-option options 'supports-filesystem #t))
      (supports-code-interpreter
       (agentic-ai-lab-sandbox-profile-policy-option
        options
        'supports-code-interpreter
        #f))
      (supports-network
       (agentic-ai-lab-sandbox-profile-policy-option options 'supports-network #f))
      (supports-persistence
       (agentic-ai-lab-sandbox-profile-policy-option
        options
        'supports-persistence
        #f))
      (max-sandboxes
       (agentic-ai-lab-sandbox-profile-policy-option options 'max-sandboxes #f))
      (cold-start-ms-p50
       (agentic-ai-lab-sandbox-profile-policy-option options 'cold-start-ms-p50 #f))
      (availability
       (agentic-ai-lab-sandbox-profile-policy-option
        options
        'availability
        '((mode . static) (runtime-executed . #f))))
      (metadata
       (agentic-ai-lab-sandbox-profile-policy-option options 'metadata '()))))))

;; agentic-ai-lab-sandbox-backend-capability?
;;   : (-> SandboxPolicyCandidate Boolean)
;;   | contract: recognize POO backend capability policy objects
;;   | result: #t only for values carrying the backend capability kind id
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability? '())
;;       ;; => #f
;;       ```
;;     %
;; : (-> SandboxPolicyCandidate Boolean)
(def (agentic-ai-lab-sandbox-backend-capability? value)
  (agentic-ai-lab-sandbox-policy-object-kind?
   value
   agentic-ai-lab-sandbox-backend-capability-kind))

;; : (-> PooSandboxBackendCapability Symbol)
(def (agentic-ai-lab-sandbox-backend-capability/backend-kind capability)
  (.ref capability 'backend-kind))

;; : (-> PooSandboxBackendCapability [Symbol])
(def (agentic-ai-lab-sandbox-backend-capability/capabilities capability)
  (.ref capability 'capabilities))

;; : (-> PooSandboxBackendCapability Symbol Boolean)
(def (agentic-ai-lab-sandbox-backend-capability-supports? capability required)
  (and (member required
               (agentic-ai-lab-sandbox-backend-capability/capabilities capability))
       #t))

;; : (-> [Alist] [Alist] POOObject)
(def (agentic-ai-lab-sandbox-backend-capability-registry entries . maybe-options)
  (let (options (if (null? maybe-options) '() (car maybe-options)))
    (object<-alist
     (list
      (cons 'kind agentic-ai-lab-sandbox-backend-capability-registry-kind)
      (cons 'entries entries)
      (cons 'aliases
            (agentic-ai-lab-sandbox-profile-policy-option options 'aliases '()))
      (cons 'default-capability
            (agentic-ai-lab-sandbox-profile-policy-option
             options
             'default-capability
             #f))
      (cons 'metadata
            (agentic-ai-lab-sandbox-profile-policy-option options 'metadata '()))))))

;; agentic-ai-lab-sandbox-backend-capability-registry?
;;   : (-> SandboxBackendCapabilityRegistryCandidate Boolean)
;;   | contract: recognize POO backend capability registry objects
;;   | result: #t only for registry objects with the registry kind id
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry? '())
;;       ;; => #f
;;       ```
;;     %
;; : (-> SandboxBackendCapabilityRegistryCandidate Boolean)
(def (agentic-ai-lab-sandbox-backend-capability-registry? value)
  (agentic-ai-lab-sandbox-policy-object-kind?
   value
   agentic-ai-lab-sandbox-backend-capability-registry-kind))

;; : (-> PooSandboxBackendCapabilityRegistry [Alist])
(def (agentic-ai-lab-sandbox-backend-capability-registry-entries registry)
  (if (agentic-ai-lab-sandbox-backend-capability-registry? registry)
    (.ref registry 'entries)
    '()))

;; : (-> PooSandboxBackendCapabilityRegistry [Alist])
(def (agentic-ai-lab-sandbox-backend-capability-registry-aliases registry)
  (if (agentic-ai-lab-sandbox-backend-capability-registry? registry)
    (.ref registry 'aliases)
    '()))

;; agentic-ai-lab-sandbox-backend-capability-registry-default-slot
;;   : (-> PooSandboxBackendCapabilityRegistry MaybeSandboxBackendCapability)
;;   | contract: read the default capability slot when a registry is valid
;;   | result: default capability value or #f for invalid/missing registries
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-default-slot '())
;;       ;; => #f
;;       ```
;;     %
;; : (-> PooSandboxBackendCapabilityRegistry MaybeSandboxBackendCapability)
(def (agentic-ai-lab-sandbox-backend-capability-registry-default-slot registry)
  (if (and (agentic-ai-lab-sandbox-backend-capability-registry? registry)
           (.slot? registry 'default-capability))
    (.ref registry 'default-capability)
    #f))

;; : (-> PooSandboxBackendCapabilityRegistry PooSandboxBackendCapability)
(def (agentic-ai-lab-sandbox-backend-capability-registry-default registry)
  (let (default-capability
        (agentic-ai-lab-sandbox-backend-capability-registry-default-slot registry))
    (if default-capability
      default-capability
      agentic-ai-lab-sandbox-backend-capability/sandbox)))

;; : (-> PooSandboxBackendCapabilityRegistry [Alist])
(def (agentic-ai-lab-sandbox-backend-capability-registry-metadata registry)
  (if (and (agentic-ai-lab-sandbox-backend-capability-registry? registry)
           (.slot? registry 'metadata))
    (.ref registry 'metadata)
    '()))

;; : (-> Alist Alist Alist)
(def (agentic-ai-lab-sandbox-backend-capability-registry-put-entries entries extra)
  (if (null? extra)
    entries
    (let* ((latest (make-hash-table))
           (ordered-extra-keys
            (agentic-ai-lab-sandbox-backend-capability-registry-put-entries/index
             (reverse extra)
             latest
             (make-hash-table)
             '()))
           (kept-entries
            (agentic-ai-lab-sandbox-backend-capability-registry-put-entries/kept
             entries
             latest
             '())))
      (agentic-ai-lab-sandbox-profile-rows/tail
       kept-entries
       (agentic-ai-lab-sandbox-backend-capability-registry-put-entries/materialize
        ordered-extra-keys
        latest
	       '())))))

;; : (-> Object Boolean)
(def (agentic-ai-lab-sandbox-backend-capability-registry-entry? entry)
  (pair? entry))

;; : (-> Pair Symbol)
(def (agentic-ai-lab-sandbox-backend-capability-registry-entry-key entry)
  (car entry))

;; : (-> Alist HashTable HashTable [Symbol] [Symbol])
(def (agentic-ai-lab-sandbox-backend-capability-registry-put-entries/index reversed-extra
                                                                     latest
                                                                     seen
                                                                     ordered)
  (cond
   ((null? reversed-extra) ordered)
   ((not (agentic-ai-lab-sandbox-backend-capability-registry-entry?
          (car reversed-extra)))
    (agentic-ai-lab-sandbox-backend-capability-registry-put-entries/index
     (cdr reversed-extra)
     latest
     seen
     ordered))
   (else
    (let (entry-key (agentic-ai-lab-sandbox-backend-capability-registry-entry-key
                     (car reversed-extra)))
      (if (hash-get seen entry-key)
        (agentic-ai-lab-sandbox-backend-capability-registry-put-entries/index
         (cdr reversed-extra)
         latest
         seen
         ordered)
        (begin
          (hash-put! seen entry-key #t)
          (hash-put! latest entry-key (car reversed-extra))
          (agentic-ai-lab-sandbox-backend-capability-registry-put-entries/index
	           (cdr reversed-extra)
	           latest
	           seen
	           (cons entry-key ordered))))))))

;; : (forall (e) (-> [e] HashTable [e] [e]))
;; : (-> Alist HashTable Alist Alist)
(def (agentic-ai-lab-sandbox-backend-capability-registry-put-entries/kept entries
                                                                  latest
                                                                  result)
  (agentic-ai-lab-sandbox-profile-rows/tail
   result
   (filter
    (lambda (entry)
      (not
       (and (agentic-ai-lab-sandbox-backend-capability-registry-entry? entry)
            (hash-get
             latest
             (agentic-ai-lab-sandbox-backend-capability-registry-entry-key entry)))))
    entries)))

;; : (forall (k e) (-> [k] HashTable [e] [e]))
;; : (-> [Symbol] HashTable Alist Alist)
(def (agentic-ai-lab-sandbox-backend-capability-registry-put-entries/materialize keys
                                                                          latest
                                                                          result)
  (agentic-ai-lab-sandbox-profile-rows/tail
   result
   (map (lambda (key) (hash-get latest key)) keys)))

;; : (-> PooSandboxBackendCapabilityRegistry [Alist] [Alist] POOObject)
(def (agentic-ai-lab-sandbox-backend-capability-registry-extend registry
                                                          entries
                                                          .
                                                          maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (aliases (agentic-ai-lab-sandbox-profile-policy-option
                   options
                   'aliases
                   '()))
         (metadata (agentic-ai-lab-sandbox-profile-policy-option
                    options
                    'metadata
                    '()))
         (default-capability
          (if (agentic-ai-lab-sandbox-profile-policy-option? options
                                                       'default-capability)
            (agentic-ai-lab-sandbox-profile-policy-option
             options
             'default-capability
             #f)
            (agentic-ai-lab-sandbox-backend-capability-registry-default-slot
             registry))))
    (agentic-ai-lab-sandbox-backend-capability-registry
     (agentic-ai-lab-sandbox-backend-capability-registry-put-entries
      (agentic-ai-lab-sandbox-backend-capability-registry-entries registry)
      entries)
     (list
      (cons 'aliases
            (agentic-ai-lab-sandbox-backend-capability-registry-put-entries
             (agentic-ai-lab-sandbox-backend-capability-registry-aliases registry)
             aliases))
      (cons 'default-capability default-capability)
      (cons 'metadata
            (agentic-ai-lab-sandbox-profile-rows/tail
             (agentic-ai-lab-sandbox-backend-capability-registry-metadata registry)
             metadata))))))

;; : (-> PooSandboxBackendCapabilityRegistry PooSandboxBackendCapabilityRegistry POOObject)
(def (agentic-ai-lab-sandbox-backend-capability-registry-merge base extension)
  (let (extension-default
        (agentic-ai-lab-sandbox-backend-capability-registry-default-slot extension))
    (agentic-ai-lab-sandbox-backend-capability-registry-extend
     base
     (agentic-ai-lab-sandbox-backend-capability-registry-entries extension)
     (agentic-ai-lab-sandbox-profile-field-rows/tail
      (if extension-default
        (agentic-ai-lab-sandbox-profile-field-rows
         (default-capability extension-default))
        '())
      (aliases
       (agentic-ai-lab-sandbox-backend-capability-registry-aliases
        extension))
      (metadata
       (agentic-ai-lab-sandbox-backend-capability-registry-metadata
        extension))))))

;; agentic-ai-lab-sandbox-backend-capability-registry-canonical-kind
;;   : (-> PooSandboxBackendCapabilityRegistry Symbol Symbol)
;;   | contract: resolve backend capability aliases to canonical registry keys
;;   | result: canonical backend kind when an alias exists, otherwise input kind
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-canonical-kind registry 'nono)
;;       ;; => nono
;;       ```
;;     %
;; : (-> PooSandboxBackendCapabilityRegistry Symbol Symbol)
(def (agentic-ai-lab-sandbox-backend-capability-registry-canonical-kind registry
                                                                  backend-kind)
  (let (entry
        (assoc backend-kind
               (agentic-ai-lab-sandbox-backend-capability-registry-aliases
                registry)))
    (if entry (cdr entry) backend-kind)))

;; agentic-ai-lab-sandbox-backend-capability-registry-ref
;;   : (-> PooSandboxBackendCapabilityRegistry Symbol PooSandboxBackendCapability)
;;   | contract: resolve a backend capability through aliases and defaults
;;   | result: matched capability object or the registry default capability
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-registry-ref registry 'nono)
;;       ;; => sandbox backend capability object
;;       ```
;;     %
;; : (-> PooSandboxBackendCapabilityRegistry Symbol PooSandboxBackendCapability)
(def (agentic-ai-lab-sandbox-backend-capability-registry-ref registry backend-kind)
  (let* ((canonical-kind
          (agentic-ai-lab-sandbox-backend-capability-registry-canonical-kind
           registry
           backend-kind))
         (entry
          (assoc canonical-kind
                 (agentic-ai-lab-sandbox-backend-capability-registry-entries
                  registry))))
    (if entry
      (cdr entry)
      (agentic-ai-lab-sandbox-backend-capability-registry-default registry))))

;; agentic-ai-lab-sandbox-backend-capability/sandbox
;;   : POOObject
;;   | doc m%
;;       Static POO capability object for the neutral sandbox backend.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability/backend-kind
;;        agentic-ai-lab-sandbox-backend-capability/sandbox)
;;       ;; => sandbox
;;       ```
(def agentic-ai-lab-sandbox-backend-capability/sandbox
  (agentic-ai-lab-sandbox-backend-capability
   'sandbox
   '(process process-run filesystem filesystem-read filesystem-write tmpdir
             cache-mount)
   '((isolation . process)
     (supports-command . #t)
     (supports-filesystem . #t)
     (metadata . ((scope . sandbox-core))))))

;; agentic-ai-lab-sandbox-backend-capability-registry/sandbox-core
;;   : POOObject
;;   | doc m%
;;       Minimal sandbox-core registry contribution. Module-system catalogs
;;       start from this object and merge backend-module contributions from
;;       enabled modules.
(def agentic-ai-lab-sandbox-backend-capability-registry/sandbox-core
  (agentic-ai-lab-sandbox-backend-capability-registry
   (list (cons 'sandbox agentic-ai-lab-sandbox-backend-capability/sandbox))
   '((metadata . ((scope . sandbox-core)
                  (runtime-executed . #f))))))

;; agentic-ai-lab-sandbox-backend-capability/nono
;;   : POOObject
;;   | doc m%
;;       Static POO capability object for the native nono sandbox backend.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability/backend-kind
;;        agentic-ai-lab-sandbox-backend-capability/nono)
;;       ;; => nono
;;       ```
(def agentic-ai-lab-sandbox-backend-capability/nono
  (agentic-ai-lab-sandbox-backend-capability
   'nono
   '(process process-run filesystem filesystem-read filesystem-write tmpdir
             cache-mount)
   '((isolation . user-process)
     (supports-command . #t)
     (supports-filesystem . #t)
     (cold-start-ms-p50 . 10)
     (metadata . ((scope . nono-sandbox) (binding . native-ffi))))))

;; agentic-ai-lab-sandbox-backend-capability/cube
;;   : POOObject
;;   | doc m%
;;       Static POO capability object for the Cube sandbox backend.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability/backend-kind
;;        agentic-ai-lab-sandbox-backend-capability/cube)
;;       ;; => cube
;;       ```
(def agentic-ai-lab-sandbox-backend-capability/cube
  (agentic-ai-lab-sandbox-backend-capability
   'cube
   '(process-run filesystem-read cache-mount snapshot kvm-isolation)
   '((isolation . kvm)
     (supports-command . #t)
     (supports-filesystem . #t)
     (supports-network . #t)
     (cold-start-ms-p50 . 500)
     (metadata . ((scope . cubeSandbox))))))

;; agentic-ai-lab-sandbox-backend-capability/docker
;;   : POOObject
;;   | doc m%
;;       Static POO capability object for the Docker sandbox backend.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability/backend-kind
;;        agentic-ai-lab-sandbox-backend-capability/docker)
;;       ;; => docker
;;       ```
(def agentic-ai-lab-sandbox-backend-capability/docker
  (agentic-ai-lab-sandbox-backend-capability
   'docker
   '(process-run filesystem-read filesystem-write tmpdir image-runtime
                 cache-mount)
   '((isolation . container)
     (supports-command . #t)
     (supports-filesystem . #t)
     (supports-network . #t)
     (supports-persistence . #t)
     (cold-start-ms-p50 . 1000)
     (metadata . ((scope . docker-sandbox))))))

;; agentic-ai-lab-sandbox-backend-capability-registry/default
;;   : POOObject
;;   | doc m%
;;       Default static backend capability registry. Backend modules can later
;;       contribute registry objects through the module-system extension path
;;       without changing capability lookup call sites.
;;
;;       # Examples
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability/backend-kind
;;        (agentic-ai-lab-sandbox-backend-capability-registry-ref
;;         agentic-ai-lab-sandbox-backend-capability-registry/default
;;         'cubeSandbox))
;;       ;; => cube
;;       ```
(def agentic-ai-lab-sandbox-backend-capability-registry/default
  (agentic-ai-lab-sandbox-backend-capability-registry-extend
   agentic-ai-lab-sandbox-backend-capability-registry/sandbox-core
   (list
    (cons 'nono agentic-ai-lab-sandbox-backend-capability/nono)
    (cons 'cube agentic-ai-lab-sandbox-backend-capability/cube)
    (cons 'docker agentic-ai-lab-sandbox-backend-capability/docker))
   '((aliases . ((cubeSandbox . cube)))
     (default-capability . #f)
     (metadata . ((scope . sandbox-core)
                  (runtime-executed . #f))))))

;; agentic-ai-lab-sandbox-backend-capability-ref
;;   : (-> Symbol PooSandboxBackendCapability)
;;   | contract: resolve a backend capability from the default registry
;;   | result: backend capability object for the requested backend kind
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-backend-capability-ref 'nono)
;;       ;; => sandbox backend capability object
;;       ```
;;     %
;; : (-> Symbol PooSandboxBackendCapability)
(def (agentic-ai-lab-sandbox-backend-capability-ref backend-kind)
  (agentic-ai-lab-sandbox-backend-capability-registry-ref
   agentic-ai-lab-sandbox-backend-capability-registry/default
   backend-kind))
