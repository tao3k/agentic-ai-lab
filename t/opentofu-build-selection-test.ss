;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :std/encoding/json write-json)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :yuanxu/profile-composition/selection-syntax
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope.) (only-in :yuanxu/modules/json-schema/json-schema-diagnostics yuanxu-json-schema-validation-diagnostic-metadata) :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-build-selection-test)
(def (assert label value)
  (unless value (error "assertion failed" label))
  (displayln "ASSERT-OK " label) (force-output))
(def (inputs candidate) (.call OpenTofuScope. .build-inputs candidate))
(def (providers candidate) (.get (inputs candidate) providers))
(def (accepted? result) (yuanxu-validation-evidence-accepted? result))

(def opentofu-build-selection-test
  (test-suite "opentofu-build-selection-test"
    (yuanxu-test-case "final keys select package inputs before artifact injection"
      (.def Configuration
        resource: (.o aws_security_group: (.o web: (.o name: "web"))))
      (assert 'aws-only-demand (equal? (providers Configuration) '("aws")))
      (assert 'request-keeps-type-path
        (equal? (.get (car (.get (inputs Configuration) demands)) path)
                '(resource aws_security_group)))
      (.def (Parent @ Configuration)
        provider: (.o aws: (error "provider values must remain lazy"))
        data: (.o aws_region: (error "data instances must remain lazy")))
      (assert 'keys-not-instance-values (equal? (providers Parent) '("aws")))
      (.def (Child @ Parent)
        resource: =>.+ (.o null_resource: (error "instance must remain lazy")))
      (assert 'child-demand-uses-final-keys (equal? (providers Child) '("aws" "null")))
      (assert 'parent-demand-unchanged (equal? (providers Parent) '("aws")))
      (assert 'data-only-owner (equal? (providers (.o data: (.o awscc_ec2_security_group: #f))) '("awscc")))
      (assert 'empty-demand (null? (providers (.o))))
      (assert 'json-alist-keys
        (equal? (providers '(("resource" . (("aws_security_group" . #f))))) '("aws")))
      (assert 'json-hash-keys
        (equal? (providers (list->hash-table
                 (list (cons "resource" (list->hash-table
                   (list (cons "null_resource" #f))))))) '("null")))
      (check-exception (inputs (.o resource: 42)) error?)
      (check-exception (inputs (.o resources: (.o))) error?)
      (check-exception (inputs (.o resource: (.o typo: #f))) error?)
      (assert 'projection-never-demands-artifact (not (.ref/cached OpenTofuScope. 'modules)))
      ;; Wire projection consumed by Nix; not a second user selection list.
      (let (output (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_SELECTION" #f))
        (when output
          (call-with-output-file output
            (lambda (port)
              (write-json port (list->hash-table
                            (list (cons 'providers (list->vector (providers Configuration))))))))))
      ;; Second phase runs against the real AWS-only Nix output.
      (when (getenv "AGENTIC_AI_LAB_OPENTOFU_ARTIFACT" #f)
       (let ()
        (def Contract (.get OpenTofuScope. types configuration))
        (def parent (.call Contract .admit Configuration #f))
        (assert 'real-aws-admitted (accepted? parent))
        (assert 'only-aws-built (equal? (.all-slots (.get OpenTofuScope. modules)) '(aws)))
        (.def (WithGroup @ Configuration)
          resource: =>.+ (.o aws_iam_group: (.o release: (.o name: "release"))))
        (assert 'same-provider-new-type-keeps-build-selection (equal? (providers WithGroup) '("aws")))
        (assert 'cached-contract-admits-final-child
          (accepted? (.call Contract .admit WithGroup #f)))
        (assert 'parent-children-unchanged (= (length (.get parent classification children)) 1))
        (def artifact (.get OpenTofuScope. modules aws provider artifact))
        (assert 'new-type-input-read-once (= (.call artifact .entry-read-count 'aws_iam_group 'resource) 1))
        (assert 'unselected-type-unread (= (.call artifact .entry-read-count 'aws_s3_bucket 'resource) 0))
        (def sg (.call (.get OpenTofuScope. modules aws provider) .contract 'aws_security_group 'resource))
        (assert 'version-lock-preserved (equal? (.get sg version) "5.100.0"))
        (assert 'source-lock-preserved
          (equal? (.get sg schema-digest) "7e4fc064120609e23bc317629f1308d72891b7241993fbf68be523f03b6c633c"))
        (def bad (.call Contract .admit
                    (.o resource: (.o aws_security_group:
                      (.o web: (.o ingress: (list (.o from_port: "bad" to_port: 443 protocol: "tcp")))))) #f))
        (assert 'invalid-port-rejected (not (accepted? bad)))
        (assert 'full-error-path
          (find (lambda (diagnostic)
                  (equal? (cdr (assoc 'path (yuanxu-json-schema-validation-diagnostic-metadata diagnostic)))
                          '(resource aws_security_group web ingress 0 from_port)))
                (.get bad diagnostics)))
        (.def (NeedsNull @ Configuration)
          resource: =>.+ (.o null_resource: (.o smoke: (.o))))
        (assert 'missing-package-rejected (not (accepted? (.call Contract .admit NeedsNull #f)))))))))
