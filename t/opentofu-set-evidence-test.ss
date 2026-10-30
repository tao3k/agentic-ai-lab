;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/modules/services/opentofu/objects agentic-ai-lab-opentofu-block-contract agentic-ai-lab-opentofu-configuration-contract)
        (only-in :agentic-ai-lab/modules/services/opentofu/collections agentic-ai-lab-opentofu-value-digest)
        (only-in :agentic-ai-lab/modules/services/opentofu/collections agentic-ai-lab-opentofu-string-set-authority)
        (only-in :yuanxu/modules/json-schema/json-schema-source yuanxu-json-schema-read-file)
        :yuanxu/object-types/contracts
        :clan/poo/object)
(export opentofu-set-evidence-test)

(def opentofu-set-evidence-test
  (test-suite "opentofu-set-evidence-test"
    (yuanxu-test-case "bound collection evidence and native admission"
      (def (assert label value)
        (unless value (error "assertion failed" label))
        (displayln "ASSERT-OK " label) (force-output))
      (def (accepted? evidence) (yuanxu-validation-evidence-accepted? evidence))
      (def (reason? result reason)
        (find (lambda (d) (eq? (.get d reason) reason)) (.get result diagnostics)))
      ;; Explicit synthetic provider: historical AWS fixture lacks a plugin
      ;; version and is never mislabeled as source-qualified string hash proof.
      (def block '((attributes .
                    ((accounts . ((type . ("set" "string")) (required . #t)))
                     (peers . ((type . ("set" "string")) (optional . #t)))
                     (name . ((type . "string") (optional . #t)))))))
      (def now 100)
      (def authority
        (agentic-ai-lab-opentofu-string-set-authority
          "test/provider" "1.0.0" block '((accounts) (peers)) (lambda () now)))
      (def Contract (agentic-ai-lab-opentofu-block-contract 'test/provider block authority))
      (def raw '((accounts . ("b" "a" "b"))))
      (def candidate (.get (.call Contract .normalize raw) value))
      (def proof (.call Contract .prove candidate 10))
      (assert 'normalized (equal? candidate '((accounts . ("b" "a")))))
      (assert 'proof-issued (= (length (.get proof receipts)) 1))
      (assert 'proof-no-failure (null? (.get proof diagnostics)))
      (##gc) ; retained context must keep weak-registry bindings live
      (assert 'string-admitted (accepted? (.call (.get Contract collection-contract) .admit candidate proof)))
      (assert 'missing-rejected
        (reason? (.call (.get Contract collection-contract) .admit candidate #f) 'provider-set-identity-unresolved))
      (assert 'forged-rejected
        (reason? (.call (.get Contract collection-contract) .admit candidate
                   (.o receipts: (list (.o accepted?: #t)))) 'provider-set-evidence-forged))
      (def receipt (car (.get proof receipts)))
      (assert 'copied-prototype-rejected
        (reason? (.call (.get Contract collection-contract) .admit candidate
                   (.o receipts: (list (.cc receipt 'expires 10000)))) 'provider-set-evidence-forged))
      ;; Public audit fields never alias private digest/path records.
      (string-set! (.get receipt candidate-digest) 0 #\x)
      (string-set! (.get authority schema) 0 #\x)
      (set-car! (.get receipt field) 'changed)
      (assert 'audit-mutation-does-not-change-proof
        (accepted? (.call (.get Contract collection-contract) .admit candidate proof)))
      (assert 'changed-set-rejected
        (reason? (.call (.get Contract collection-contract) .admit '((accounts . ("different"))) proof)
                 'provider-set-evidence-candidate-mismatch))
      (assert 'changed-sibling-rejected
        (reason? (.call (.get Contract collection-contract) .admit '((accounts . ("b" "a")) (name . "changed")) proof)
                 'provider-set-evidence-candidate-mismatch))
      (def unnormalized-proof (.call Contract .prove raw 10))
      (assert 'duplicates-still-rejected
        (reason? (.call (.get Contract collection-contract) .admit raw unnormalized-proof) 'set-normalization-required))
      (def expression '((accounts . ("${var.account}"))))
      (assert 'expression-no-proof (null? (.get (.call Contract .prove expression) receipts)))
      (assert 'expression-rejected
        (not (accepted? (.call (.get Contract collection-contract) .admit expression (.call Contract .prove expression)))))
      (set! now 110)
      (assert 'expiry-boundary
        (reason? (.call (.get Contract collection-contract) .admit candidate proof) 'provider-set-evidence-expired))
      (assert 'fresh-proof-accepted
        (accepted? (.call (.get Contract collection-contract) .admit candidate (.call Contract .prove candidate))))
      (assert 'ttl-bounded (null? (.get (.call Contract .prove candidate 3601) receipts)))
      (def v2 (agentic-ai-lab-opentofu-string-set-authority
                "test/provider" "2.0.0" block '((accounts)) (lambda () now)))
      (def V2Contract (agentic-ai-lab-opentofu-block-contract 'test/v2 block v2))
      (assert 'version-replay-rejected
        (reason? (.call (.get V2Contract collection-contract) .admit candidate (.call Contract .prove candidate))
                 'provider-set-evidence-forged))
      (def other-provider (agentic-ai-lab-opentofu-string-set-authority
                            "other/provider" "1.0.0" block '((accounts)) (lambda () now)))
      (def OtherContract (agentic-ai-lab-opentofu-block-contract 'test/other block other-provider))
      (assert 'provider-replay-rejected
        (not (accepted? (.call (.get OtherContract collection-contract) .admit candidate (.call Contract .prove candidate)))))
      (def other-schema '((attributes . ((accounts . ((type . ("set" "string")) (required . #t)))))))
      (assert 'schema-binding-construction-rejected
        (with-catch (lambda (_) #t)
          (lambda () (agentic-ai-lab-opentofu-block-contract 'wrong other-schema authority) #f)))
      (def restricted (agentic-ai-lab-opentofu-string-set-authority
                        "test/provider" "1.0.0" block '((peers)) (lambda () now)))
      (def Restricted (agentic-ai-lab-opentofu-block-contract 'restricted block restricted))
      (assert 'field-not-enrolled
        (null? (.get (.call Restricted .prove candidate) receipts)))
      ;; A full candidate digest also prevents moving proofs across identical
      ;; fields/instances. Field selection is not inferred from visible tags.
      (def both '((accounts . ("a")) (peers . ("a"))))
      (def both-proof (.call Contract .prove both))
      (assert 'two-fields-admitted (accepted? (.call (.get Contract collection-contract) .admit both both-proof)))
      (assert 'field-replay-rejected
        (reason? (.call (.get Contract collection-contract) .admit both
                   (.o receipts: (list (car (.get both-proof receipts)))))
                 'provider-set-evidence-path-mismatch))
      (def ConfigurationContract
        (agentic-ai-lab-opentofu-configuration-contract '() (list (cons 'test_resource block)) '()
          (.o resource: (.o test_resource: authority))))
      (def config `((resource . ((test_resource . ((web . ,candidate)))))))
      (def config-proof (.call ConfigurationContract .prove config))
      (assert 'configuration-proof (null? (.get config-proof diagnostics)))
      (assert 'configuration-admitted (accepted? (.call (.get ConfigurationContract collection-contract) .admit config config-proof)))
      (assert 'block-proof-not-configuration-proof
        (not (accepted? (.call (.get ConfigurationContract collection-contract) .admit config (.call Contract .prove candidate)))))
      (def changed-config '((resource . ((test_resource . ((web . ((accounts . ("changed"))))))))))
      (def changed-result (.call (.get ConfigurationContract collection-contract) .admit changed-config config-proof))
      (assert 'configuration-rejects-stale
        (reason? changed-result 'provider-set-evidence-candidate-mismatch))
      (assert 'configuration-qualified-path
        (equal? (.get (car (.get changed-result diagnostics)) path)
                '(resource test_resource web accounts)))
      (assert 'wire-order-independent
        (equal? (agentic-ai-lab-opentofu-value-digest '((a . 1) (b . 2)))
                (agentic-ai-lab-opentofu-value-digest '((b . 2) (a . 1)))))
      ;; Real fixtures remain useful rejection controls, not invented attestations.
      (def aws (yuanxu-json-schema-read-file "t/fixtures/opentofu/aws-security-group.json"))
      (def AwsContract (agentic-ai-lab-opentofu-block-contract 'aws/security-group aws))
      (def sg '((name . "demo") (ingress . (((from_port . 443) (to_port . 443)
                        (protocol . "tcp") (security_groups . ("sg-a" "sg-a")))))))
      (def sg-normal (.get (.call AwsContract .normalize sg) value))
      (assert 'real-aws-custom-hash-unresolved
        (reason? (.call (.get AwsContract collection-contract) .admit sg-normal (.call AwsContract .prove sg-normal))
                 'provider-set-identity-unresolved))
      (assert 'real-aws-no-custom-proof (null? (.get (.call AwsContract .prove sg-normal) receipts)))
      ;; Even an enrolled field never converts object-set equality into strings.
      (def aws-authority (agentic-ai-lab-opentofu-string-set-authority
                           "test/aws-shape" "fixture-control-1" aws '((ingress)) (lambda () now)))
      (def BoundAws (agentic-ai-lab-opentofu-block-contract 'aws/control aws aws-authority))
      (assert 'object-policy-cannot-mint (null? (.get (.call BoundAws .prove sg-normal) receipts)))
      (assert 'object-policy-still-rejected
        (not (accepted? (.call (.get BoundAws collection-contract) .admit sg-normal (.call BoundAws .prove sg-normal)))))
      (def inner-authority
        (agentic-ai-lab-opentofu-string-set-authority
          "test/aws-shape" "fixture-control-1" aws
          '((ingress 0 security_groups)) (lambda () now)))
      (def InnerAws (agentic-ai-lab-opentofu-block-contract 'aws/inner-control aws inner-authority))
      (def inner-proof (.call InnerAws .prove sg-normal))
      (assert 'real-shape-inner-literal-proof (= (length (.get inner-proof receipts)) 1))
      (assert 'real-shape-outer-still-unresolved
        (reason? (.call (.get InnerAws collection-contract) .admit sg-normal inner-proof) 'provider-set-identity-unresolved))
      (assert 'string-key-paths
        (accepted? (.call (.get Contract collection-contract) .admit
                     '(("accounts" . ("a")))
                     (.call Contract .prove '(("accounts" . ("a")))))))
      (assert 'schema-mutation-rejected
        (let* ((mutable-block (list (cons 'attributes
                                     (list (cons 'accounts
                                             '((type . ("set" "string")) (required . #t)))))))
               (auth (agentic-ai-lab-opentofu-string-set-authority
                       "test/provider" "1.0.0" mutable-block '((accounts))))
               (bound (agentic-ai-lab-opentofu-block-contract 'mutable mutable-block auth))
               (value '((accounts . ("a"))))
               (evidence (.call bound .prove value)))
          (set-cdr! mutable-block '((description . "changed")))
          (not (accepted? (.call (.get bound collection-contract) .admit value evidence)))))
      (displayln "OPENTOFU-SET-EVIDENCE-OK"))))
