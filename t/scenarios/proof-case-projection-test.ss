;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/governance/policy/authorized-effect-token
        :agentic-ai-lab/modules/proof/projections/proof-case-projection)

(export proof-case-projection-test)

(def binding
  (agentic-ai-lab-effect-binding
   "bundle" 7 "policy" "entities" "decision" "intent"
   'attempt-1 'external-tool 'python-runtime 'session-1
   1 1 'arena-1 3 0 16 "payload" 'lease-1))

(def semantic-root
  (agentic-ai-lab-semantic-root "bundle" "policy" "entities" "decision" "intent"))

(def validity (agentic-ai-lab-token-validity 10 10 20 4))

(def token
  (agentic-ai-lab-authorized-effect-token
   'token-1 'nonce-1 semantic-root binding validity 'strict 255
   'scheme-control "signature"))

(def (complete-obligations)
  (agentic-ai-lab-authorized-effect-obligations #t #t #t #t #t #t #t #t))

(def proof-case-projection-test
  (test-suite "AC-09 proof-case POO projection"
    (yuanxu-test-case "single obligation is a POO object"
      (let (obligation
            (agentic-ai-lab-proof-obligation 'policy-revision-bound 0 #t))
        (check (.ref obligation 'bit) => 0)))
    (yuanxu-test-case "canonical obligation family is order invariant"
      (let* ((canonical (complete-obligations))
             (reversed
              (agentic-ai-lab-proof-obligation-family-build
               (reverse (.ref canonical 'obligations)))))
        (check (.ref canonical 'required-mask) => 255)
        (check (.ref canonical 'present-mask) => 255)
        (check (map (lambda (item) (.ref item 'name))
                    (.ref canonical 'obligations))
               =>
               (map (lambda (item) (.ref item 'name))
                    (.ref reversed 'obligations)))))
    (yuanxu-test-case "proof case binds token roots and canonical masks"
      (let* ((roots (agentic-ai-lab-proof-evidence-roots
                     semantic-root "execution-root" #f))
             (proof-case
              (agentic-ai-lab-authorized-effect-proof-case
               token roots (complete-obligations)
               'committed 1 'strict 4 "previous-root")))
        (check (.ref proof-case 'token-id) => 'token-1)
        (check (string-length (.ref proof-case 'token-digest)) => 64)
        (check (.ref proof-case 'policy-revision) => "policy")
        (check (string-length (.ref proof-case 'effect-digest)) => 64)
        (check (.ref proof-case 'subject-binding) => "entities")
        (check (.ref proof-case 'resource-binding) => "payload")
        (check (.ref proof-case 'action-binding) => "intent")
        (check (.ref proof-case 'semantic-root) => semantic-root)
        (check (.ref proof-case 'execution-root) => "execution-root")
        (check (.ref proof-case 'required-obligation-mask) => 255)
        (check (.ref proof-case 'present-obligation-mask) => 255)
        (check (agentic-ai-lab-authorized-effect-proof-case-valid? proof-case) => #t)))
    (yuanxu-test-case "unsatisfied obligation fails proof-case validity"
      (let* ((roots (agentic-ai-lab-proof-evidence-roots
                     semantic-root "execution-root" #f))
             (obligations
              (agentic-ai-lab-authorized-effect-obligations
               #t #t #t #t #t #t #t #f))
             (proof-case
              (agentic-ai-lab-authorized-effect-proof-case
               token roots obligations 'committed 1 'strict 4 "previous-root")))
        (check (.ref obligations 'complete?) => #f)
        (check (agentic-ai-lab-authorized-effect-proof-case-valid? proof-case) => #f)))
    (yuanxu-test-case "missing and duplicate obligations fail closed"
      (let* ((canonical (complete-obligations))
             (items (.ref canonical 'obligations))
             (missing
              (with-catch
               (lambda (error) 'rejected)
               (lambda ()
                 (agentic-ai-lab-proof-obligation-family-build (cdr items))
                 'accepted)))
             (duplicate
              (with-catch
               (lambda (error) 'rejected)
               (lambda ()
                 (agentic-ai-lab-proof-obligation-family-build
                  (cons (car items) items))
                 'accepted))))
        (check missing => 'rejected)
        (check duplicate => 'rejected)))
    (yuanxu-test-case "diagnostic proof case cannot become valid"
      (let* ((roots (agentic-ai-lab-proof-evidence-roots
                     semantic-root "execution-root" #f))
             (proof-case
              (agentic-ai-lab-authorized-effect-proof-case
               token roots (complete-obligations)
               'committed 1 'diagnostic 4 "previous-root")))
        (check (agentic-ai-lab-authorized-effect-proof-case-valid? proof-case) => #f)))))
