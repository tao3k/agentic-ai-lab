;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/modules/services/opentofu/objects agentic-ai-lab-opentofu-block-contract agentic-ai-lab-opentofu-configuration-contract agentic-ai-lab-opentofu-normalize-block)
        (only-in :agentic-ai-lab/modules/services/opentofu/func agentic-ai-lab-opentofu-cty->schema)
        (only-in :yuanxu/modules/json-schema/json-schema-contract yuanxu-json-schema->contract)
        (only-in :yuanxu/modules/json-schema/json-schema-receipt yuanxu-json-schema->contract-artifact yuanxu-json-schema-contract-artifact-normalization)
        (only-in :yuanxu/modules/json-schema/json-schema-validate yuanxu-json-schema-contract-artifact-validate)
        (only-in :yuanxu/modules/json-schema/json-schema-valid yuanxu-json-schema-node-valid?)
        (only-in :yuanxu/modules/json-schema/json-schema-validate yuanxu-json-schema-node-validate yuanxu-json-schema-object-contract-validation-valid?)
        (only-in :yuanxu/modules/json-schema/json-schema-ir yuanxu-json-schema-normalization-schema)
        (only-in :yuanxu/modules/json-schema/json-schema-source yuanxu-json-schema-read-file)
        (only-in :yuanxu/modules/json-schema/json-schema-diagnostics yuanxu-json-schema-validation-diagnostic-metadata)
        (only-in :yuanxu/modules/json-schema/json-schema-ir
                 yuanxu-json-schema-normalization-schema)
        :yuanxu/object-types/contracts
        :clan/poo/object)
