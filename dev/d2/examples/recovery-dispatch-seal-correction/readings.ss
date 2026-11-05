;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative D2 presentation facts.
(import :clan/poo/object)
(export DesignReadings)
(def DesignReadings (.o inspections: (list (.o identity: 'current-reading view: 'recovery-dispatch-seal-correction revision: 'design source-cut: 'sha256-748923cabc829c6dfe0095115f37869452c0bdcdaadab41514d0d7efab2310e0 image-sha: "89c5c729d457330df1108c6f923eb77f51f9e4c4f96dec3b12ab8e6380bddca4" question: 'what-survives producer: 'current-model response: "I inspected the actual PNG. The prior panel has one R42 marker with four sealed ranges, and explicitly keeps v3 in history. The correction opens B's last range while the requalified A witness remains visible and the count is open. The fresh seal fills that range and adds a different replay marker R43. The final panel shows two distinct replays, so restored coverage cannot revive the previous exact-one assertion. The labeled arrows describe the evidence changes shown in this example. This is a model reading of the selected image.")) image-evidence: (list
(.o inspection: 'current-reading facet: 'prior-basis anchor: "prior/text/3" excerpt: "Prior exact count")
(.o inspection: 'current-reading facet: 'prior-basis anchor: "prior/text/4" excerpt: "Keep v3 in history.")
(.o inspection: 'current-reading facet: 'corrected-basis anchor: "gap/text/3" excerpt: "Gap")
(.o inspection: 'current-reading facet: 'corrected-basis anchor: "gap/text/5" excerpt: "A verified. Count open.")
(.o inspection: 'current-reading facet: 'new-basis anchor: "closed/text/3" excerpt: "R43")
(.o inspection: 'current-reading facet: 'new-basis anchor: "closed/text/5" excerpt: "Two distinct replays.")) representation-gaps: '() layout-concerns: '()))
