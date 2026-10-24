;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        "./fixtures/opentofu/aws-5.100.0/qualification.ss"
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/feature-system/source-lock-feature sources-lock-value)
        (only-in :agentic-ai-lab/modules/services/opentofu/objects agentic-ai-lab-opentofu-configuration-contract)
        (only-in :agentic-ai-lab/modules/services/opentofu/aws-hash agentic-ai-lab-opentofu-aws-string-hash agentic-ai-lab-opentofu-aws-rule-hash)
        (only-in :agentic-ai-lab/modules/services/opentofu/types ProviderSelectionContract)
        (only-in :agentic-ai-lab/modules/services/opentofu/aws-hash agentic-ai-lab-opentofu-aws-rule-key)
        (only-in :yuanxu/modules/json-schema/json-schema-source yuanxu-json-schema-read-file)
        (only-in :yuanxu/modules/json-schema/json-schema-diagnostics yuanxu-json-schema-validation-diagnostic-metadata)
        :yuanxu/object-types/contracts
        :clan/poo/object)
(export opentofu-aws-source-test)

(def root "t/fixtures/opentofu/aws-5.100.0/")
(def (read-source id) (call-with-input-file (string-append root id) read-all-as-u8vector))
(def (read-control id) (yuanxu-json-schema-read-file (string-append root id)))
(def (ref rows key) (cdr (assoc key rows)))

