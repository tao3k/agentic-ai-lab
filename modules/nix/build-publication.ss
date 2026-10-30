;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Restore from a governed Nix Source, never a candidate-selected release pin.
(import :clan/poo/object
        (only-in "./func.ss" agentic-ai-lab-nix-verify-store)
        (only-in :yuanxu/module-system/source/admission module-source-type module-source-admit-current!)
        (only-in :yuanxu/module-system/building/artifacts
          accept-build-artifact-handoff! read-build-artifact-handoff
          admit-build-artifacts! invalidate-build-artifacts!))
(export agentic-ai-lab-nix-restore-build-publication!)
(def (agentic-ai-lab-nix-restore-build-publication! source graph)
  (with-catch
    (lambda (failure) (invalidate-build-artifacts! graph) (raise failure))
    (lambda ()
      ((.get graph compiler-current))
      ;; A receiver-local native publication owns the derivation and its source
      ;; observations. This guard intentionally does not close over the Graph.
      (def observations (.get source source-inputs))
      (def publication (.call source .prepare (cut module-source-admit-current! observations)))
      ((.get publication admit-current))
      (def root (.get publication artifact))
      (def executable (.get source config realize))
      (def (approved-current!)
        (agentic-ai-lab-nix-verify-store executable root)
        ((.get publication admit-current)))
      (approved-current!)
      (def asset (path-expand "issuance.ss" root))
      (unless (eq? (module-source-type asset) 'regular)
        (error "approved Core issuance must be a regular file" asset))
      (def packet (call-with-input-file asset
        (lambda (port)
          (parameterize ((current-input-port port)) (read-build-artifact-handoff)))))
      (def inputs (list-ref packet 2))
      (def input-index (make-hash-table))
      (for-each
        (lambda (row)
          (when (and (hash-key? input-index (car row))
                     (not (equal? (hash-ref input-index (car row)) (cdr row))))
            (error "inconsistent approved source observations" (car row)))
          (hash-put! input-index (car row) (cdr row))) inputs)
      ;; Packet compiler roots may include retained build tools. They must cover
      ;; EVERY input of this current selected Graph, and all packet inputs must
      ;; remain current. They cannot substitute their own source observations.
      (unless (every (lambda (row) (and (hash-key? input-index (car row))
                                      (equal? (hash-ref input-index (car row)) (cdr row))))
                     (.get graph compiler-inputs))
        (error "approved publication omits or replaces selected source"))
      (def (current!)
        ((.get graph compiler-current))
        (module-source-admit-current! inputs))
      (current!)
      (def projection (.o build-graph: graph compiler-identities: (list-ref packet 1)
                         source-inputs: inputs admit-current: current!))
      (call-with-input-string (call-with-output-string (cut write packet <>))
        (lambda (port)
          (parameterize ((current-input-port port))
            (accept-build-artifact-handoff! projection (list-ref packet 3)
              (cut module-source-admit-current! observations) approved-current!))))
      ;; Retain the same approval boundary in saved .publish and hot admission.
      (admit-build-artifacts! graph))))
