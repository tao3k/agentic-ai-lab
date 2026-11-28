;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def))
(export D2Node. D2Relation. D2Diagram. D2Question. D2Representation. D2AuthoringContext.)
(.def D2Node. identity: #f label: "" kind: 'node)
(.def D2Relation. from: #f to: #f role: 'related)
(.def D2Diagram. identity: #f revision: #f nodes: '() relations: '() roots: '())
(.def D2Question. identity: #f audience: #f subject: #f text: "")
(.def D2Representation. identity: #f subject: #f state: #f asset-ref: #f)
(.def D2AuthoringContext.
  views: '() proposals: '() renders: '() observations: '() feedback: '()
  questions: '() needs: '() prerequisites: '() explanations: '()
  learner-checks: '() question-inventories: '() explanation-plan: #f
  ;; Host-measured anchors and model observations; no review-success flag.
  inspections: '() facet-needs: '() image-evidence: '() image-anchors: '()
  representation-gaps: '() layout-concerns: '() structure-gaps: '()
  route-needs: '() image-routes: '() minimum-reader-text: 0 visual-expressions: '())
