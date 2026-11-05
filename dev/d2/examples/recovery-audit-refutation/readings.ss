;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative D2 presentation facts for the audit design.
(import :clan/poo/object)
(export DesignReadings)
(def DesignReadings (.o inspections: (list (.o identity: 'refined-reading view: 'recovery-audit-refutation revision: 'design source-cut: 'sha256-85c8bfffe274b061fb74295e91e5e0571720a925c9238d48bcb5f28fb5a6183a image-sha: "035f2554e042f91ceb78a3d11d7aa6870c1b5edb2d3ffd3e5002d42574640d2e" question: 'what-changed producer: 'current-model response: "I viewed the revised ASCENT PNG. Storage audit puts 1 with Commit and two ticks for Append and Once; W1-v2 is identified as the append basis. Dispatch journal puts 1 with Replay seen and crosses out No replay, so I read the number as a witness rather than an exact total. Both evidence objects point to the revised summary. The stacked B and v2 sheets, with Kept on B, separate preservation from selection. Exact rewrite needs full coverage distinguishes withdrawing the old assertion from publishing a new count. The compact canvas and short captions are easier to scan. The replay caption sits near its local panel edge but remains legible. This is a scoped image reading.")
  (.o identity: 'first-reading view: 'recovery-audit-refutation revision: 'design source-cut: 'sha256-85c8bfffe274b061fb74295e91e5e0571720a925c9238d48bcb5f28fb5a6183a image-sha: "ecb2a2318bf4743b49590b454a347b5e124fe2f69cee198073beee62c4d1ad15" question: 'what-changed producer: 'current-model response: "I viewed the first ASCENT-rendered PNG. The green check marks retain Append and Once, the replay loop strikes No replay, and the stacked papers separate B from v2. But both large digits read as bare ones. The dispatch digit is an observed witness, while the storage digit is an exact count. The title makes the two counts sound equally complete, and the revision leaves the conditional rewrite unstated. Label the units locally, mark the replay as seen, and show the full-audit condition for an exact replay rewrite. The objects use a small fraction of the available width. This is model critique of the actual image.")) image-evidence: (list
  (.o inspection: 'refined-reading facet: 'commit-support anchor: "storage/text/0" excerpt: "1")
  (.o inspection: 'refined-reading facet: 'commit-support anchor: "storage/text/1" excerpt: "Append")
  (.o inspection: 'refined-reading facet: 'commit-support anchor: "storage/text/2" excerpt: "Once")
  (.o inspection: 'refined-reading facet: 'commit-support anchor: "storage/text/3" excerpt: "Commit")
  (.o inspection: 'refined-reading facet: 'replay-refutation anchor: "dispatch/text/0" excerpt: "1")
  (.o inspection: 'refined-reading facet: 'replay-refutation anchor: "dispatch/text/1" excerpt: "No replay")
  (.o inspection: 'refined-reading facet: 'replay-refutation anchor: "dispatch/text/2" excerpt: "Replay seen")
  (.o inspection: 'refined-reading facet: 'admission-history anchor: "revision/text/0" excerpt: "B")
  (.o inspection: 'refined-reading facet: 'admission-history anchor: "revision/text/1" excerpt: "v2")
  (.o inspection: 'refined-reading facet: 'admission-history anchor: "revision/text/2" excerpt: "Kept")
  (.o inspection: 'refined-reading facet: 'admission-history anchor: "revision/text/4" excerpt: "Exact rewrite needs full")
) representation-gaps: (list
  (.o inspection: 'first-reading facet: 'commit-support target: "ContextRepeatedRecovery::interruptedWriteDesign" reason: 'commit-unit-missing)
  (.o inspection: 'first-reading facet: 'replay-refutation target: "ContextRepeatedRecovery::interruptedWriteDesign" reason: 'witness-count-misreads-as-exact)
  (.o inspection: 'first-reading facet: 'admission-history target: "ContextRepeatedRecovery::interruptedWriteDesign" reason: 'rewrite-guard-not-visible)) layout-concerns: '()))
