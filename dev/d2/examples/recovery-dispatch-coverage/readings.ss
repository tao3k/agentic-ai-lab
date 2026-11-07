;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative D2 scene facts.
(import :clan/poo/object)
(export DesignReadings)
(def DesignReadings (.o inspections: (list (.o identity: 'final-reading view: 'recovery-dispatch-coverage revision: 'design source-cut: 'sha256-d0910e85da44d52b6c51eec932177344fd3a0c7659b2d444cdc765cad270d8bf image-sha: "a48bb205942f04797dd8cc33b2a15544c985eac40affcbf8f1f601a5af08469e" question: 'when-can-we-count producer: 'current-model response: "I viewed the revised PNG. Both views use the same A and B rows. A's Replay marker stays in place, while B's dashed empty ranges become sealed filled ranges. The B sealed relation distinguishes qualified coverage from mere arrival. The completed view reads One distinct replay; Count assessed qualifies the link to the exact-one revision. The first view keeps Count open, so the picture separates coverage, assessment and admission. B and v2 remain visible behind v3. The short labels are legible and the arrows explain changes in evidence and support. This is a scoped model reading.")
  (.o identity: 'second-reading view: 'recovery-dispatch-coverage revision: 'design source-cut: 'sha256-d0910e85da44d52b6c51eec932177344fd3a0c7659b2d444cdc765cad270d8bf image-sha: "820d1cc994e6016782c4510ffc34363a31f98729dd9b27df142aab08ebb51ff6" question: 'when-can-we-count producer: 'current-model response: "I viewed the revised PNG. Both views use the same A and B rows. A's Replay marker stays in place, while B's dashed empty ranges become sealed filled ranges. The B sealed relation distinguishes qualified coverage from mere arrival. The completed view reads One distinct replay; Count assessed qualifies the link to the exact-one revision. The first view keeps Count open, so the picture separates coverage, assessment and admission. B and v2 remain visible behind v3. The arrows explain changes in evidence and support. The measured Replay and Missing labels are below the reader size target, so enlarge those local labels. This is a scoped model reading.")
  (.o identity: 'first-reading view: 'recovery-dispatch-coverage revision: 'design source-cut: 'sha256-d0910e85da44d52b6c51eec932177344fd3a0c7659b2d444cdc765cad270d8bf image-sha: "6253c6dc14f2cf9c9846443c160d6c7de4eb132883cf51d59e7e73fdc97798b3" question: 'when-can-we-count producer: 'current-model response: "I viewed the first ASCENT PNG. A has a replay marker in both views. B changes from dashed missing ranges to two filled ranges. The papers retain B and the withdrawal. The two unlabeled arrows can be read as a fixed workflow or as immediate publication after raw logs arrive. Put a sealing qualification on the first relation and an exact count assessment qualification on the second. Name the required manifest inventory in the short introduction. This is an image reading, not a learner comprehension verdict.")) image-evidence: (list
  (.o inspection: 'final-reading facet: 'missing-range anchor: "gap/text/3" excerpt: "Missing")
  (.o inspection: 'final-reading facet: 'missing-range anchor: "gap/text/5" excerpt: "Zero refuted. Count open.")
  (.o inspection: 'final-reading facet: 'sealed-range anchor: "closed/text/3" excerpt: "Coverage closed")
  (.o inspection: 'final-reading facet: 'sealed-range anchor: "closed/text/4" excerpt: "One distinct replay.")
  (.o inspection: 'final-reading facet: 'version-history anchor: "summary/text/1" excerpt: "v2")
  (.o inspection: 'final-reading facet: 'version-history anchor: "summary/text/2" excerpt: "v3")
  (.o inspection: 'final-reading facet: 'version-history anchor: "summary/text/4" excerpt: "Keep B and v2.")
  (.o inspection: 'second-reading facet: 'missing-range anchor: "gap/text/3" excerpt: "Missing")
  (.o inspection: 'second-reading facet: 'missing-range anchor: "gap/text/5" excerpt: "Zero refuted. Count open.")
  (.o inspection: 'second-reading facet: 'sealed-range anchor: "closed/text/3" excerpt: "Coverage closed")
  (.o inspection: 'second-reading facet: 'sealed-range anchor: "closed/text/4" excerpt: "One distinct replay.")
  (.o inspection: 'second-reading facet: 'version-history anchor: "summary/text/1" excerpt: "v2")
  (.o inspection: 'second-reading facet: 'version-history anchor: "summary/text/2" excerpt: "v3")
  (.o inspection: 'second-reading facet: 'version-history anchor: "summary/text/4" excerpt: "Keep B and v2.")) representation-gaps: (list
  (.o inspection: 'first-reading facet: 'sealed-range target: "ContextRepeatedRecovery::interruptedWriteDesign" reason: 'sealing-and-inventory-condition-implicit)
  (.o inspection: 'first-reading facet: 'version-history target: "ContextRepeatedRecovery::interruptedWriteDesign" reason: 'exact-assessment-condition-hidden)) layout-concerns: '()))
