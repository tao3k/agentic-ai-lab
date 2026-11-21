;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Explanatory objects and relations, not an executor's workflow or coordinates.
(import :clan/poo/object)
(export TeachingItems TeachingMechanism)
(def Org "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/28-hybrid-runtime.org")
(def Sysml "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/28-hybrid-allocation.sysml")
(def Authority "The Scheme POO contract is the semantic owner. ASCENT proof admission,\ntemporal-causality, source/policy versions, support edges, Context views and\nSession's actual terminal CAS remain Scheme operations.")
(def NoTerminal "Neither a Rust enum, async completion, routing handle nor Tokio cancellation\nbecomes evidence authority or an Attempt terminal.")
(def (depiction id-value q-value facet-value suffix art title-value explanation-value rationale-value source-value excerpt-value (encoding-value (.o family: #f state: #f intent: 'object)))
  (.o identity: id-value question: q-value facet: facet-value
      target: (string-append "ContextHybridAllocation::HybridNode" suffix)
      glyph: (if (string=? art "") "" (string-append "dev/d2/examples/hybrid-allocation/assets/" art ".svg"))
      representation: encoding-value
      title: title-value explanation: explanation-value rationale: rationale-value source: source-value excerpt: excerpt-value))
(def TeachingItems
  (list
    (depiction 'arrival-state 'who-decides 'io-readiness "/runtime/asyncIo" "candidate"
      "A result arrives" "Rust brings result R."
      "R is an amber candidate, not an admitted fact. It must visibly reach a checker instead of sitting in a separate topic panel." Org NoTerminal)
    (depiction 'copy-state 'what-completes 'copied-boundary "/runtime/runtimeOwners/service" "copy-transfer"
      "Send a separate copy" "Live objects stay in their VM."
      "The detached copy R travels to its fixed Scheme owner. The root network is retained behind the boundary."
      Sysml "// Compiler-produced C ABI; transfer copied bytes, never borrowed roots.")
    (depiction 'compute-state 'who-decides 'compute-proposal "/runtime/compute" "optional-work"
      "Optional work" "A new proposal needs checking."
      "Optional CPU work is a side branch feeding the same checker, never a second admission authority."
      Org "| Rust compute adapter | Optional bounded CPU work over owned immutable inputs | Authenticating its own result or mutating Session state |")
    (depiction 'original-state 'what-completes 'retained-originals "/evidence" "source-archive"
      "Retained originals" "Facts, rules and proof stay."
      "The source archive feeds the check; a returned result never overwrites these originals."
      Org "Original Org,\nfacts, rules and proof inputs remain retained evidence.")
    (depiction 'fixed-home 'who-decides 'fixed-locality "/runtime/runtimeOwners" ""
      "The same runtime home" "Same Context, same VM.\nNo VM per Session."
      "Pinning is an attached condition of checking, not an unrelated illustration."
      Org "Use a small long-lived pool of fixed VMs, with multiple Context domains/Actors\ninside each as appropriate. Do not allocate one VM or OS thread per Session.")
    (depiction 'current-state 'who-decides 'current-context "/runtime/runtimeOwners/vm/contexts" "context-before"
      "Current Context / v0" "A, B and C are already here."
      "The before-state supplies the current source/policy cut. The not-admitted branch returns here without a version change." Org Authority
      (.o family: 'context-graph state: 'v0 intent: 'state))
    (depiction 'decision-state 'who-decides 'context-authority "/runtime/runtimeOwners/vm/contexts" "check-inputs"
      "Scheme checks R" "Source + permission + rules."
      "The checker receives the actual candidate, original evidence and current cut; it has explicit admitted and not-admitted relations to the Context states." Org Authority
      (.o family: 'comparison state: 'checking intent: 'check))
    (depiction 'changed-state 'who-decides 'changed-context "/runtime/runtimeOwners/vm/contexts" "context-after"
      "Changed Context / v1" "A, B and C stay; R is added."
      "The same Context graph gains R only on the Scheme-admitted branch. This is a possible state change, not a claim that every arrival succeeds." Org Authority
      (.o family: 'context-graph state: 'v1 intent: 'state))
    (depiction 'session-state 'what-completes 'independent-terminal "/sessions" "outcome-ledger"
      "Session outcome" "A receipt is not a final outcome."
      "An observation of arrival and the Session's independent final outcome are distinct. The arrival does not produce a terminal CAS." Org NoTerminal)
    (depiction 'terminal-owner 'what-completes 'terminal-authority "/sessions" "terminal-owner"
      "Session's own decision" "Only its owner can record the result."
      "This independent authority connects to the final-outcome ledger, not to transport completion. Context admission is explicitly insufficient." Org Authority)
    (depiction 'control-gap 'what-is-open 'control-reserve-gap "/runtime/input" ""
      "Control messages need room" "The full route is not reserved yet."
      "Attach the broken control lane to ingress, so the learner can see where the missing guarantee matters."
      Sysml "attribute endToEndControlReserveImplemented : Boolean := false;")
    (depiction 'export-gap 'what-is-open 'context-export-gap "/runtime/runtimeOwners/service" ""
      "Real Context service gap" "The real service link is still missing."
      "Attach the unimplemented production service export to the copied-byte handoff, without denying the separately qualified fixture bridge."
      Sysml "attribute productionContextExportImplemented : Boolean := false;")
    (depiction 'heap-gap 'what-is-open 'heap-policy-gap "/runtime/runtimeOwners/service" ""
      "Memory limit before start" "That limit is still missing."
      "Attach the missing pre-start limit to the VM home, rather than arranging all caveats as a separate row."
      Sysml "attribute preSetupHeapPolicyImplemented : Boolean := false;")))
(def (link id-value from-value to-value role-value label-value style-value trace-value source-value excerpt-value)
  (.o identity: id-value from: from-value to: to-value role: role-value label: label-value
      style: style-value propagates?: trace-value source: source-value excerpt: excerpt-value))
(def (need-link q-value from-value to-value role-value)
  (.o question: q-value from: from-value to: to-value role: role-value))
(def TeachingMechanism
  (.o links:
    (list
      (link 'carry 'arrival-state 'copy-state 'transport "result R" "flow" #t Org NoTerminal)
      (link 'handoff 'copy-state 'decision-state 'input "a separate copy of R" "flow" #t Sysml "// Compiler-produced C ABI; transfer copied bytes, never borrowed roots.")
      (link 'optional 'copy-state 'compute-state 'optional-work "optional copied input" "support" #t Org "| Rust compute adapter | Optional bounded CPU work over owned immutable inputs | Authenticating its own result or mutating Session state |")
      (link 'recheck 'compute-state 'decision-state 'proposal "proposal, not approval" "flow" #t Org NoTerminal)
      (link 'original-input 'original-state 'decision-state 'basis "check against originals" "support" #t Org "Original Org,\nfacts, rules and proof inputs remain retained evidence.")
      (link 'current-cut 'current-state 'decision-state 'current-cut "current sources and rules" "support" #t Org Authority)
      (link 'accept 'decision-state 'changed-state 'admitted "only if Scheme accepts R" "admitted" #t Org Authority)
      (link 'keep 'decision-state 'current-state 'not-admitted "if not accepted: keep v0" "unchanged" #t Org Authority)
      (link 'pin 'fixed-home 'decision-state 'locality "same Context owner" "constraint" #f Org "Independent Context domains can be pinned to different fixed VM owners.")
      (link 'observe 'arrival-state 'session-state 'observation "arrival is observation only" "constraint" #f Org NoTerminal)
      (link 'not-finished 'changed-state 'session-state 'distinction "does not finish Session" "negation" #f Org NoTerminal)
      (link 'terminal 'terminal-owner 'session-state 'terminal-authority "owner records final outcome" "admitted" #t Org Authority)
      (link 'ingress-gap 'control-gap 'arrival-state 'qualification "ingress still has this gap" "constraint" #f Sysml "attribute endToEndControlReserveImplemented : Boolean := false;")
      (link 'service-gap 'export-gap 'copy-state 'qualification "production export still open" "constraint" #f Sysml "attribute productionContextExportImplemented : Boolean := false;")
      (link 'memory-gap 'heap-gap 'fixed-home 'qualification "must be set before VM starts" "constraint" #f Sysml "attribute preSetupHeapPolicyImplemented : Boolean := false;"))
    attachments:
    (list (.o child: 'control-gap parent: 'arrival-state)
          (.o child: 'export-gap parent: 'copy-state)
          (.o child: 'fixed-home parent: 'decision-state)
          (.o child: 'heap-gap parent: 'fixed-home))
    requirements:
    (list (need-link 'who-decides 'arrival-state 'copy-state 'transport)
          (need-link 'who-decides 'copy-state 'decision-state 'input)
          (need-link 'who-decides 'original-state 'decision-state 'basis)
          (need-link 'who-decides 'current-state 'decision-state 'current-cut)
          (need-link 'who-decides 'decision-state 'changed-state 'admitted)
          (need-link 'who-decides 'decision-state 'current-state 'not-admitted)
          (need-link 'who-decides 'compute-state 'decision-state 'proposal)
          (need-link 'what-completes 'changed-state 'session-state 'distinction)
          (need-link 'what-completes 'terminal-owner 'session-state 'terminal-authority)
          (need-link 'what-is-open 'control-gap 'arrival-state 'qualification)
          (need-link 'what-is-open 'export-gap 'copy-state 'qualification)
          (need-link 'what-is-open 'heap-gap 'fixed-home 'qualification))
    traces:
    (list (.o question: 'who-decides from: 'arrival-state to: 'changed-state)
          (.o question: 'who-decides from: 'original-state to: 'changed-state)
          (.o question: 'what-completes from: 'terminal-owner to: 'session-state))))
