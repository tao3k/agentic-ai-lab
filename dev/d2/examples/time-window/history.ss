;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Model-authored observations are illustrative review evidence, not pupil data.
(import :clan/poo/object)
(export illustration-history)
(def illustration-history
  (.o subjects: (list (.o subject: 'counterexample state: 'late-arrival)
                         (.o subject: 'diagnostic-method state: 'contested)
                         (.o subject: 'stale-inputs state: 'contested)
                         (.o subject: 'compiler-abi state: 'open))
      learning-goals: (list (.o subject: 'counterexample concept: 'two-times)
                           (.o subject: 'diagnostic-method concept: 'scoped-knowledge)
                           (.o subject: 'stale-inputs concept: 'support-not-proof)
                           (.o subject: 'compiler-abi concept: 'plain-alternative))
      audience-gaps: (list (.o audience: 'beginner concept: 'two-times)
                           (.o audience: 'beginner concept: 'scoped-knowledge)
                           (.o audience: 'beginner concept: 'support-not-proof)
                           (.o audience: 'beginner concept: 'plain-alternative))
      distinctions: (list (.o concept: 'two-times facet: 'event-versus-known)
                          (.o concept: 'scoped-knowledge facet: 'age-is-not-admission)
                          (.o concept: 'support-not-proof facet: 'support-is-not-proof)
                          (.o concept: 'plain-alternative facet: 'plain-alternative))
      proposals: (list (.o identity: 'clear-time responds-to: '(r2-time) view: 'context-lesson revision: 'r3 source-cut: 'window-example-v1
        asset-ref: "dev/d2/examples/time-window/r3.svg" asset-sha: "806952a633772f47241b1ca78bdaefdecd2e14d236d282c94710561cfc530762") (.o identity: 'revised responds-to: '(r1-time r1-support r1-alternative) view: 'context-lesson revision: 'r2 source-cut: 'window-example-v1
        asset-ref: "dev/d2/examples/time-window/r2.svg" asset-sha: "5cccdf301d2ea8222b7ec6f1155d48abad88397e8a4a00dce06131f40aef017b") (.o identity: 'draft view: 'context-lesson revision: 'r1 source-cut: 'window-example-v1
        asset-ref: "dev/d2/examples/time-window/r1.svg" asset-sha: "aab6745eb20cc6e23025c984888563a6d5ceb75980f69d04a131a9ff68b86592")) renders: (list (.o proposal: 'clear-time asset-sha: "806952a633772f47241b1ca78bdaefdecd2e14d236d282c94710561cfc530762" image-sha: "32761a25c7f94102ceedb5187374545ba977de7e722572b46862ff42a02130cc"
        image-ref: "dev/d2/output/authoring/r3.png") (.o proposal: 'revised asset-sha: "5cccdf301d2ea8222b7ec6f1155d48abad88397e8a4a00dce06131f40aef017b" image-sha: "681132bf107bb723e294140c2a59d1c685f2a54001cbbba2369250d41901841a"
        image-ref: "dev/d2/output/authoring/r2.png") (.o proposal: 'draft asset-sha: "aab6745eb20cc6e23025c984888563a6d5ceb75980f69d04a131a9ff68b86592" image-sha: "71a4a46fed7144342b38b39f8826a9bd252e7a9adeae54785cc56694d7c37bb2"
        image-ref: "dev/d2/output/authoring/r1.png")) feedback: (list (.o identity: 'r3-time view: 'context-lesson revision: 'r3 source-cut: 'window-example-v1
          question: 'late-evidence verdict: 'understood producer: 'current-session-model image-sha: "32761a25c7f94102ceedb5187374545ba977de7e722572b46862ff42a02130cc"
          text: "The arrow now occupies the gap between the two captions. Time ticks and event/receipt wording are unobstructed; the earlier view excludes the not-yet-known result.")
        (.o identity: 'r3-retention view: 'context-lesson revision: 'r3 source-cut: 'window-example-v1
          question: 'retention verdict: 'understood producer: 'current-session-model image-sha: "32761a25c7f94102ceedb5187374545ba977de7e722572b46862ff42a02130cc"
          text: "The open notebook retains a method, scope and failed control. Under review and the age qualification avoid implying automatic promotion.")
        (.o identity: 'r3-support view: 'context-lesson revision: 'r3 source-cut: 'window-example-v1
          question: 'support-meaning verdict: 'understood producer: 'current-session-model image-sha: "32761a25c7f94102ceedb5187374545ba977de7e722572b46862ff42a02130cc"
          text: "Support is named on the connections, conflict has different wording, and the footer says support does not prove a cause.")
        (.o identity: 'r3-alternative view: 'context-lesson revision: 'r3 source-cut: 'window-example-v1
          question: 'alternative-meaning verdict: 'understood producer: 'current-session-model image-sha: "32761a25c7f94102ceedb5187374545ba977de7e722572b46862ff42a02130cc"
          text: "The possible incompatibility is expressed as build parts that do not fit. The question mark and open-explanations caption preserve uncertainty.")
         (.o identity: 'r2-time view: 'context-lesson revision: 'r2 source-cut: 'window-example-v1
          question: 'late-evidence verdict: 'unclear producer: 'current-session-model image-sha: "681132bf107bb723e294140c2a59d1c685f2a54001cbbba2369250d41901841a"
          text: "The relocated delivery curve crosses tick labels near 15 and 20. Give the arrow its own clear gap.")
        (.o identity: 'r2-retention view: 'context-lesson revision: 'r2 source-cut: 'window-example-v1
          question: 'retention verdict: 'understood producer: 'current-session-model image-sha: "681132bf107bb723e294140c2a59d1c685f2a54001cbbba2369250d41901841a"
          text: "The proposed method remains under review and retains scope and the failed control.")
        (.o identity: 'r2-support view: 'context-lesson revision: 'r2 source-cut: 'window-example-v1
          question: 'support-meaning verdict: 'understood producer: 'current-session-model image-sha: "681132bf107bb723e294140c2a59d1c685f2a54001cbbba2369250d41901841a"
          text: "Both arrows say supports; the footer explicitly distinguishes support from proof.")
        (.o identity: 'r2-alternative view: 'context-lesson revision: 'r2 source-cut: 'window-example-v1
          question: 'alternative-meaning verdict: 'understood producer: 'current-session-model image-sha: "681132bf107bb723e294140c2a59d1c685f2a54001cbbba2369250d41901841a"
          text: "Incompatible build parts and the disconnected plugs convey a possible mismatch without an ABI prerequisite.")
         (.o identity: 'r1-time view: 'context-lesson revision: 'r1 source-cut: 'window-example-v1
          question: 'late-evidence verdict: 'unclear producer: 'current-session-model image-sha: "71a4a46fed7144342b38b39f8826a9bd252e7a9adeae54785cc56694d7c37bb2"
          text: "The delivery arc crosses the time labels; separate the arrow and wording.")
        (.o identity: 'r1-retention view: 'context-lesson revision: 'r1 source-cut: 'window-example-v1
          question: 'retention verdict: 'understood producer: 'current-session-model image-sha: "71a4a46fed7144342b38b39f8826a9bd252e7a9adeae54785cc56694d7c37bb2"
          text: "The notebook carries scope and a counterexample; the method remains under review.")
        (.o identity: 'r1-support view: 'context-lesson revision: 'r1 source-cut: 'window-example-v1
          question: 'support-meaning verdict: 'unclear producer: 'current-session-model image-sha: "71a4a46fed7144342b38b39f8826a9bd252e7a9adeae54785cc56694d7c37bb2"
          text: "The plus glyph does not name support; a green arrow could be mistaken for proof.")
        (.o identity: 'r1-alternative view: 'context-lesson revision: 'r1 source-cut: 'window-example-v1
          question: 'alternative-meaning verdict: 'unclear producer: 'current-session-model image-sha: "71a4a46fed7144342b38b39f8826a9bd252e7a9adeae54785cc56694d7c37bb2"
          text: "Compiler / ABI assumes vocabulary that the beginner reader has not been given.")) observations: (list (.o finding: 'r3-time image-sha: "32761a25c7f94102ceedb5187374545ba977de7e722572b46862ff42a02130cc" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r3.png")
        (.o finding: 'r3-retention image-sha: "32761a25c7f94102ceedb5187374545ba977de7e722572b46862ff42a02130cc" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r3.png")
        (.o finding: 'r3-support image-sha: "32761a25c7f94102ceedb5187374545ba977de7e722572b46862ff42a02130cc" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r3.png")
        (.o finding: 'r3-alternative image-sha: "32761a25c7f94102ceedb5187374545ba977de7e722572b46862ff42a02130cc" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r3.png")
         (.o finding: 'r2-time image-sha: "681132bf107bb723e294140c2a59d1c685f2a54001cbbba2369250d41901841a" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r2.png")
        (.o finding: 'r2-retention image-sha: "681132bf107bb723e294140c2a59d1c685f2a54001cbbba2369250d41901841a" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r2.png")
        (.o finding: 'r2-support image-sha: "681132bf107bb723e294140c2a59d1c685f2a54001cbbba2369250d41901841a" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r2.png")
        (.o finding: 'r2-alternative image-sha: "681132bf107bb723e294140c2a59d1c685f2a54001cbbba2369250d41901841a" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r2.png")
         (.o finding: 'r1-time image-sha: "71a4a46fed7144342b38b39f8826a9bd252e7a9adeae54785cc56694d7c37bb2" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r1.png")
        (.o finding: 'r1-retention image-sha: "71a4a46fed7144342b38b39f8826a9bd252e7a9adeae54785cc56694d7c37bb2" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r1.png")
        (.o finding: 'r1-support image-sha: "71a4a46fed7144342b38b39f8826a9bd252e7a9adeae54785cc56694d7c37bb2" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r1.png")
        (.o finding: 'r1-alternative image-sha: "71a4a46fed7144342b38b39f8826a9bd252e7a9adeae54785cc56694d7c37bb2" producer: 'current-session-model
          method: 'view-image image-ref: "dev/d2/output/authoring/r1.png"))
      explanations: (list (.o view: 'context-lesson revision: 'r3 concept: 'two-times element: 'independent-delivery-arrow)
                            (.o view: 'context-lesson revision: 'r3 concept: 'scoped-knowledge element: 'notebook-with-limits)
                            (.o view: 'context-lesson revision: 'r3 concept: 'support-not-proof element: 'support-wording-and-qualification)
                            (.o view: 'context-lesson revision: 'r3 concept: 'plain-alternative element: 'incompatible-plugs) (.o view: 'context-lesson revision: 'r2 concept: 'two-times element: 'separated-event-and-receipt-marks)
                            (.o view: 'context-lesson revision: 'r2 concept: 'scoped-knowledge element: 'notebook-with-limits)
                            (.o view: 'context-lesson revision: 'r2 concept: 'support-not-proof element: 'support-wording-and-qualification)
                            (.o view: 'context-lesson revision: 'r2 concept: 'plain-alternative element: 'incompatible-plugs) (.o view: 'context-lesson revision: 'r1 concept: 'two-times element: 'event-and-receipt-marks)
                            (.o view: 'context-lesson revision: 'r1 concept: 'scoped-knowledge element: 'notebook-with-limits)) representations: (list (.o identity: 'r3-time subject: 'counterexample state: 'late-arrival asset-ref: "dev/d2/examples/time-window/r3.svg")
                              (.o identity: 'r3-knowledge subject: 'diagnostic-method state: 'contested asset-ref: "dev/d2/examples/time-window/r3.svg")
                              (.o identity: 'r3-support subject: 'stale-inputs state: 'contested asset-ref: "dev/d2/examples/time-window/r3.svg")
                              (.o identity: 'r3-alternative subject: 'compiler-abi state: 'open asset-ref: "dev/d2/examples/time-window/r3.svg") (.o identity: 'r2-time subject: 'counterexample state: 'late-arrival asset-ref: "dev/d2/examples/time-window/r2.svg")
                              (.o identity: 'r2-knowledge subject: 'diagnostic-method state: 'contested asset-ref: "dev/d2/examples/time-window/r2.svg")
                              (.o identity: 'r2-support subject: 'stale-inputs state: 'contested asset-ref: "dev/d2/examples/time-window/r2.svg")
                              (.o identity: 'r2-alternative subject: 'compiler-abi state: 'open asset-ref: "dev/d2/examples/time-window/r2.svg") (.o identity: 'time-scene subject: 'counterexample state: 'late-arrival asset-ref: "dev/d2/examples/time-window/r1.svg")
                              (.o identity: 'knowledge-scene subject: 'diagnostic-method state: 'contested asset-ref: "dev/d2/examples/time-window/r1.svg")) makes-visible: (list (.o candidate: 'r3-time facet: 'event-versus-known)
                            (.o candidate: 'r3-knowledge facet: 'age-is-not-admission)
                            (.o candidate: 'r3-support facet: 'support-is-not-proof)
                            (.o candidate: 'r3-alternative facet: 'plain-alternative) (.o candidate: 'r2-time facet: 'event-versus-known)
                            (.o candidate: 'r2-knowledge facet: 'age-is-not-admission)
                            (.o candidate: 'r2-support facet: 'support-is-not-proof)
                            (.o candidate: 'r2-alternative facet: 'plain-alternative) (.o candidate: 'time-scene facet: 'event-versus-known)
                            (.o candidate: 'knowledge-scene facet: 'age-is-not-admission)) meaning-reviews: (list (.o view: 'context-lesson revision: 'r3 candidate: 'r3-time)
                             (.o view: 'context-lesson revision: 'r3 candidate: 'r3-knowledge)
                             (.o view: 'context-lesson revision: 'r3 candidate: 'r3-support)
                             (.o view: 'context-lesson revision: 'r3 candidate: 'r3-alternative) (.o view: 'context-lesson revision: 'r1 candidate: 'knowledge-scene)
                             (.o view: 'context-lesson revision: 'r2 candidate: 'r2-knowledge)
                             (.o view: 'context-lesson revision: 'r2 candidate: 'r2-support)
                             (.o view: 'context-lesson revision: 'r2 candidate: 'r2-alternative))
      needs: (list (.o question: 'late-evidence concept: 'two-times)
                   (.o question: 'retention concept: 'scoped-knowledge)
                   (.o question: 'support-meaning concept: 'support-not-proof)
                   (.o question: 'alternative-meaning concept: 'plain-alternative))
      questions:
      (list (.o identity: 'support-meaning audience: 'beginner subject: 'stale-inputs
                text: "Does a green arrow prove the cause, and what does the plus mean?")
            (.o identity: 'alternative-meaning audience: 'beginner subject: 'compiler-abi
                text: "What might be incompatible? Can I understand the idea without knowing ABI?") (.o identity: 'late-evidence audience: 'beginner subject: 'counterexample
                text: "If the failed test happened early, why does it change the later view only?")
            (.o identity: 'retention audience: 'beginner subject: 'diagnostic-method
                text: "What may become reusable knowledge, and what must remain open?"))))
