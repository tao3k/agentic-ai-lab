;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: sandbox resource bindings live in this domain module.
;;; Boundary: backend extensions consume these POO data objects and project them
;;; into Docker, Cube, nono, or Marlin-specific request shapes.
;;; Invariant: this module never starts a sandbox, opens ports, mounts paths, or
;;; resolves store items; it only preserves declarative resource intent.

(import :agentic-ai-lab/modules/agent-sandbox/projection-syntax)

(export +sandbox-volume-modes+
        +sandbox-port-protocols+
        +sandbox-env-sources+
        make-sandbox-volume-binding
        sandbox-volume-binding?
        sandbox-volume-binding-store-item
        sandbox-volume-binding-mount-path
        sandbox-volume-binding-mode
        sandbox-volume-binding-read-only?
        make-sandbox-port-binding
        sandbox-port-binding?
        sandbox-port-binding-name
        sandbox-port-binding-container-port
        sandbox-port-binding-host-port
        sandbox-port-binding-protocol
        make-sandbox-env-binding
        sandbox-env-binding?
        sandbox-env-binding-name
        sandbox-env-binding-value
        sandbox-env-binding-source
        make-sandbox-resource-set
        sandbox-resource-set?
        sandbox-resource-set-volumes
        sandbox-resource-set-ports
        sandbox-resource-set-env
        make-empty-sandbox-resource-set
        sandbox-volume-binding->request
        sandbox-port-binding->request
        sandbox-env-binding->request
        sandbox-volume-bindings->request
        sandbox-port-bindings->request
        sandbox-env-bindings->request
        sandbox-resource-set->request
        sandbox-volume-bindings-merge
        sandbox-port-bindings-merge
        sandbox-env-bindings-merge
        sandbox-resource-set-merge)

