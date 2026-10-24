;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scale gate for inert Sandbox Profile construction and explicit list policy.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :std/test check-equal? test-suite)
        :agentic-ai-lab/modules/nono-sandbox/config
        :agentic-ai-lab/modules/agent-sandbox/config)

(export sandbox-profile-object-composition-performance-test)

(def +sandbox-profile-composition-count+ 1000)
(def +sandbox-profile-composition-maximum-ms+ 3000)

(def (sandbox-profile-composition-name index)
  (string->symbol
   (string-append "profile/" (number->string index))))

(def (sandbox-profile-composition-build count)
  (let loop ((index 0) (profiles '()))
    (if (= index count)
      (reverse profiles)
      (loop (+ index 1)
            (cons
             (agentic-ai-lab-nono-sandbox-profile-config
              (sandbox-profile-composition-name index)
              '((capabilities :append filesystem-write)
                (capabilities :remove filesystem-read)
                (metadata (stage . benchmark))))
             profiles)))))

(def sandbox-profile-object-composition-performance-test
  (test-suite "Sandbox Profile POO composition performance"
    (yuanxu-test-case "1000 inert profiles retain ordered list policy"
      (let* ((started (current-jiffy))
             (profiles
              (sandbox-profile-composition-build
               +sandbox-profile-composition-count+))
             (elapsed-ms
              (quotient
               (* (- (current-jiffy) started) 1000)
               (jiffies-per-second))))
        (displayln "[agentic-ai-lab-benchmark] sandbox-profile-composition count="
                   +sandbox-profile-composition-count+
                   " elapsedMs=" elapsed-ms
                   " maxMs=" +sandbox-profile-composition-maximum-ms+)
        (force-output)
        (check-equal? (length profiles) +sandbox-profile-composition-count+)
        (check-equal?
         (agentic-ai-lab-sandbox-profile-capabilities (car profiles))
         '(process filesystem tmpdir filesystem-write))
        (check-equal? (<= elapsed-ms
                          +sandbox-profile-composition-maximum-ms+)
                      #t)))))
