;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: pure qualification declarations and receipt verification.
;;; Build execution, scheduling, resource guards, and process receipts are
;;; owned by std/make through the ASP Build API and gerbil-bazel actions.

(export #t)

(import (only-in :clan/poo/object .o .ref object<-alist)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode))

(def +poo-flow-ac10-release-gates+
  '(scheme-canonical-fixture runtime-v0-installed-consumer
    proof-case-installed-consumer python-production-runtime
    python-proof-installed-wheel lean-build lean-ffi-smoke
    runtime-c-functional runtime-c-sanitizers runtime-c-leaks
    python-proof-functional performance-matrix))

(def (poo-flow-qualification-gate gate-id owner installed-consumer?
                                  artifact modes)
  (object<-alist
   (list (cons 'kind 'poo-flow.qualification-gate.v1)
         (cons 'gate-id gate-id)
         (cons 'owner owner)
         (cons 'installed-consumer? installed-consumer?)
         (cons 'artifact artifact)
         (cons 'modes modes))))

(def (gate-canonical gate)
  (list 'poo-flow.qualification-gate.v1
        (.ref gate 'gate-id)
        (.ref gate 'owner)
        (.ref gate 'installed-consumer?)
        (.ref gate 'artifact)
        (.ref gate 'modes)))

(def (poo-flow-qualification-gate-digest gate)
  (hex-encode
   (sha256
    (string->utf8
     (call-with-output-string
      (lambda (port) (write (gate-canonical gate) port)))))))

(def (poo-flow-agentic-control-plane-gate-registry)
  (list
   (poo-flow-qualification-gate
    'scheme-canonical-fixture 'scheme #f "canonical-fixture"
    '(focused release))
   (poo-flow-qualification-gate
    'runtime-v0-installed-consumer 'runtime-c #t
    "runtime-v0-installed-prefix" '(release))
   (poo-flow-qualification-gate
    'proof-case-installed-consumer 'runtime-c #t
    "proof-case-v1-installed-prefix" '(release))
   (poo-flow-qualification-gate
    'python-production-runtime 'python #f "python-production-suite"
    '(release))
   (poo-flow-qualification-gate
    'python-proof-installed-wheel 'python #t "isolated-proof-wheel"
    '(release))
   (poo-flow-qualification-gate
    'lean-build 'lean #f "lean-checked-artifact" '(release))
   (poo-flow-qualification-gate
    'lean-ffi-smoke 'lean #t "lean-native-ffi-smoke" '(release))
   (poo-flow-qualification-gate
    'runtime-c-functional 'runtime-c #f "runtime-c-functional" '(release))
   (poo-flow-qualification-gate
    'runtime-c-sanitizers 'runtime-c #f "runtime-c-sanitizers" '(release))
   (poo-flow-qualification-gate
    'runtime-c-leaks 'runtime-c #f "runtime-c-leaks" '(release))
   (poo-flow-qualification-gate
    'python-proof-functional 'python #f
    "python-proof-security-and-differential" '(release))
   (poo-flow-qualification-gate
    'performance-matrix 'scheme #f
    "supported-performance-cartesian-matrix" '(release))))

(def (poo-flow-qualification-gate-receipt gate source-revision accepted?
                                          evidence)
  (let ((source-revision-value source-revision)
        (accepted-value accepted?)
        (evidence-value evidence))
    (.o (kind 'poo-flow.qualification-gate-receipt.v1)
      (gate-id (.ref gate 'gate-id))
      (owner (.ref gate 'owner))
      (source-revision source-revision-value)
      (declaration-digest (poo-flow-qualification-gate-digest gate))
      (artifact (.ref gate 'artifact))
      (installed-consumer? (.ref gate 'installed-consumer?))
      (accepted? accepted-value)
      (evidence evidence-value))))

(def (poo-flow-qualification-run-receipt mode source-revision gate-receipts)
  (let ((mode-value mode)
        (source-revision-value source-revision)
        (gate-receipt-values gate-receipts))
    (.o (kind 'poo-flow.qualification-run-receipt.v1)
      (mode mode-value)
      (source-revision source-revision-value)
      (gate-receipts gate-receipt-values)
      (accepted?
       (andmap (lambda (receipt) (.ref receipt 'accepted?))
               gate-receipt-values)))))

(def (find-gate id gates)
  (find (lambda (gate) (eq? id (.ref gate 'gate-id))) gates))

(def (find-receipt id receipts)
  (find (lambda (receipt) (eq? id (.ref receipt 'gate-id))) receipts))

(def (poo-flow-qualification-verify-run registry run-receipt)
  (let* ((receipts (.ref run-receipt 'gate-receipts))
         (revision (.ref run-receipt 'source-revision))
         (release? (eq? (.ref run-receipt 'mode) 'release))
         (required (if release? +poo-flow-ac10-release-gates+
                       '(scheme-canonical-fixture)))
         (diagnostics '()))
    (def (reject! code gate-id)
      (set! diagnostics
            (cons (list (cons 'code code) (cons 'gate-id gate-id))
                  diagnostics)))
    (for-each
     (lambda (id)
       (let ((gate (find-gate id registry))
             (receipt (find-receipt id receipts)))
         (cond
          ((not gate) (reject! 'missing-gate-declaration id))
          ((not receipt) (reject! 'missing-gate-receipt id))
          ((not (equal? revision (.ref receipt 'source-revision)))
           (reject! 'stale-source-revision id))
          ((not (equal? (poo-flow-qualification-gate-digest gate)
                        (.ref receipt 'declaration-digest)))
           (reject! 'stale-gate-declaration id))
          ((not (.ref receipt 'accepted?)) (reject! 'gate-failed id))
          ((and release?
                (memq id '(runtime-v0-installed-consumer
                           proof-case-installed-consumer
                           python-proof-installed-wheel lean-ffi-smoke))
                (not (.ref receipt 'installed-consumer?)))
           (reject! 'installed-consumer-required id)))))
     required)
    (let (diagnostic-values (reverse diagnostics))
      (.o (kind 'poo-flow.qualification-verification-receipt.v1)
          (accepted? (null? diagnostic-values))
          (code (if (null? diagnostic-values) 'verified 'rejected))
          (diagnostics diagnostic-values)))))

(def (poo-flow-qualification-run-receipt->alist receipt)
  (list
   (cons 'schema 'poo-flow.qualification-run-receipt.v1)
   (cons 'mode (.ref receipt 'mode))
   (cons 'source-revision (.ref receipt 'source-revision))
   (cons 'accepted? (.ref receipt 'accepted?))
   (cons 'gates
         (map
          (lambda (gate-receipt)
            (list
             (cons 'gate-id (.ref gate-receipt 'gate-id))
             (cons 'owner (.ref gate-receipt 'owner))
             (cons 'declaration-digest
                   (.ref gate-receipt 'declaration-digest))
             (cons 'artifact (.ref gate-receipt 'artifact))
             (cons 'installed-consumer?
                   (.ref gate-receipt 'installed-consumer?))
             (cons 'accepted? (.ref gate-receipt 'accepted?))
             (cons 'evidence (.ref gate-receipt 'evidence))))
          (.ref receipt 'gate-receipts)))))

(def (poo-flow-qualification-verification-receipt->alist receipt)
  (list (cons 'schema 'poo-flow.qualification-verification-receipt.v1)
        (cons 'accepted? (.ref receipt 'accepted?))
        (cons 'code (.ref receipt 'code))
        (cons 'diagnostics (.ref receipt 'diagnostics))))
