;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Image-specific observations from actual PNG review.
(import :clan/poo/object)
(export DesignReadings)
(def DesignReadings (.o
  inspections: (list
(.o identity: 'first-reading view: 'recovery-dispatch-alias-correction revision: 'design
  source-cut: 'sha256-44e8b2124c89ef54f74ad22d6049976aa4a6136c0d9bdb256a742f1abe752b48 image-sha: "bceb50f51d1f5da9da70ae91e8d484114bd89ac49a91c2c0d5d240e776bd4f06"
  question: 'copy-count producer: 'current-model response: "I viewed the first PNG. The copy arrow correctly points from R43 to R42, and the three sheets distinguish v3, v4 and v5. But Resolves count points at a card titled Count open again. A reader can mistake closure for another reopening. Use a title naming the persistent responsibility and label the two incoming relations with opposite actions.")
(.o identity: 'revised-reading view: 'recovery-dispatch-alias-correction revision: 'design
  source-cut: 'sha256-44e8b2124c89ef54f74ad22d6049976aa4a6136c0d9bdb256a742f1abe752b48 image-sha: "8a48fcb6e7fc133b933cec84157d076ee43f9276ebe7abd13ca171e0efb7da23"
  question: 'copy-count producer: 'current-model response: "I viewed the revised PNG. The R43 ticket points to R42, so the two labels do not mean two dispatches. The two labeled arrows now point to the same ASCENT count responsibility: the identity correction reopens review and the four rechecked ranges close it. Only R42 is supported in the window. The lower arrow requires a still-current basis for Temporal to admit v5, with v3 and v4 visibly kept."))
  image-evidence: (list
(.o inspection: 'first-reading facet: 'copy-identity anchor: "forward/text/2" excerpt: "R43 is a copy")
(.o inspection: 'first-reading facet: 'reopened-count anchor: "review/text/1" excerpt: "Count open again")
(.o inspection: 'first-reading facet: 'fresh-count anchor: "coverage/text/0" excerpt: "Four ranges rechecked")
(.o inspection: 'first-reading facet: 'published-history anchor: "versions/text/4" excerpt: "Exactly one. Keep v3 and v4.")
(.o inspection: 'revised-reading facet: 'copy-identity anchor: "forward/text/0" excerpt: "R43")
(.o inspection: 'revised-reading facet: 'copy-identity anchor: "forward/text/1" excerpt: "R42")
(.o inspection: 'revised-reading facet: 'copy-identity anchor: "forward/text/2" excerpt: "R43 is a copy")
(.o inspection: 'revised-reading facet: 'reopened-count anchor: "review/text/1" excerpt: "ASCENT checks the count")
(.o inspection: 'revised-reading facet: 'reopened-count anchor: "review/text/2" excerpt: "Context withdraws “exactly two.”")
(.o inspection: 'revised-reading facet: 'fresh-count anchor: "coverage/text/0" excerpt: "Four ranges rechecked")
(.o inspection: 'revised-reading facet: 'fresh-count anchor: "coverage/text/1" excerpt: "Only R42 in the window.")
(.o inspection: 'revised-reading facet: 'published-history anchor: "versions/text/3" excerpt: "Temporal admits v5")
(.o inspection: 'revised-reading facet: 'published-history anchor: "versions/text/4" excerpt: "Exactly one. Keep v3 and v4."))
  representation-gaps: (list
    (.o inspection: 'first-reading facet: 'reopened-count
      target: "ContextRepeatedRecovery::interruptedWriteDesign"
      reason: 'closure-arrow-looks-like-reopening))
  layout-concerns: '()))
