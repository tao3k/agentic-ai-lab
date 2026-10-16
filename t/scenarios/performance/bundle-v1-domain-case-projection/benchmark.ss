;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :clan/poo/object
        :core/feature-system/interface
        "../../../../core/t/fixtures/bundle-v1-domain-case-projection.ss")

(def +agent-count+ 1000)

(def owner-started-at (time->seconds (current-time)))
(def runtime-handoff-plan
  (make-bundle-v1-domain-case-runtime-handoff-plan
   +agent-count+ +agent-count+ +agent-count+ #f))
(def owner-elapsed-seconds
  (- (time->seconds (current-time)) owner-started-at))

(unless (.ref runtime-handoff-plan 'accepted?)
  (error "1,000-agent runtime handoff owner graph rejected"
         (.alist/sort runtime-handoff-plan)))

(def projection-started-at (time->seconds (current-time)))
(def projection
  (feature-bundle-v1-project-domain-case 1 runtime-handoff-plan))
(def projection-elapsed-seconds
  (- (time->seconds (current-time)) projection-started-at))

(unless (.ref projection 'accepted?)
  (error "1,000-agent Bundle v1 Domain Case projection rejected"
         (.alist/sort projection)))

(def lowering-plan (.ref projection 'lowering-plan))
(def descriptor (.ref lowering-plan 'descriptor))

(display "schema=poo-flow.bundle-v1.domain-case-projection-benchmark.1\n")
(display "agents=")
(display +agent-count+)
(newline)
(display "resolved-handoffs=")
(display (length (.ref runtime-handoff-plan 'resolved-handoffs)))
(newline)
(display "components=")
(display (length (.ref projection 'components)))
(newline)
(display "edges=")
(display (length (.ref projection 'edges)))
(newline)
(display "evidence-obligations=")
(display (length (.ref projection 'evidence-obligations)))
(newline)
(display "arena-bytes=")
(display (.ref descriptor 'arena-bytes))
(newline)
(display "owner-elapsed-seconds=")
(display owner-elapsed-seconds)
(newline)
(display "projection-elapsed-seconds=")
(display projection-elapsed-seconds)
(newline)
(display "component-matching=compact-id-sort-merge\n")
(display "component-matching-complexity=O(n-log-n)\n")
(display "input-interface=poo-native-runtime-handoff-plan\n")
(display "json-in-hot-path=false\n")
