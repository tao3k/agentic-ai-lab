;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(export DesignReadings)
(def DesignReadings (.o
  inspections: (list
    (.o identity: 'first-reading view: 'recovery-dispatch-count-mvp revision: 'design
      source-cut: 'sha256-d68ee27fd856b93399c8afe41d37b98ee23da44081d11c10845f35be1b9d27d2 image-sha: "73bdb8388ad2a32029f6269bdf8512f0a289c6e8cedade3786e6f617bbad27ec"
      question: 'same-question producer: 'current-model response: "I viewed the PNG. Three evidence conditions converge on one count question. The opposing plus and minus signs on R43 and R44 could look like arithmetic cancellation. Use words that distinguish a corrected binding from a newly verified replay.")
    (.o identity: 'revised-reading view: 'recovery-dispatch-count-mvp revision: 'design
      source-cut: 'sha256-d68ee27fd856b93399c8afe41d37b98ee23da44081d11c10845f35be1b9d27d2 image-sha: "ad9ad4082d8edd71f75cc8a8ea3843e31194131c3de7a8f288762a5b5a66fe83"
      question: 'same-question producer: 'current-model response: "I viewed the revised PNG. The three arrows name different effects on the same question. The known copy adds another record of R42 with no count change. R43 is labeled Was a copy and R44 New replay, so readers no longer have to interpret the two discoveries as arithmetic. The checked ranges visibly support an exact count. One question card and its evidence remain the focus, with no numbered summary ladder."))
  image-evidence: (list
    (.o inspection: 'revised-reading facet: 'same-dispatch anchor: "copies/text/1" excerpt: "Known copy")
    (.o inspection: 'revised-reading facet: 'same-dispatch anchor: "copies/text/2" excerpt: "Another record, same dispatch.")
    (.o inspection: 'revised-reading facet: 'changed-basis anchor: "witness/text/0" excerpt: "R43")
    (.o inspection: 'revised-reading facet: 'changed-basis anchor: "witness/text/1" excerpt: "R44")
    (.o inspection: 'revised-reading facet: 'changed-basis anchor: "witness/text/2" excerpt: "Was a copy")
    (.o inspection: 'revised-reading facet: 'changed-basis anchor: "witness/text/3" excerpt: "New replay")
    (.o inspection: 'revised-reading facet: 'changed-basis anchor: "witness/text/4" excerpt: "Old count loses support")
    (.o inspection: 'revised-reading facet: 'exact-basis anchor: "coverage/text/0" excerpt: "Every range checked")
    (.o inspection: 'revised-reading facet: 'exact-basis anchor: "coverage/text/1" excerpt: "Exactly R42 and R44.")
    (.o inspection: 'revised-reading facet: 'one-question anchor: "review/text/1" excerpt: "Same ASCENT count question")
    (.o inspection: 'revised-reading facet: 'one-question anchor: "review/text/2" excerpt: "Keep the answer and its reasons."))
  representation-gaps: (list
    (.o inspection: 'first-reading facet: 'changed-basis
      target: "ContextRepeatedRecovery::interruptedWriteDesign"
      reason: 'opposite-signs-suggest-cancelling-two-evidence-changes))
  layout-concerns: '()))
