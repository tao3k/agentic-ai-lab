;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

((benchmarkKind . scenario)
 (schema . agentic-ai-lab.poo-clos-native-c4.v1)
 (sourcePath . "t/scenarios/performance/poo-clos-native-c4/scenario.ss")
 (feature . poo-clos-native-metaobject-precedence)
 (sampleCount . 40)
 (semanticGate . "projected class metaobjects must be eq? to the class pointers on the complete upstream prototype C4")
 (architectureGate . "POO CLOS must not own a parallel CPL or graph linearizer")
 (metrics construction-p50-ms warm-precedence-p50-ms)
 (tags poo clos mop c4 identity performance))