(export opentofu-schema-test)
(def opentofu-schema-test
  (test-suite "opentofu-schema-test"
    (yuanxu-test-case "provider conversion and native admission"
        (def (assert label value) (unless value (error "assertion failed" label)) (displayln "ASSERT-OK " label) (force-output))
        (def (accepted? contract candidate)
          (yuanxu-validation-evidence-accepted? (.call contract .admit candidate #f)))
        (def (collection-accepted? contract candidate)
          (yuanxu-validation-evidence-accepted?
            (.call (.get contract collection-contract) .admit candidate #f)))
        (def (node schema)
          (yuanxu-json-schema-normalization-schema
            (yuanxu-json-schema-contract-artifact-normalization
              (yuanxu-json-schema->contract-artifact schema))))
        (def (valid? schema value) (yuanxu-json-schema-node-valid? (node schema) value))
        (def (reason? diagnostics reason)
          (find (lambda (d) (eq? (.get d reason) reason)) diagnostics))
        (def unique-schema '((type . "array") (uniqueItems . #t) (items . #t)))
        (assert 'unique-distinct (valid? unique-schema '("a" "b")))
        (assert 'unique-duplicate (not (valid? unique-schema '("a" "a"))))
        (assert 'unique-numeric (not (valid? unique-schema '(1 1.0))))
        (assert 'unique-record-order
          (not (valid? unique-schema '(((a . 1) (b . 2)) ((b . 2) (a . 1))))))
        (assert 'unique-nested-array
          (not (valid? unique-schema '(#("a" "b") #("a" "b")))))
        (assert 'unique-false (valid? '((type . "array") (uniqueItems . #f)) '("a" "a")))
        ;; Synthetic tuple; neither downloaded AWS fixture contains one.
        (def tuple-schema (agentic-ai-lab-opentofu-cty->schema '("tuple" ("string" "number"))))
        (assert 'tuple-valid (valid? tuple-schema '("x" 2)))
        (assert 'tuple-index (not (valid? tuple-schema '(2 "x"))))
        (assert 'tuple-short (not (valid? tuple-schema '("x"))))
        (assert 'tuple-long (not (valid? tuple-schema '("x" 2 3))))
        (assert 'tuple-empty (valid? (agentic-ai-lab-opentofu-cty->schema '("tuple" ())) '()))
        (def tuple-artifact (yuanxu-json-schema->contract-artifact
          `((type . "object") (properties . ((pair . ,tuple-schema))))))
        (assert 'tuple-emitted
          (yuanxu-json-schema-object-contract-validation-valid?
            (yuanxu-json-schema-contract-artifact-validate tuple-artifact '((pair . ("x" 2))))))
        (assert 'tuple-emitted-invalid
          (not (yuanxu-json-schema-object-contract-validation-valid?
            (yuanxu-json-schema-contract-artifact-validate tuple-artifact '((pair . (2 "x")))))))
        (def aws (yuanxu-json-schema-read-file "t/fixtures/opentofu/aws-security-group.json"))
        (def awscc (yuanxu-json-schema-read-file "t/fixtures/opentofu/awscc-provider.json"))
        (def AwsContract (agentic-ai-lab-opentofu-block-contract 'aws/security-group aws))
        (def AwsccContract (agentic-ai-lab-opentofu-block-contract 'awscc/provider awscc))
        (assert 'awscc-nested (accepted? AwsccContract '((assume_role . ((duration . "900"))))))
        (assert 'awscc-nested-wrong (not (accepted? AwsccContract '((assume_role . ((duration . 900)))))))
        (assert 'awscc-unknown (not (accepted? AwsccContract '((assume_role . ((duraton . "900")))))))
        (def StringsBlock '((attributes . ((accounts . ((type . ("set" "string")) (required . #t)))))))
        (def StringsContract (agentic-ai-lab-opentofu-block-contract 'string-set StringsBlock))
        (def normalized (agentic-ai-lab-opentofu-normalize-block StringsBlock '((accounts . ("b" "a" "b")))))
        (assert 'string-set-normalized (equal? (.get normalized value) '((accounts . ("b" "a")))))
        (assert 'string-set-no-issue (null? (.get normalized diagnostics)))
        (assert 'string-set-shape-admit
          (accepted? (yuanxu-json-schema->contract 'cty/string-set (.get StringsContract schema))
                     (.get normalized value)))
        (assert 'string-set-provider-identity-unresolved
          (not (collection-accepted? StringsContract (.get normalized value))))
        (assert 'raw-duplicate-needs-normalization (not (collection-accepted? StringsContract '((accounts . ("a" "a"))))))
        (assert 'expression-unresolved (not (collection-accepted? StringsContract '((accounts . ("${var.account}"))))))
        (assert 'aws-empty-shape (accepted? AwsContract '((name . "demo")) ))
        (def sg '((name . "demo") (ingress . (((from_port . 443) (to_port . 443) (protocol . "tcp")
                                               (security_groups . ("sg-a" "sg-a")))))))
        (def unresolved (.call (.get AwsContract collection-contract) .admit sg #f))
        (assert 'custom-hash-unresolved (not (yuanxu-validation-evidence-accepted? unresolved)))
        (assert 'custom-hash-reason (reason? (.get unresolved diagnostics) 'provider-set-identity-unresolved))
        (assert 'forged-proof-rejected
          (not (yuanxu-validation-evidence-accepted?
            (.call (.get AwsContract collection-contract) .admit sg (.o accepted?: #t)))))
        (def ConfigurationContract
          (agentic-ai-lab-opentofu-configuration-contract (list (cons 'awscc awscc)) (list (cons 'aws_security_group aws)) '()))
        (assert 'custom-hash-not-required-for-configuration (accepted? AwsContract sg))
        (assert 'duplicates-are-config-not-identity
          (accepted? StringsContract '((accounts . ("a" "a")))))
        (assert 'configuration-with-custom-set-admitted
          (accepted? ConfigurationContract `((resource . ((aws_security_group . ((web . ,sg))))))))
        (assert 'configuration-valid
          (accepted? ConfigurationContract '((provider . ((awscc . (((assume_role . ((duration . "900"))))))))
                                             (resource . ((aws_security_group . ((web . ((name . "demo"))))))))))
        (assert 'configuration-custom-hash-unresolved
          (not (collection-accepted? ConfigurationContract `((resource . ((aws_security_group . ((web . ,sg)))))))))
        (assert 'configuration-unknown-resource
          (not (accepted? ConfigurationContract '((resource . ((aws_unknown . ((x . ())))))))))
        (assert 'computed-only-rejected
          (not (accepted? AwsContract '((arn . "arn:aws:ec2:demo")))))
        ;; Every entrypoint must agree, not just the boolean fast path.
        (def UniqueContract (yuanxu-json-schema->contract 'unique unique-schema))
        (assert 'unique-public-admit (not (accepted? UniqueContract '("a" "a")) ))
        (assert 'unique-diagnostic (pair? (.get (.call UniqueContract .admit '("a" "a") #f) diagnostics)))
        (assert 'unique-path-validate
          (pair? (yuanxu-json-schema-node-validate (node unique-schema) '("a" "a") '(outputs))))
        (def unique-object-artifact (yuanxu-json-schema->contract-artifact
          `((type . "object") (properties . ((outputs . ,unique-schema))))))
        (assert 'unique-emitted-records
          (yuanxu-json-schema-object-contract-validation-valid?
            (yuanxu-json-schema-contract-artifact-validate unique-object-artifact
              '((outputs . (((name . "a")) ((name . "b"))))))))
        (assert 'unique-emitted-reject
          (not (yuanxu-json-schema-object-contract-validation-valid?
            (yuanxu-json-schema-contract-artifact-validate unique-object-artifact
              '((outputs . (((name . "a")) ((name . "a")))))))))
        (assert 'tuple-vector (valid? tuple-schema '#("x" 2)))
        (assert 'tuple-index-path
          (equal? (cdr (assoc 'path
            (yuanxu-json-schema-validation-diagnostic-metadata
              (car (yuanxu-json-schema-node-validate (node tuple-schema) '("x" "bad") '(pair))))))
            '(pair 1)))
        (assert 'tuple-reference
          (valid? '((type . "array") (items . ((($ref . "#/$defs/Name")) ((type . "number"))))
                    ($defs . ((Name . ((type . "string")))))) '("x" 1)))
        (assert 'awscc-null (accepted? AwsccContract '((assume_role . null))))
        (assert 'computed-optional-retained (accepted? AwsContract '((id . "sg-123"))))
        (def wrong (.call AwsccContract .admit '((assume_role . ((duration . 900)))) #f))
        (assert 'native-error-path
          (equal? (cdr (assoc 'path (yuanxu-json-schema-validation-diagnostic-metadata
                                     (car (.get wrong diagnostics))))) '(assume_role duration)))
        (assert 'normalize-malformed-safe
          (pair? (.get (agentic-ai-lab-opentofu-normalize-block awscc
                          '((assume_role . ((duration . 900))))) diagnostics)))
        (assert 'native-object-normalization
          (equal? (.get (agentic-ai-lab-opentofu-normalize-block StringsBlock
                          (.o accounts: '("a" "a"))) value) '((accounts . ("a")))))
        (def nested-tuple-block
          '((attributes . ((pair . ((type . ("tuple" ("string" ("set" "string")))) (required . #t)))))))
        (def NestedTupleContract (agentic-ai-lab-opentofu-block-contract 'tuple-set nested-tuple-block))
        (def nested-normal (.call NestedTupleContract .normalize '((pair . ("x" ("a" "a"))))))
        (assert 'nested-tuple-normalize (equal? (.get nested-normal value) '((pair . ("x" ("a"))))))
        (assert 'nested-tuple-shape-admit
          (accepted? (yuanxu-json-schema->contract 'cty/tuple-set (.get NestedTupleContract schema))
                     (.get nested-normal value)))
        (assert 'nested-tuple-provider-identity-unresolved
          (not (collection-accepted? NestedTupleContract (.get nested-normal value))))
        (def nested-set-block
          '((attributes . ((rules . ((optional . #t)
                    (nested_type . ((nesting_mode . "set")
                                    (attributes . ((name . ((type . "string") (required . #t)))))))))))))
        (def NestedSetContract (agentic-ai-lab-opentofu-block-contract 'nested-set nested-set-block))
        (assert 'empty-object-set-unresolved (not (collection-accepted? NestedSetContract '((rules . ())))))
        (def final-unresolved (.call (.get ConfigurationContract collection-contract) .admit
                                `((resource . ((aws_security_group . ((web . ,sg)))))) #f))
        (assert 'provider-reason-qualified-path
          (find (lambda (diagnostic)
                  (equal? (.get diagnostic path) '(resource aws_security_group web ingress)))
                (.get final-unresolved diagnostics)))
        (assert 'unsupported-dynamic-rejected
          (with-catch (lambda (_) #t)
                      (lambda () (agentic-ai-lab-opentofu-cty->schema "dynamic") #f)))
        (def sg-normalized (.call AwsContract .normalize sg))
        (assert 'inner-string-set-normalized
          (equal? (cdr (assoc 'security_groups
                     (car (cdr (assoc 'ingress (.get sg-normalized value)))))) '("sg-a")))
        (assert 'outer-hash-still-unresolved
          (reason? (.get sg-normalized diagnostics) 'provider-set-identity-unresolved))
        (assert 'decoded-null-admit
          (accepted? AwsccContract (list (cons 'assume_role (void)))))
        (assert 'decoded-null-normalization
          (void? (cdr (assoc 'assume_role
                     (.get (.call AwsccContract .normalize
                              (list (cons 'assume_role (void)))) value)))))
        (assert 'invalid-unique-schema-rejected
          (with-catch (lambda (_) #t)
            (lambda ()
              (yuanxu-json-schema->contract 'invalid-unique
                '((type . "array") (uniqueItems . "true"))) #f)))
        (displayln "OPENTOFU-COLLECTIONS-OK"))))
