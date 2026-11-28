;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Slice 52 (BUG-F5):
;;; 1. Pure functional compiler `funflow-flow->durable-dag` bridging declarative
;;;    `control-plane/flow.ss` arrows (`pure`, `scheme`, `external`, `store`,
;;;    `branch`, `try`, `kleisli`, nested flows) onto `durable-dag.ss`.
;;; 2. Concurrent multi-agent `lookup-or-wait` singleflight CAS store with
;;;    atomic temp-write-then-rename publication barrier and AuditCapsule-pinned
;;;    CAS garbage collection (preserving historical `cut = 1` forensic artifacts).

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter find every delete-duplicates/hash)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow
                 flow? flow-name flow-steps
                 branch-step? branch-step-name branch-step-left branch-step-right
                 try-step? try-step-name try-step-source
                 kleisli-step? kleisli-step-name kleisli-step-source)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/task
                 task? task-name task-kind task-request)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/durable-dag
                 PureCAS. VerifiedEpistemic. FencedEffect. ExternalSandboxProfile.
                 DurableGovernedStrategy.
                 funflow-dag-node funflow-dag-build funflow-canonical-sha256
                 funflow-admit-external-task-sandbox))

(export funflow-flow->durable-dag
        FunflowCasStore.
        make-funflow-cas-store
        funflow-cas-store?
        funflow-cas-lookup
        funflow-cas-lookup-or-wait!
        funflow-cas-pin-capsule!
        funflow-cas-pinned-keys
        funflow-cas-gc-sweep!
        funflow-cas-active-compute-count
        funflow-cas-peak-compute-count
        FunflowCasStoreExports)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

;;; ---------------------------------------------------------------------------
;;; 1. Pure Compiler: `control-plane/flow.ss` -> `durable-dag.ss`
;;; ---------------------------------------------------------------------------

(def (task-kind->effect-class kind)
  (case kind
    ((pure) PureCAS.)
    ((scheme) VerifiedEpistemic.)
    ((external store) FencedEffect.)
    (else FencedEffect.)))