;;; Boundary: volume modes are backend-neutral filesystem grants. Docker can
;;; derive read-only flags, while Cube and nono can preserve symbolic modes.
;; : [Symbol]
(def +sandbox-volume-modes+
  '(read write read-write))

;;; Boundary: port protocols stay declarative so Marlin decides whether a
;;; backend can actually expose or forward a requested network endpoint.
;; : [Symbol]
(def +sandbox-port-protocols+
  '(tcp udp))

;;; Boundary: environment sources distinguish literal values from values a
;;; runtime must resolve from secret/config stores.
;; : [Symbol]
(def +sandbox-env-sources+
  '(literal secret config runtime))

;;; Sandbox volume bindings describe a store item mounted at a sandbox path.
;;; Backend projection owns provider flags and path resolution.
;; : (-> StoreItem MountPath Symbol SandboxVolumeBinding)
(defstruct sandbox-volume-binding
  (store-item
   mount-path
   mode)
  transparent: #t)

;;; Sandbox port bindings describe a desired container endpoint. Host port may
;;; be false when the runtime should allocate or map provider-side ports.
;; : (-> Symbol Integer (U Integer #f) Symbol SandboxPortBinding)
(defstruct sandbox-port-binding
  (name
   container-port
   host-port
   protocol)
  transparent: #t)

;;; Sandbox env bindings keep value source explicit so secret/config resolution
;;; does not leak into user-facing flow composition.
;; : (-> Symbol Value Symbol SandboxEnvBinding)
(defstruct sandbox-env-binding
  (name
   value
   source)
  transparent: #t)

;;; Resource sets are the reusable POO aggregate passed between sandbox-backed
;;; extensions before any backend-specific request projection.
;; : (-> [SandboxVolumeBinding] [SandboxPortBinding] [SandboxEnvBinding] SandboxResourceSet)
(defstruct sandbox-resource-set
  (volumes
   ports
   env)
  transparent: #t)

;;; Boundary: empty resource sets are the monoidal zero for sandbox resource
;;; composition across Docker, nono, and Cube setup layers.
;; : (-> Unit SandboxResourceSet)
(def (make-empty-sandbox-resource-set)
  (make-sandbox-resource-set '() '() '()))

;;; Boundary: Docker read-only flags are a backend projection of neutral
;;; sandbox volume modes, not a separate binding type.
;; : (-> SandboxVolumeBinding Boolean)
(def (sandbox-volume-binding-read-only? binding)
  (eq? (sandbox-volume-binding-mode binding) 'read))

;;; Boundary: shared volume request data includes both neutral mode and Docker's
;;; derived read-only flag so backend adapters can choose their native field.
;; : (-> SandboxVolumeBinding Alist)
(def (sandbox-volume-binding->request binding)
  (agent-sandbox-field-rows
   (store-item (sandbox-volume-binding-store-item binding))
   (mount-path (sandbox-volume-binding-mount-path binding))
   (mode (sandbox-volume-binding-mode binding))
   (read-only? (sandbox-volume-binding-read-only? binding))))

;;; Boundary: port request data is neutral enough for Docker port publishing,
;;; Cube network declarations, and nono sandbox request projection.
;; : (-> SandboxPortBinding Alist)
(def (sandbox-port-binding->request binding)
  (agent-sandbox-field-rows
   (name (sandbox-port-binding-name binding))
   (container-port (sandbox-port-binding-container-port binding))
   (host-port (sandbox-port-binding-host-port binding))
   (protocol (sandbox-port-binding-protocol binding))))

;;; Boundary: env request data keeps the source tag attached to the value so
;;; runtime adapters can resolve secrets without Scheme-side IO.
;; : (-> SandboxEnvBinding Alist)
(def (sandbox-env-binding->request binding)
  (agent-sandbox-field-rows
   (name (sandbox-env-binding-name binding))
   (value (sandbox-env-binding-value binding))
   (source (sandbox-env-binding-source binding))))

;;; Boundary: sequence projection stays a pure map over POO bindings; backend
;;; adapters receive plain request data after this edge.
;; : (forall (a) (-> [SandboxVolumeBinding] [a]))
;; : (-> [SandboxVolumeBinding] [Alist])
(def (sandbox-volume-bindings->request bindings)
  (map sandbox-volume-binding->request bindings))

;;; Boundary: port projection is shared by sandbox backends and avoids each
;;; extension open-coding the same request field names.
;; : (forall (a) (-> [SandboxPortBinding] [a]))
;; : (-> [SandboxPortBinding] [Alist])
(def (sandbox-port-bindings->request bindings)
  (map sandbox-port-binding->request bindings))

;;; Boundary: env projection is shared by sandbox backends and preserves source
;;; metadata through the runtime handoff.
;; : (forall (a) (-> [SandboxEnvBinding] [a]))
;; : (-> [SandboxEnvBinding] [Alist])
(def (sandbox-env-bindings->request bindings)
  (map sandbox-env-binding->request bindings))

;;; Boundary: resource-set projection is report-only request data, not sandbox
;;; setup; execution remains in Rust/Marlin runtime adapters.
;; : (-> SandboxResourceSet Alist)
(def (sandbox-resource-set->request resource-set)
  (agent-sandbox-field-rows
   (volumes
    (sandbox-volume-bindings->request
     (sandbox-resource-set-volumes resource-set)))
   (ports
    (sandbox-port-bindings->request
     (sandbox-resource-set-ports resource-set)))
   (env
    (sandbox-env-bindings->request
     (sandbox-resource-set-env resource-set)))))

;;; Boundary: sandbox volume mount seen predicate is the policy-visible edge
;;; for sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> MountPath [SandboxVolumeBinding] Boolean)
(def (sandbox-volume-mount-seen? mount bindings)
  (cond
   ((not mount) #f)
   ((null? bindings) #f)
   ((equal? mount (sandbox-volume-binding-mount-path (car bindings))) #t)
   (else (sandbox-volume-mount-seen? mount (cdr bindings)))))

;;; Boundary: volume merge is left-biased by mount path so earlier composition
;;; layers keep priority when several sandbox modules bind the same path.
;; : (-> [SandboxVolumeBinding] [SandboxVolumeBinding] [SandboxVolumeBinding] [SandboxVolumeBinding])
(def (sandbox-volume-bindings-merge/rev seen right additions-rev)
  (if (null? right)
    additions-rev
    (let (binding (car right))
      (if (sandbox-volume-mount-seen?
           (sandbox-volume-binding-mount-path binding)
           seen)
        (sandbox-volume-bindings-merge/rev seen (cdr right) additions-rev)
        (sandbox-volume-bindings-merge/rev
         (cons binding seen)
         (cdr right)
         (cons binding additions-rev))))))

;; : (-> [SandboxVolumeBinding] [SandboxVolumeBinding] [SandboxVolumeBinding])
(def (sandbox-volume-bindings-merge left right)
  (agent-sandbox-rows/tail
   left
   (reverse (sandbox-volume-bindings-merge/rev left right '()))))

;;; Boundary: sandbox port seen predicate is the policy-visible edge for
;;; sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> SandboxPortBinding [SandboxPortBinding] Boolean)
(def (sandbox-port-seen? binding bindings)
  (cond
   ((null? bindings) #f)
   ((and (equal? (sandbox-port-binding-container-port binding)
                 (sandbox-port-binding-container-port (car bindings)))
         (equal? (sandbox-port-binding-protocol binding)
                 (sandbox-port-binding-protocol (car bindings))))
    #t)
   (else (sandbox-port-seen? binding (cdr bindings)))))

;;; Boundary: port merge is left-biased by container port and protocol, which
;;; matches provider behavior where one endpoint cannot have two meanings.
;; : (-> [SandboxPortBinding] [SandboxPortBinding] [SandboxPortBinding] [SandboxPortBinding])
(def (sandbox-port-bindings-merge/rev seen right additions-rev)
  (if (null? right)
    additions-rev
    (let (binding (car right))
      (if (sandbox-port-seen? binding seen)
        (sandbox-port-bindings-merge/rev seen (cdr right) additions-rev)
        (sandbox-port-bindings-merge/rev
         (cons binding seen)
         (cdr right)
         (cons binding additions-rev))))))

;; : (-> [SandboxPortBinding] [SandboxPortBinding] [SandboxPortBinding])
(def (sandbox-port-bindings-merge left right)
  (agent-sandbox-rows/tail
   left
   (reverse (sandbox-port-bindings-merge/rev left right '()))))

;;; Boundary: sandbox env name seen predicate is the policy-visible edge for
;;; sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol [SandboxEnvBinding] Boolean)
(def (sandbox-env-name-seen? name bindings)
  (cond
   ((null? bindings) #f)
   ((equal? name (sandbox-env-binding-name (car bindings))) #t)
   (else (sandbox-env-name-seen? name (cdr bindings)))))

;;; Boundary: env merge is left-biased by variable name so outer policy can
;;; deliberately override inner module defaults.
;; : (-> [SandboxEnvBinding] [SandboxEnvBinding] [SandboxEnvBinding] [SandboxEnvBinding])
(def (sandbox-env-bindings-merge/rev seen right additions-rev)
  (if (null? right)
    additions-rev
    (let (binding (car right))
      (if (sandbox-env-name-seen? (sandbox-env-binding-name binding) seen)
        (sandbox-env-bindings-merge/rev seen (cdr right) additions-rev)
        (sandbox-env-bindings-merge/rev
         (cons binding seen)
         (cdr right)
         (cons binding additions-rev))))))

;; : (-> [SandboxEnvBinding] [SandboxEnvBinding] [SandboxEnvBinding])
(def (sandbox-env-bindings-merge left right)
  (agent-sandbox-rows/tail
   left
   (reverse (sandbox-env-bindings-merge/rev left right '()))))

;;; Boundary: full resource-set merge composes the three reusable sandbox axes
;;; without knowing which backend will later consume the request.
;; : (-> SandboxResourceSet SandboxResourceSet SandboxResourceSet)
(def (sandbox-resource-set-merge left right)
  (make-sandbox-resource-set
   (sandbox-volume-bindings-merge
    (sandbox-resource-set-volumes left)
    (sandbox-resource-set-volumes right))
   (sandbox-port-bindings-merge
    (sandbox-resource-set-ports left)
    (sandbox-resource-set-ports right))
   (sandbox-env-bindings-merge
    (sandbox-resource-set-env left)
    (sandbox-resource-set-env right))))
