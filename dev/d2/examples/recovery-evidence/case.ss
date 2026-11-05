;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object)
(import (only-in "./teaching.ss" TeachingItems TeachingMechanism RecoveryNeeds))
(export DesignCase)
(def DesignCase (.o identity: 'recovery-evidence
 inputs: '("dev/d2/examples/recovery-evidence/teaching.ss"
 "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.qnt"
 "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.lean"
 "modules/temporal-causality/framework.org"
 "modules/temporal-causality/evidence/model.org")
 org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.org"
 models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/workspace-recovery.sysml" "dev/d2/examples/recovery-evidence/view.sysml")
 view: "RecoveryEvidenceView::teaching" audience: 'young-novice primary: 'why-still-unknown width: 1800
 title: "The line is there. Is the work finished?"
 intro: "The write may have happened before a crash. No receipt was saved. Follow the evidence, not a fixed sequence."
 teaching: TeachingItems mechanism: TeachingMechanism facet-needs: RecoveryNeeds
 questions: (list (.o identity: 'why-still-unknown audience: 'young-novice subject: 'recovery text: "What could tell us who wrote the line, and what changes when that evidence is corrected?"))
 choices: (list (.o source-ref: "ContextRepeatedRecovery::interruptedWriteDesign" caption: "Recovery Context" glyph: "" role: "default" rationale: "One retained recovery scene, with separate evidence and question views."))))
