;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Current-model readings of actual PNGs. Content/evidence, never pass flags.
(import :clan/poo/object)
(export WindowReadings)
(def WindowReadings
  (.o facet-needs:
      (list (.o question: 'changedView facet: 'changed-evidence target: 'graph)
            (.o question: 'changedView facet: 'preserved-history target: 'graph)
            (.o question: 'retainedLimits facet: 'method target: 'knowledge)
            (.o question: 'retainedLimits facet: 'scope target: 'knowledge)
            (.o question: 'retainedLimits facet: 'counterexample target: 'knowledge)
            (.o question: 'retainedLimits facet: 'recheck-condition target: 'knowledge))
      inspections: (list
        (.o identity: 'revised-change view: 'context-design revision: 'design source-cut: 'sha256-dae4f817d7a94369cc451c9be23267f614a17bb622235a50b00b52c13f557dfe
            image-sha: "dbe748513de4f4d46755e0efe986c578447d9f7f7e48ebe02e36850b057fc97e" question: 'changedView producer: 'current-model
            response: "A failed control adds conflict to the old-input hypothesis. The earlier view is still drawn beside the later one; the passing rebuild and its green support remain in both. The same-idea connection links those versions rather than replacing the earlier one. The identity and supports labels now occupy separate regions.")
        (.o identity: 'revised-limits view: 'context-design revision: 'design source-cut: 'sha256-dae4f817d7a94369cc451c9be23267f614a17bb622235a50b00b52c13f557dfe
            image-sha: "dbe748513de4f4d46755e0efe986c578447d9f7f7e48ebe02e36850b057fc97e" question: 'retainedLimits producer: 'current-model
            response: "The candidate method compares a clean rebuild with a control. Its applicability is the same source and tool versions; the retained counterexample is a control that still fails after rebuild. Changes to source or tool versions require rechecking. These are visible notebook contents, not only field headings." )
        (.o identity: 'expanded-change view: 'context-design revision: 'design source-cut: 'sha256-9c112a4418456f45b678f2eb7584c3dcc9f254685f9c58d2254b900b7773f93c
            image-sha: "d36fc98efaf01cc1522799034c4aba7c6a11cbef2a92aed3efd8b639780d91ca" question: 'changedView producer: 'current-model
            response: "The earlier view retains the passing rebuild and the later view adds a conflicting control result to the same hypothesis. The shared-identity label and the second supports label crowd each other, making that otherwise visible correspondence harder to follow.")
        (.o identity: 'expanded-limits view: 'context-design revision: 'design source-cut: 'sha256-9c112a4418456f45b678f2eb7584c3dcc9f254685f9c58d2254b900b7773f93c
            image-sha: "d36fc98efaf01cc1522799034c4aba7c6a11cbef2a92aed3efd8b639780d91ca" question: 'retainedLimits producer: 'current-model
            response: "The notebook now names a proposed clean/control comparison, limits it to the same source and tools, retains the failing control, and says to recheck when source or tool versions change. Its candidate caption separates this example from admitted long-term knowledge.")
        (.o identity: 'before-change view: 'context-design revision: 'design source-cut: 'sha256-761313ba1e10c5015187f57c6af3729fdb6ffd622f42bce5e27f67181bbe31af
            image-sha: "359835eb5d674ac27a0a16484a03799e4a5df60c49ee6798f5f1cd6978a14caf" question: 'changedView producer: 'current-model
            response: "The feedback caption names a counterexample and the POO caption says earlier versions remain. The picture still shows only one generic graph, so the reader must imagine which earlier relation survives and what changes.")
        (.o identity: 'before-limits view: 'context-design revision: 'design source-cut: 'sha256-761313ba1e10c5015187f57c6af3729fdb6ffd622f42bce5e27f67181bbe31af
            image-sha: "359835eb5d674ac27a0a16484a03799e4a5df60c49ee6798f5f1cd6978a14caf" question: 'retainedLimits producer: 'current-model
            response: "The atlas labels Method, Scope and Limits. It supplies no concrete method, applicability boundary, retained counterexample or condition for rechecking; these names do not answer what must travel with this method.")) image-evidence: (list
        (.o inspection: 'revised-change facet: 'changed-evidence anchor: "n3/text/4" excerpt: "Control failed")
        (.o inspection: 'revised-change facet: 'changed-evidence anchor: "n3/text/8" excerpt: "conflicts")
        (.o inspection: 'revised-change facet: 'preserved-history anchor: "n3/text/1" excerpt: "Earlier view")
        (.o inspection: 'revised-change facet: 'preserved-history anchor: "n3/text/2" excerpt: "Later view")
        (.o inspection: 'revised-change facet: 'preserved-history anchor: "n3/text/13" excerpt: "Earlier support remains.")
        (.o inspection: 'revised-change facet: 'preserved-history anchor: "n3/text/10" excerpt: "same idea")
        (.o inspection: 'revised-limits facet: 'method anchor: "n10/text/3" excerpt: "Compare clean rebuild")
        (.o inspection: 'revised-limits facet: 'method anchor: "n10/text/4" excerpt: "with a control.")
        (.o inspection: 'revised-limits facet: 'scope anchor: "n10/text/6" excerpt: "Same source and tool")
        (.o inspection: 'revised-limits facet: 'scope anchor: "n10/text/7" excerpt: "versions.")
        (.o inspection: 'revised-limits facet: 'counterexample anchor: "n10/text/9" excerpt: "Control still fails")
        (.o inspection: 'revised-limits facet: 'counterexample anchor: "n10/text/10" excerpt: "after rebuild.")
        (.o inspection: 'revised-limits facet: 'recheck-condition anchor: "n10/text/12" excerpt: "Source or tool")
        (.o inspection: 'revised-limits facet: 'recheck-condition anchor: "n10/text/13" excerpt: "versions change.")
        (.o inspection: 'expanded-change facet: 'changed-evidence anchor: "n3/text/4" excerpt: "Control failed")
        (.o inspection: 'expanded-change facet: 'changed-evidence anchor: "n3/text/8" excerpt: "conflicts")
        (.o inspection: 'expanded-change facet: 'preserved-history anchor: "n3/text/13" excerpt: "Earlier support remains.")
        (.o inspection: 'expanded-change facet: 'preserved-history anchor: "n3/text/10" excerpt: "same idea")
        (.o inspection: 'expanded-limits facet: 'method anchor: "n10/text/3" excerpt: "Compare clean rebuild")
        (.o inspection: 'expanded-limits facet: 'method anchor: "n10/text/4" excerpt: "with a control.")
        (.o inspection: 'expanded-limits facet: 'scope anchor: "n10/text/6" excerpt: "Same source and tool")
        (.o inspection: 'expanded-limits facet: 'scope anchor: "n10/text/7" excerpt: "versions.")
        (.o inspection: 'expanded-limits facet: 'counterexample anchor: "n10/text/9" excerpt: "Control still fails")
        (.o inspection: 'expanded-limits facet: 'counterexample anchor: "n10/text/10" excerpt: "after rebuild.")
        (.o inspection: 'expanded-limits facet: 'recheck-condition anchor: "n10/text/12" excerpt: "Source or tool")
        (.o inspection: 'expanded-limits facet: 'recheck-condition anchor: "n10/text/13" excerpt: "versions change.")
        (.o inspection: 'before-change facet: 'changed-evidence anchor: "n7/text/2" excerpt: "A counterexample can reopen a claim.")
        (.o inspection: 'before-change facet: 'preserved-history anchor: "n2/text/5" excerpt: "New versions keep their history.")) representation-gaps: (list
        (.o inspection: 'before-change facet: 'changed-evidence target: 'graph reason: 'no-visible-before-after-evidence)
        (.o inspection: 'before-change facet: 'preserved-history target: 'graph reason: 'no-visible-retained-earlier-view)
        (.o inspection: 'before-limits facet: 'scope target: 'knowledge reason: 'scope-is-only-a-heading)) layout-concerns: (list (.o inspection: 'revised-change first: "n3/text/7" second: "n3/text/10") (.o inspection: 'expanded-change first: "n3/text/7" second: "n3/text/10"))))
