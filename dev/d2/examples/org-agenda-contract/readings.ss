;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export DesignReadings)
(def DesignReadings (.o
  inspections: (list
    (.o identity: 'first-late-reading view: 'org-agenda-contract revision: 'design
      source-cut: 'sha256-176339f2da8eb37374eab1eda139cb92a600353355c48dc86e19def72d2701f5 image-sha: "fc4bc90535ff602b7983caf9b2201b7dc26bde29011d7ba1ddb357d884a4ea16"
      question: 'late-receipt producer: 'current-model
      response: "I viewed the PNG. The Org art says Starts 18:00 while its caption says the current time is 19:00. Make the before and after explicit. Show that Bob's matched receipt changes the prior unknown assessment to accepted.")
    (.o identity: 'revised-late-reading view: 'org-agenda-contract revision: 'design
      source-cut: 'sha256-176339f2da8eb37374eab1eda139cb92a600353355c48dc86e19def72d2701f5 image-sha: "d4e72ee04fa441e62609ba96829c8238289f9e991e91049ee60460a4bcb386cf"
      question: 'late-receipt producer: 'current-model response: "I viewed the revised PNG. Was 18:00 and Now 19:00 refer to the same appointment. Bob's receipt still names the 18:00 notice, and the caption shows the change from unknown to accepted. Alice and Bob have correction candidates while Cara has a first notice. The permission arrow and one-handoff caption qualify sending, and receipts return in the opposite direction."))
  image-evidence: (list
    (.o inspection: 'revised-late-reading facet: 'current-plan anchor: "draft/text/0" excerpt: "Was 18:00")
    (.o inspection: 'revised-late-reading facet: 'current-plan anchor: "draft/text/1" excerpt: "Now 19:00")
    (.o inspection: 'revised-late-reading facet: 'current-plan anchor: "draft/text/3" excerpt: "Same appointment.")
    (.o inspection: 'revised-late-reading facet: 'receipt-match anchor: "late-receipt/text/0" excerpt: "Bob")
    (.o inspection: 'revised-late-reading facet: 'receipt-match anchor: "late-receipt/text/1" excerpt: "18:00 notice")
    (.o inspection: 'revised-late-reading facet: 'receipt-match anchor: "late-receipt/text/2" excerpt: "Bob’s receipt arrives")
    (.o inspection: 'revised-late-reading facet: 'receipt-match anchor: "late-receipt/text/3" excerpt: "Unknown to accepted.")
    (.o inspection: 'revised-late-reading facet: 'recipient-judgment anchor: "authority/text/0" excerpt: "ASCENT checks each person")
    (.o inspection: 'revised-late-reading facet: 'recipient-judgment anchor: "authority/text/1" excerpt: "Old message or first notice?")
    (.o inspection: 'revised-late-reading facet: 'deduplication anchor: "receipts/text/0" excerpt: "Alice")
    (.o inspection: 'revised-late-reading facet: 'deduplication anchor: "receipts/text/1" excerpt: "Bob")
    (.o inspection: 'revised-late-reading facet: 'deduplication anchor: "receipts/text/2" excerpt: "Cara")
    (.o inspection: 'revised-late-reading facet: 'deduplication anchor: "receipts/text/3" excerpt: "Correction")
    (.o inspection: 'revised-late-reading facet: 'deduplication anchor: "receipts/text/4" excerpt: "Correction")
    (.o inspection: 'revised-late-reading facet: 'deduplication anchor: "receipts/text/5" excerpt: "First notice")
    (.o inspection: 'revised-late-reading facet: 'deduplication anchor: "receipts/text/6" excerpt: "Durable sends if allowed")
    (.o inspection: 'revised-late-reading facet: 'deduplication anchor: "receipts/text/7" excerpt: "One handoff per key."))
  representation-gaps: (list
    (.o inspection: 'first-late-reading facet: 'current-plan
      target: "OrgDurableDeclarations::agendaDesign" reason: 'old-time-looks-current))
  layout-concerns: '()))
