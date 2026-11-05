;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export DesignReadings)
(def DesignReadings (.o
  inspections: (list
    (.o identity: 'first-reading view: 'org-durable-declarations revision: 'design
      source-cut: 'sha256-1e37ab32e131a1e3f8a2f9f63fb9672df350239e0cb0a8e174a8fb50ce8b8e51 image-sha: "07ec32e79e61b8c5c591adfd07e74cb627bfb19f79dcdcd257e8f0faf6e74348"
      question: 'same-slot producer: 'current-model
      response: "I viewed the PNG. The Org heading and nominal slot independently feed the owner, and the slot appears again in the acceptance record. The small captions, particularly the slot caption split over two lines, make the two input roles harder to read. Increase the canvas width and shorten the captions.")
    (.o identity: 'revised-reading view: 'org-durable-declarations revision: 'design
      source-cut: 'sha256-1e37ab32e131a1e3f8a2f9f63fb9672df350239e0cb0a8e174a8fb50ce8b8e51 image-sha: "d6519672c442f593e13c8c78b24e0859bb28bf1b0d8328253584f8874ca38194"
      question: 'same-slot producer: 'current-model response: "I viewed the revised PNG. The clock and Org heading independently reach the owner through When to check and What to check. The 10:05 slot appears on both sides of the gate. A late delivery still refers to 10:05, and the ledger shows one acceptance record. The shield caption names current binding and permission. The enlarged and shorter captions are readable."))
  image-evidence: (list
    (.o inspection: 'revised-reading facet: 'source anchor: "heading/text/0" excerpt: "Org")
    (.o inspection: 'revised-reading facet: 'source anchor: "heading/text/1" excerpt: "Watch the workspace")
    (.o inspection: 'revised-reading facet: 'source anchor: "heading/text/2" excerpt: "An Org heading names a read.")
    (.o inspection: 'revised-reading facet: 'occurrence anchor: "slot/text/0" excerpt: "10:05")
    (.o inspection: 'revised-reading facet: 'occurrence anchor: "slot/text/1" excerpt: "A clock slot comes due")
    (.o inspection: 'revised-reading facet: 'occurrence anchor: "slot/text/2" excerpt: "A late wakeup keeps 10:05.")
    (.o inspection: 'revised-reading facet: 'authority anchor: "owner/text/0" excerpt: "Durable owner checks")
    (.o inspection: 'revised-reading facet: 'authority anchor: "owner/text/1" excerpt: "Current binding and permission.")
    (.o inspection: 'revised-reading facet: 'acceptance anchor: "journal/text/0" excerpt: "10:05")
    (.o inspection: 'revised-reading facet: 'acceptance anchor: "journal/text/1" excerpt: "One acceptance record")
    (.o inspection: 'revised-reading facet: 'acceptance anchor: "journal/text/2" excerpt: "Repeats find the same record.")) representation-gaps: '() layout-concerns: '()))