(def opentofu-aws-source-test
  (test-suite "opentofu-aws-source-test"
    (yuanxu-test-case "real pinned AWS source, Schema and native collection admission"
      (def (assert label value)
        (unless value (error "assertion failed" label))
        (displayln "ASSERT-OK " label) (force-output))
      (def (accepted? r) (yuanxu-validation-evidence-accepted? r))
      (def (reason? r reason)
        (find (lambda (d) (eq? (.get d reason) reason)) (.get r diagnostics)))
      (def selection (.o provider: "registry.terraform.io/hashicorp/aws" version: "5.100.0"))
      (def lock (agentic-ai-lab-opentofu-aws-sources-lock))
      (def request (.cc (.o) 'selection selection 'lock lock 'read read-source))
      (assert 'selection-contract (accepted? (.call ProviderSelectionContract .admit selection #f)))
      (assert 'malformed-selection
        (not (accepted? (.call ProviderSelectionContract .admit
                         (.cc selection 'version "latest") #f))))
      (assert 'real-source-admitted (accepted? (.call AwsProviderSourceContract .admit request #f)))
      (assert 'version-rejected
        (reason? (.call AwsProviderSourceContract .admit
                   (.cc request 'selection (.cc selection 'version "5.99.0")) #f)
                 'provider-version-mismatch))
      (def (wrong-schema id)
        (let (bytes (read-source id))
          (if (string=? id "schema.json") (u8vector-append bytes #u8(32)) bytes)))
      (assert 'schema-bytes-rejected
        (reason? (.call AwsProviderSourceContract .admit (.cc request 'read wrong-schema) #f)
                 'provider-schema-mismatch))
      (def (wrong-source id)
        (if (string=? id "sdk-set.go") #u8(0) (read-source id)))
      (assert 'sdk-source-bytes-rejected
        (reason? (.call AwsProviderSourceContract .admit (.cc request 'read wrong-source) #f)
                 'provider-source-payload-mismatch))
      (assert 'lock-root-rejected
        (reason? (.call AwsProviderSourceContract .admit
                   (.cc request 'lock (.cc lock 'digest "sha256:wrong")) #f)
                 'provider-source-lock-mismatch))
      ;; A self-consistent altered lock is still checked against maintained pins.
      (def changed-lock
        (sources-lock-value "opentofu/aws" "5.100.0" #f
          (map (lambda (entry) (.cc entry 'exact-version "5.99.0")) (.get lock entries))))
      (assert 'repinned-version-rejected
        (reason? (.call AwsProviderSourceContract .admit (.cc request 'lock changed-lock) #f)
                 'provider-source-lock-mismatch))
      (def aws (agentic-ai-lab-opentofu-aws-provider selection lock read-source))
      (let (public-block (.call aws .block 'aws_iam_group_membership))
        (set-cdr! public-block '((description . "tampered")))
        (assert 'published-block-does-not-alias-source
          (assoc 'attributes (.call aws .block 'aws_iam_group_membership))))
      (assert 'forged-lock-verifier-cannot-authenticate-schema
        (reason? (.call AwsProviderSourceContract .admit
                   (.cc request 'read wrong-schema
                     'lock (.cc lock '.verify (lambda (_id _bytes) (.o valid?: #t)))) #f)
                 'provider-schema-mismatch))
      (def Membership (.call aws .contract 'aws_iam_group_membership))
      (def controls (read-control "hash-controls.json"))
      (def strings (ref (ref controls 'membership) 'input))
      (def raw (.o name: "example" group: "example" users: strings))
      (def normal (.call Membership .normalize raw))
      (def value (.get normal value))
      (assert 'sdk-hash-normalization
        (equal? (list-sort string<? (ref value 'users))
                (ref (ref controls 'membership) 'normalized)))
      (assert 'sdk-collision-hash
        (every (lambda (text)
                 (= (agentic-ai-lab-opentofu-aws-string-hash text) (ref (ref controls 'collision) 'hash)))
               (ref (ref controls 'collision) 'strings)))
      (assert 'crc32-ieee-vector (= (agentic-ai-lab-opentofu-aws-string-hash "123456789") #xcbf43926))
      (def binding (.call Membership .prove value))
      (assert 'real-string-proof (= (length (.get binding receipts)) 1))
      (assert 'ordinary-admit-needs-no-manual-evidence
        (accepted? (.call Membership .admit value #f)))
      (assert 'real-string-admitted (accepted? (.call (.get Membership collection-contract) .admit value binding)))
      (assert 'raw-collision-rejected
        (reason? (.call (.get Membership collection-contract) .admit raw (.call Membership .prove raw))
                 'provider-set-hash-collision))
      (assert 'changed-candidate-rejected
        (reason? (.call (.get Membership collection-contract) .admit
                   (.o name: "changed" group: "example" users: '("alice")) binding)
                 'provider-set-evidence-candidate-mismatch))
      (assert 'forged-binding-rejected
        (reason? (.call (.get Membership collection-contract) .admit value (.o receipts: (list (.o accepted?: #t))))
                 'provider-set-evidence-forged))
      (assert 'source-type-required
        (not (accepted? (.call AwsProviderSourceContract .admit (.o accepted?: #t) #f))))
      ;; Match the actual plugin's planned canonical rule and a source-derived
      ;; CRC vector. Hash correspondence does NOT certify all SDK resource rules.
      (def rule (ref controls 'rule))
      (assert 'security-group-rule-hash
        (= (agentic-ai-lab-opentofu-aws-rule-hash rule) (ref controls 'rule_hash)))
      (assert 'protocol-alias
        (= (agentic-ai-lab-opentofu-aws-rule-hash (.cc (.o) 'from_port 443 'to_port 443
             'protocol "6" 'security_groups '("sg-a")
             'cidr_blocks '("10.0.0.0/16" "10.1.0.0/16")))
           (agentic-ai-lab-opentofu-aws-rule-hash rule)))
      (assert 'description-affects-identity
        (not (= (agentic-ai-lab-opentofu-aws-rule-hash rule)
                (agentic-ai-lab-opentofu-aws-rule-hash
                  (cons '(description . "different") (filter (lambda (r) (not (eq? (car r) 'description))) rule))))))
      (def SG (.call aws .contract 'aws_security_group))
      (def sg (.o name: "example" ingress: (list rule)))
      (def sg-normal (.get (.call SG .normalize sg) value))
      (assert 'security-group-configuration-admitted (accepted? (.call SG .admit sg #f)))
      (assert 'security-group-wrong-type-rejected
        (not (accepted? (.call SG .admit (.o ingress: (list (.o from_port: "443"))) #f))))
      (assert 'security-group-spelling-rejected
        (not (accepted? (.call SG .admit (.o ingerss: '()) #f))))
      (assert 'iam-raw-strings-configuration-admitted (accepted? (.call Membership .admit raw #f)))
      ;; Exact counterparts of admission/*.tf, checked against the real plugin.
      ;; These omissions belong to the export, not to a missing hash receipt.
      (assert 'export-cidr-gap-not-invented
        (accepted? (.call SG .admit
          (.o name: "example" ingress:
            (list (.o from_port: 443 to_port: 443 protocol: "tcp"
                      cidr_blocks: '("10.0.0.1/16")))) #f)))
      (assert 'export-nested-required-gap-not-invented
        (accepted? (.call SG .admit
          (.o name: "example" ingress:
            (list (.o to_port: 443 protocol: "tcp"))) #f)))
      (def ConfigSG
        (agentic-ai-lab-opentofu-configuration-contract '()
          (list (cons 'aws_security_group (.call aws .block 'aws_security_group))) '()))
      (assert 'real-security-group-configuration-contract
        (accepted? (.call ConfigSG .admit
          (.o resource: (.o aws_security_group: (.o example: sg))) #f)))
      (def wrong-config
        (.call ConfigSG .admit
          (.o resource: (.o aws_security_group:
            (.o example: (.o ingress: (list (.o from_port: "wrong")))))) #f))
      (assert 'configuration-type-path-preserved
        (find (lambda (diagnostic)
                (equal? (cdr (assoc 'path
                          (yuanxu-json-schema-validation-diagnostic-metadata diagnostic)))
                        '(resource aws_security_group example ingress 0 from_port)))
              (.get wrong-config diagnostics)))
      (assert 'admit-does-not-prove-or-normalize
        (accepted? (.call (.cc SG
                      '.prove (lambda _ (error "unexpected collection proof"))
                      '.normalize (lambda _ (error "unexpected normalization")))
                    .admit sg #f)))
      (assert 'inner-string-bound (= (length (.get (.call SG .prove sg-normal) receipts)) 1))
      (assert 'custom-hash-not-self-certified
        (reason? (.call (.get SG collection-contract) .admit sg-normal (.call SG .prove sg-normal))
                 'provider-set-identity-unresolved))
      (def Config
        (agentic-ai-lab-opentofu-configuration-contract '()
          (list (cons 'aws_iam_group_membership (.call aws .block 'aws_iam_group_membership))) '()
          (.o resource: (.o aws_iam_group_membership: (.call aws .authority 'aws_iam_group_membership)))))
      (def config `((resource . ((aws_iam_group_membership . ((example . ,value)))))))
      (assert 'final-configuration-admitted (accepted? (.call Config .admit config #f)))
      ;; Native source checks remain live after an earlier admission.
      (def active-read read-source)
      (def live-aws (agentic-ai-lab-opentofu-aws-provider selection lock (lambda (id) (active-read id))))
      (def Live (.call live-aws .contract 'aws_iam_group_membership))
      (def old-binding (.call Live .prove value))
      (set! active-read wrong-schema)
      (assert 'changed-source-without-proof
        (reason? (.call Live .admit value #f) 'provider-source-mismatch))
      (assert 'changed-source-after-proof
        (reason? (.call Live .admit value old-binding) 'provider-source-mismatch))
      (displayln "OPENTOFU-AWS-SOURCE-OK"))))
