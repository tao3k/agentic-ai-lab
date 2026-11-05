;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export DesignReadings)
(def DesignReadings (.o
  inspections: (list
    (.o identity: 'first-reading view: 'org-agentic-inquiry revision: 'design
      source-cut: 'sha256-12871c554b29d7e6c530bc8eecc5ab3440c04f127aab912e2566ee0d7f111818 image-sha: "90005ec9c7ec80fc6fb07d864740f03e9223a4eb5737cf383d3c28a4c75b1c61"
      question: 'open-question producer: 'current-model
      response: "I viewed the PNG. The long horizontal chain reads like a required sequence. The return arrow is long and the captions are small. Show Org intent and the model's proposed checks entering Context separately, and keep the selected handoff and evidence return adjacent to the question.")
    (.o identity: 'revised-reading view: 'org-agentic-inquiry revision: 'design
      source-cut: 'sha256-12871c554b29d7e6c530bc8eecc5ab3440c04f127aab912e2566ee0d7f111818 image-sha: "f4d8328e1767421e5e540a5740145911c4035142e2d0c3624890def6592595f8"
      question: 'open-question producer: 'current-model response: "I viewed the revised PNG. The open question has a central position, with intent and model proposals shown as different inputs. The model can suggest a receipt check or defer. Two short, oppositely directed links connect the question and Durable: selected handoff and findings to assess. The arrow directions and names are legible and show a relationship, rather than a required sequence."))
  image-evidence: (list
    (.o inspection: 'revised-reading facet: 'intent anchor: "intent/text/0" excerpt: "Org gives intent")
    (.o inspection: 'revised-reading facet: 'intent anchor: "intent/text/1" excerpt: "Did the write happen?")
    (.o inspection: 'revised-reading facet: 'question anchor: "context/text/1" excerpt: "Context holds the question")
    (.o inspection: 'revised-reading facet: 'question anchor: "context/text/2" excerpt: "ASCENT finds the missing link.")
    (.o inspection: 'revised-reading facet: 'choice anchor: "model/text/0" excerpt: "The model explores")
    (.o inspection: 'revised-reading facet: 'choice anchor: "model/text/1" excerpt: "Check a receipt, or defer.")
    (.o inspection: 'revised-reading facet: 'handoff anchor: "durable/text/0" excerpt: "Durable keeps the decision")
    (.o inspection: 'revised-reading facet: 'handoff anchor: "durable/text/1" excerpt: "Checks permission. Keeps")
    (.o inspection: 'revised-reading facet: 'handoff anchor: "durable/text/2" excerpt: "evidence."))
  representation-gaps: (list
    (.o inspection: 'first-reading facet: 'question target: "OrgDurableDeclarations::inquiryDesign"
      reason: 'long-chain-looks-like-required-sequence))
  layout-concerns: '()))
