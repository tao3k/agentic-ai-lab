;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Expected: Marlin receives one stable POO handoff family surface.

(import (only-in :clan/poo/object .o .ref))

(def marlin-runtime-handoff-family
  (.o (kind 'marlin-runtime-handoff-family)
      (name 'marlin-runtime-handoff-family)
      (source 'agentic-ai-lab.performance.marlin-runtime-handoff)))

(def (marlin-handoff-profile profile-value
                             abi-value
                             threading-value
                             handoff-value
                             proof-value)
  (.o (family 'marlin-runtime-handoff-family)
      (profile profile-value)
      (abi abi-value)
      (threading threading-value)
      (handoff handoff-value)
      (proof proof-value)))

(def marlin-handoff-profile-value
  (marlin-handoff-profile 'marlin-runtime
                          'rust
                          'shared
                          'request-response
                          'required))

(def (marlin-handoff-hot-loop profile rounds)
  (let (abi-value (.ref profile 'abi))
    (let loop ((round 0) (accepted 0))
      (if (>= round rounds)
        accepted
        (loop (+ round 1)
              (if abi-value (+ accepted 1) accepted))))))
