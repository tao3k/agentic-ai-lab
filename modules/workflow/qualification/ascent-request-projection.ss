;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Inert POO projection. MRR owns identity parsing, receipt format, and admission.
(import (only-in :clan/poo/object .o .ref))

(export poo-flow-ascent-project-request)

(def (nonempty-string? value)
  (and (string? value) (> (string-length value) 0)))

(def (positive-exact-integer? value)
  (and (exact-integer? value) (> value 0)))

(def (poo-flow-ascent-project-request declaration)
  (let ((bundle (.ref declaration 'mrr-bundle-identity))
        (pack (.ref declaration 'mrr-rule-pack-identity))
        (generation (.ref declaration 'mrr-generation-identity))
        (epoch (.ref declaration 'organization-epoch))
        (capability (.ref declaration 'capability-identity))
        (input-bound (.ref declaration 'max-input-facts))
        (pair-bound (.ref declaration 'max-derived-pairs))
        (result-bound (.ref declaration 'max-results)))
    (unless (and (nonempty-string? bundle)
                 (nonempty-string? pack)
                 (nonempty-string? generation))
      (error "Ascent request requires opaque MRR identities"))
    (unless (and (positive-exact-integer? epoch)
                 (nonempty-string? capability)
                 (positive-exact-integer? input-bound)
                 (positive-exact-integer? pair-bound)
                 (positive-exact-integer? result-bound))
      (error "Ascent request requires capability, epoch, and positive bounds"))
    (.o kind: 'poo-flow.ascent-evaluation-request
        mrr-bundle-identity: bundle
        mrr-rule-pack-identity: pack
        mrr-generation-identity: generation
        organization-epoch: epoch
        capability-identity: capability
        max-input-facts: input-bound
        max-derived-pairs: pair-bound
        max-results: result-bound
        runtime-executed?: #f)))