(def (compile-flow-steps flow prefix-id upstream-ids source-cut env-digest
                         step-code-digests sandbox-profile counter-box nodes-box)
  (let ((next-id (lambda (base)
                   (let ((n (+ 1 (unbox counter-box))))
                     (set-box! counter-box n)
                     (string->symbol
                      (string-append prefix-id "/" (symbol->string base) "#" (number->string n)))))))
    (let loop ((steps (flow-steps flow)) (prev upstream-ids))
      (if (null? steps)
        prev
        (let ((step (car steps)))
          (cond
           ((task? step)
            (let* ((tname (task-name step))
                   (tkind (task-kind step))
                   (nid (next-id tname))
                   (eff (task-kind->effect-class tkind))
                   (code-entry (assoc tname step-code-digests))
                   (code-dig (if code-entry
                               (cdr code-entry)
                               (funflow-canonical-sha256 (list 'task-code tkind tname (task-request step)))))
                   (idem (and (memq tkind '(external store))
                              (string-append "idem:" (symbol->string nid) ":" source-cut)))
                   (sbx (and (memq tkind '(external store))
                             (or sandbox-profile
                                 (.o (:: @ ExternalSandboxProfile.)
                                     bind-these: #f
                                     env-digest: env-digest
                                     has-untrusted-input?: #f
                                     has-private-data?: #f
                                     egress-enabled?: #f
                                     egress-endorsed?: #f
                                     lease-valid?: #t))))
                   (node (funflow-dag-node nid
                                           needs: prev
                                           source-cut: source-cut
                                           step-code-digest: code-dig
                                           env-digest: env-digest
                                           input-digest: (funflow-canonical-sha256 (task-request step))
                                           effect-class: eff
                                           idempotency-key: idem
                                           sandbox-profile: sbx)))
              (set-box! nodes-box (cons node (unbox nodes-box)))
              (loop (cdr steps) (list nid))))
           ((flow? step)
            (let ((out-ids (compile-flow-steps step
                                               (string-append prefix-id "/" (symbol->string (flow-name step)))
                                               prev source-cut env-digest step-code-digests
                                               sandbox-profile counter-box nodes-box)))
              (loop (cdr steps) out-ids)))
           ((branch-step? step)
            (let* ((bname (branch-step-name step))
                   (left-ids (compile-flow-steps (branch-step-left step)
                                                 (string-append prefix-id "/" (symbol->string bname) ":L")
                                                 prev source-cut env-digest step-code-digests
                                                 sandbox-profile counter-box nodes-box))
                   (right-ids (compile-flow-steps (branch-step-right step)
                                                  (string-append prefix-id "/" (symbol->string bname) ":R")
                                                  prev source-cut env-digest step-code-digests
                                                  sandbox-profile counter-box nodes-box))
                   (join-id (next-id (string->symbol (string-append (symbol->string bname) "-join"))))
                   (join-deps (delete-duplicates/hash (append left-ids right-ids)))
                   (join-node (funflow-dag-node join-id
                                                needs: join-deps
                                                source-cut: source-cut
                                                step-code-digest: (funflow-canonical-sha256 (list 'branch-join bname))
                                                env-digest: env-digest
                                                effect-class: PureCAS.)))
              (set-box! nodes-box (cons join-node (unbox nodes-box)))
              (loop (cdr steps) (list join-id))))
           ((try-step? step)
            (let* ((tname (try-step-name step))
                   (src-ids (compile-flow-steps (try-step-source step)
                                                (string-append prefix-id "/" (symbol->string tname) ":try")
                                                prev source-cut env-digest step-code-digests
                                                sandbox-profile counter-box nodes-box))
                   (catch-id (next-id (string->symbol (string-append (symbol->string tname) "-catch"))))
                   (catch-node (funflow-dag-node catch-id
                                                 needs: src-ids
                                                 source-cut: source-cut
                                                 step-code-digest: (funflow-canonical-sha256 (list 'try-catch tname))
                                                 env-digest: env-digest
                                                 effect-class: PureCAS.)))
              (set-box! nodes-box (cons catch-node (unbox nodes-box)))
              (loop (cdr steps) (list catch-id))))
           ((kleisli-step? step)
            (let* ((kname (kleisli-step-name step))
                   (src-ids (compile-flow-steps (kleisli-step-source step)
                                                (string-append prefix-id "/" (symbol->string kname) ":kleisli")
                                                prev source-cut env-digest step-code-digests
                                                sandbox-profile counter-box nodes-box))
                   (bind-id (next-id (string->symbol (string-append (symbol->string kname) "-bind"))))
                   (bind-node (funflow-dag-node bind-id
                                                needs: src-ids
                                                source-cut: source-cut
                                                step-code-digest: (funflow-canonical-sha256 (list 'kleisli-bind kname))
                                                env-digest: env-digest
                                                effect-class: VerifiedEpistemic.)))
              (set-box! nodes-box (cons bind-node (unbox nodes-box)))
              (loop (cdr steps) (list bind-id))))
           (else
            (error "Unsupported FunFlow step during flow->durable-dag compilation" step))))))))

(def (funflow-flow->durable-dag flow
                                source-cut: (source-cut "cut-0")
                                env-digest: (env-digest "")
                                step-code-digests: (step-code-digests '())
                                sandbox-profile: (sandbox-profile #f)
                                strategy: (strategy DurableGovernedStrategy.))
  (unless (flow? flow)
    (error "funflow-flow->durable-dag expects a FunFlow flow" flow))
  (let* ((counter-box (box 0))
         (nodes-box (box '()))
         (terminal-ids (compile-flow-steps flow
                                           (symbol->string (flow-name flow))
                                           '()
                                           source-cut
                                           env-digest
                                           step-code-digests
                                           sandbox-profile
                                           counter-box
                                           nodes-box))
         (nodes (reverse (unbox nodes-box)))
         (dag (funflow-dag-build nodes strategy: strategy)))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.funflow.compiled-flow-dag.v1
        flow-name: (flow-name flow)
        valid?: (.ref dag 'valid?)
        terminal-ids: terminal-ids
        dag: dag)))

;;; ---------------------------------------------------------------------------
;;; 2. Concurrent Singleflight (`lookupOrWait`), Atomic Temp-Rename & Pinned GC
;;; ---------------------------------------------------------------------------

(defstruct cas-store-state
  (mutex root-dir entries inflight pinned-capsules nonce-counter peak-inflight)
  final: #t)

(defstruct singleflight-slot (condvar done? failed? result error) final: #t)

(.def FunflowCasStore.
  kind: 'agentic-ai-lab.funflow.cas-store.v1)

(def (safe-key-filename key)
  (let* ((s (if (string? key) key (funflow-canonical-sha256 key)))
         (h (funflow-canonical-sha256 s)))
    ;; strip "sha256:" prefix so filename is purely hex-safe
    (substring h 7 (string-length h))))

(def (make-funflow-cas-store root-dir: (root-dir #f))
  (when (and root-dir (not (file-exists? root-dir)))
    (create-directory* root-dir))
  (let ((st (make-cas-store-state
             (make-mutex 'funflow-cas-store)
             root-dir
             (make-hash-table)       ;; key -> (.o value premise-gen file-path)
             (make-hash-table)       ;; key -> singleflight-slot
             (make-hash-table)       ;; capsule-id -> list of keys
             0
             0)))
    (.o (:: @ FunflowCasStore.)
        bind-these: #f
        kind: 'agentic-ai-lab.funflow.cas-store.v1
        root-dir: root-dir
        private-state: st)))

(def (funflow-cas-store? v)
  (and (object? v)
       (.slot? v 'kind)
       (eq? (.ref v 'kind) 'agentic-ai-lab.funflow.cas-store.v1)
       (.slot? v 'private-state)
       (cas-store-state? (.ref v 'private-state))))

(def (store-state store)
  (unless (funflow-cas-store? store)
    (error "Expected FunflowCasStore" store))
  (.ref store 'private-state))

(def (funflow-cas-lookup store key)
  (let* ((st (store-state store))
         (m (cas-store-state-mutex st)))
    (mutex-lock! m)
    (let ((entry (hash-get (cas-store-state-entries st) key)))
      (mutex-unlock! m)
      entry)))

(def (funflow-cas-active-compute-count store)
  (let* ((st (store-state store))
         (m (cas-store-state-mutex st)))
    (mutex-lock! m)
    (let ((n (hash-length (cas-store-state-inflight st))))
      (mutex-unlock! m)
      n)))

(def (funflow-cas-peak-compute-count store)
  (let* ((st (store-state store))
         (m (cas-store-state-mutex st)))
    (mutex-lock! m)
    (let ((n (cas-store-state-peak-inflight st)))
      (mutex-unlock! m)
      n)))

(def (atomic-write-cas-file! root-dir key nonce value)
  (let* ((fname (safe-key-filename key))
         (final-path (path-expand (string-append fname ".cas") root-dir))
         (tmp-path (path-expand (string-append ".tmp-" fname "-" (number->string nonce)) root-dir)))
    (with-catch
     (lambda (exn)
       (when (file-exists? tmp-path)
         (with-catch void (lambda () (delete-file tmp-path))))
       (raise exn))
     (lambda ()
       (call-with-output-file tmp-path
         (lambda (port)
           (write value port)
           (newline port)
           (force-output port)))
       (rename-file tmp-path final-path)
       final-path))))

(def (funflow-cas-lookup-or-wait! store key compute-thunk
                                  premise-gen: (premise-gen 1))
  (let* ((st (store-state store))
         (m (cas-store-state-mutex st)))
    (let retry ()
      (mutex-lock! m)
      (let ((existing (hash-get (cas-store-state-entries st) key)))
        (cond
         ;; 1. Live CAS hit at matching premise generation
         ((and existing (= (.ref existing 'premise-gen) premise-gen))
          (mutex-unlock! m)
          (.o bind-these: #f
              kind: 'agentic-ai-lab.funflow.cas-lookup-result.v1
              key: key
              hit?: #t
              singleflight-waited?: #f
              premise-gen: premise-gen
              value: (.ref existing 'value)
              file-path: (.ref existing 'file-path)))
         ;; 2. Another thread is already computing this key -> wait on condvar!
         ((hash-get (cas-store-state-inflight st) key)
          => (lambda (slot)
               (let wait-loop ()
                 (if (singleflight-slot-done? slot)
                   (let ((failed? (singleflight-slot-failed? slot))
                         (res (singleflight-slot-result slot)))
                     (mutex-unlock! m)
                     (if failed?
                       ;; Prior owner crashed before atomic rename -> cleanly retry & take over!
                       (retry)
                       (.o bind-these: #f
                           kind: 'agentic-ai-lab.funflow.cas-lookup-result.v1
                           key: key
                           hit?: #t
                           singleflight-waited?: #t
                           premise-gen: premise-gen
                           value: (.ref res 'value)
                           file-path: (.ref res 'file-path))))
                   (begin
                     (mutex-unlock! m (singleflight-slot-condvar slot))
                     (mutex-lock! m)
                     (wait-loop))))))
         ;; 3. Acquire singleflight ownership for `key`, run compute outside mutex,
         ;;    stage temp file and atomically rename before publishing!
         (else
          (let* ((slot (make-singleflight-slot (make-condition-variable 'cas-sf) #f #f #f #f))
                 (nonce (+ 1 (cas-store-state-nonce-counter st))))
            (set! (cas-store-state-nonce-counter st) nonce)
            (hash-put! (cas-store-state-inflight st) key slot)
            (let ((cur (hash-length (cas-store-state-inflight st))))
              (when (> cur (cas-store-state-peak-inflight st))
                (set! (cas-store-state-peak-inflight st) cur)))
            (mutex-unlock! m)
            (with-catch
             (lambda (exn)
               (mutex-lock! m)
               (set! (singleflight-slot-failed? slot) #t)
               (set! (singleflight-slot-error slot) exn)
               (set! (singleflight-slot-done? slot) #t)
               (hash-remove! (cas-store-state-inflight st) key)
               (condition-variable-broadcast! (singleflight-slot-condvar slot))
               (mutex-unlock! m)
               (raise exn))
             (lambda ()
               (let* ((val (compute-thunk))
                      (rdir (cas-store-state-root-dir st))
                      (fpath (and rdir (atomic-write-cas-file! rdir key nonce val)))
                      (entry (.o bind-these: #f
                                 kind: 'agentic-ai-lab.funflow.cas-entry.v1
                                 key: key
                                 value: val
                                 premise-gen: premise-gen
                                 file-path: fpath)))
                 (mutex-lock! m)
                 (hash-put! (cas-store-state-entries st) key entry)
                 (set! (singleflight-slot-result slot) entry)
                 (set! (singleflight-slot-done? slot) #t)
                 (hash-remove! (cas-store-state-inflight st) key)
                 (condition-variable-broadcast! (singleflight-slot-condvar slot))
                 (mutex-unlock! m)
                 (.o bind-these: #f
                     kind: 'agentic-ai-lab.funflow.cas-lookup-result.v1
                     key: key
                     hit?: #f
                     singleflight-waited?: #f
                     premise-gen: premise-gen
                     value: val
                     file-path: fpath)))))))))))

(def (funflow-cas-pin-capsule! store capsule-id keys)
  (let* ((st (store-state store))
         (m (cas-store-state-mutex st)))
    (mutex-lock! m)
    (let* ((prior (hash-ref (cas-store-state-pinned-capsules st) capsule-id '()))
           (merged (delete-duplicates/hash (append prior keys))))
      (hash-put! (cas-store-state-pinned-capsules st) capsule-id merged)
      (mutex-unlock! m)
      (.o bind-these: #f
          kind: 'agentic-ai-lab.funflow.cas-capsule-pin.v1
          capsule-id: capsule-id
          pinned-keys: merged))))

(def (funflow-cas-pinned-keys store)
  (let* ((st (store-state store))
         (m (cas-store-state-mutex st)))
    (mutex-lock! m)
    (let ((all-pinned
           (delete-duplicates/hash
            (let loop ((rows (hash->list (cas-store-state-pinned-capsules st))) (acc '()))
              (if (null? rows) acc (loop (cdr rows) (append (cdar rows) acc)))))))
      (mutex-unlock! m)
      all-pinned)))

;; AuditCapsule-Pinned CAS GC Sweep (Slice 52 / BUG-F5):
;; Evicts ONLY entries that are NEITHER pinned by any AuditCapsule NOR active in
;; a live DAG; pinned forensic cut=1 artifacts are NEVER deleted.
(def (funflow-cas-gc-sweep! store active-keys: (active-keys '()))
  (let* ((st (store-state store))
         (m (cas-store-state-mutex st)))
    (mutex-lock! m)
    (let* ((pinned-set (make-hash-table))
           (active-set (make-hash-table))
           (evicted '())
           (preserved-pinned '()))
      (for-each
       (lambda (row)
         (for-each (lambda (k) (hash-put! pinned-set k #t)) (cdr row)))
       (hash->list (cas-store-state-pinned-capsules st)))
      (for-each (lambda (k) (hash-put! active-set k #t)) active-keys)
      (for-each
       (lambda (kv)
         (let ((k (car kv))
               (entry (cdr kv)))
           (cond
            ((hash-get pinned-set k)
             (set! preserved-pinned (cons k preserved-pinned)))
            ((hash-get active-set k)
             (void))
            (else
             (hash-remove! (cas-store-state-entries st) k)
             (let ((fp (.ref entry 'file-path)))
               (when (and fp (file-exists? fp))
                 (with-catch void (lambda () (delete-file fp)))))
             (set! evicted (cons k evicted))))))
       (hash->list (cas-store-state-entries st)))
      (let ((retained-count (hash-length (cas-store-state-entries st))))
        (mutex-unlock! m)
        (.o bind-these: #f
            kind: 'agentic-ai-lab.funflow.cas-gc-receipt.v1
            evicted-keys: (reverse evicted)
            preserved-pinned-keys: (reverse preserved-pinned)
            retained-count: retained-count)))))

(def FunflowCasStoreExports
  (.o bind-these: #f
      flow->durable-dag: funflow-flow->durable-dag
      FunflowCasStore: FunflowCasStore.
      make-cas-store: make-funflow-cas-store
      cas-store?: funflow-cas-store?
      cas-lookup: funflow-cas-lookup
      cas-lookup-or-wait!: funflow-cas-lookup-or-wait!
      cas-pin-capsule!: funflow-cas-pin-capsule!
      cas-pinned-keys: funflow-cas-pinned-keys
      cas-gc-sweep!: funflow-cas-gc-sweep!))
