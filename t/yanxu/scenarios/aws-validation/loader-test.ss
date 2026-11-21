;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :clan/poo/object .get .ref/cached .slot?)
        (only-in "../../../../init.ss" tao3k/agentic-ai-lab.init.exports))
(export aws-validation-loader-test)

(def aws-validation-loader-test
  (test-suite "AWS validation scenario selection"
    (test-case "the declared scenario has a leaf before provider realization"
      (def scenarios (.get tao3k/agentic-ai-lab.init.exports scenarios))
      (check-equal? (.slot? scenarios 'aws-validation) #t)
      (check-equal? (.ref/cached scenarios 'aws-validation) #f))))
