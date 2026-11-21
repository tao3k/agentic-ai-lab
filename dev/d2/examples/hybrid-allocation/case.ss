;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Model-authored teaching data only: no coordinates, routes or TS compositor.
(import :clan/poo/object (only-in "./teaching.ss" TeachingItems TeachingMechanism))
(export DesignCase)
(def (at suffix) (string-append "ContextHybridAllocation::HybridNode" suffix))
(def (picture filename) (string-append "dev/d2/examples/hybrid-allocation/assets/" filename ".svg"))
(def DesignCase
  (.o identity: 'hybrid-allocation
      inputs: '("dev/d2/examples/hybrid-allocation/teaching.ss")
      teaching: TeachingItems
      mechanism: TeachingMechanism
      org: "docs/10-19-design/10.06-poo-module-system/agentic-ai-context/28-hybrid-runtime.org"
      models: '("docs/10-19-design/10.06-poo-module-system/agentic-ai-context/28-hybrid-allocation.sysml"
                "dev/d2/examples/hybrid-allocation/view.sysml")
      view: "HybridTeachingView::teaching" audience: 'beginner
      title: "Follow result R. Receiving it does not mean accepting it."
      intro: "Context holds working information. VM is its runtime home. Session tracks progress and its own outcome."
      primary: 'who-decides width: 1800
      questions:
      (list (.o identity: 'who-decides audience: 'beginner subject: 'hybrid
                text: "Who can change what the system knows?")
            (.o identity: 'what-completes audience: 'beginner subject: 'hybrid
                text: "Why are a copy, an original and an outcome different?")
            (.o identity: 'what-is-open audience: 'beginner subject: 'hybrid
                text: "What is still missing from the deployed path?"))
      facet-needs:
      (list (.o question: 'who-decides facet: 'io-readiness target: (at "/runtime/asyncIo"))
            (.o question: 'who-decides facet: 'context-authority target: (at "/runtime/runtimeOwners/vm/contexts"))
            (.o question: 'who-decides facet: 'fixed-locality target: (at "/runtime/runtimeOwners"))
            (.o question: 'who-decides facet: 'compute-proposal target: (at "/runtime/compute"))
            (.o question: 'what-completes facet: 'copied-boundary target: (at "/runtime/runtimeOwners/service"))
            (.o question: 'what-completes facet: 'retained-originals target: (at "/evidence"))
            (.o question: 'what-completes facet: 'independent-terminal target: (at "/sessions"))
            (.o question: 'what-is-open facet: 'context-export-gap target: (at "/runtime/runtimeOwners/service"))
            (.o question: 'what-is-open facet: 'heap-policy-gap target: (at "/runtime/runtimeOwners/service"))
            (.o question: 'what-is-open facet: 'control-reserve-gap target: (at "/runtime/input"))
            (.o question: 'who-decides facet: 'current-context target: (at "/runtime/runtimeOwners/vm/contexts"))
            (.o question: 'who-decides facet: 'changed-context target: (at "/runtime/runtimeOwners/vm/contexts"))
            (.o question: 'what-completes facet: 'terminal-authority target: (at "/sessions")))

      choices:
      (list (.o source-ref: (at "") caption: "One hybrid node" glyph: "" role: "boundary"
                rationale: "The outer boundary is deployment allocation, not an extra semantic authority.")
            (.o source-ref: (at "/runtime") caption: "Rust runtime adapter" glyph: "" role: "boundary"
                rationale: "An enclosing adapter expresses runtime allocation without inventing a data-flow edge.")
            (.o source-ref: (at "/runtime/asyncIo") caption: "Tokio I/O (Rust)\nWatches I/O; reports arrivals\nCannot admit Context results"
                glyph: (picture "io") role: "default"
                rationale: "A switchboard of arriving events expresses I/O readiness rather than an authority stamp.")
            (.o source-ref: (at "/runtime/input") caption: "Bounded host input\nControl reserve:\nnot end-to-end yet"
                glyph: (picture "lanes") role: "pending"
                rationale: "Separate lanes distinguish data and controls. A visibly broken amber lane marks the unresolved end-to-end reserve, instead of a complete shield that implies protection already exists.")
            (.o source-ref: (at "/runtime/runtimeOwners") caption: "Same Context domain, same VM" glyph: "" role: "boundary"
                rationale: "Combine the owner and its local VM as one teaching boundary. ASCENT lifts visible children through the omitted VM occurrence while retaining their native ancestry; this is not one VM per Session or round-robin routing.")
            (.o source-ref: (at "/runtime/runtimeOwners/vm/contexts") caption: "Scheme Context\nOwns Context decisions\nChecks source, grant, policy"
                glyph: (picture "authority") role: "focal"
                rationale: "An evidence-fed decision gate distinguishes proof/admission from asynchronous completion.")
            (.o source-ref: (at "/runtime/runtimeOwners/service") caption: "Copied-byte boundary\nVM roots never cross\nContext export: not implemented\nHeap limit before setup:\nnot implemented"
                glyph: (picture "parcel") role: "pending"
                rationale: "A parcel across a fence depicts owned bytes, while both outstanding source flags remain explicit.")
            (.o source-ref: (at "/runtime/compute") caption: "Optional CPU work\nOwned immutable inputs\nProposals still need admission"
                glyph: (picture "compute") role: "default"
                rationale: "A calculator over copied inputs suggests computation rather than a second proof owner.")
            (.o source-ref: (at "/evidence") caption: "Original evidence\nKeep facts, rules, proof inputs\nResults do not replace them"
                glyph: (picture "archive") role: "knowledge"
                rationale: "A retained archive expresses originals, rather than a compressed summary or another Context database.")
            (.o source-ref: (at "/sessions") caption: "Independent Sessions\nOwn attempts + final outcomes\nI/O cannot finish a Session"
                glyph: (picture "terminal") role: "default"
                rationale: "A single endpoint and receipt express terminal ownership, separate from an I/O arrival."))))
