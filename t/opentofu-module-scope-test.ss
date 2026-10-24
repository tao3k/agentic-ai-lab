;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :yuanxu/profile-composition/selection-syntax
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope. OpenTofuModule.)
        :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-module-scope-test)

(def opentofu-module-scope-test
  (test-suite "opentofu-module-scope-test"
    (yuanxu-test-case "module-owned package injection and bounded native admission"
      (def (assert label value)
        (unless value (error "assertion failed" label))
        (displayln "ASSERT-OK " label) (force-output))
      (def (accepted? evidence) (yuanxu-validation-evidence-accepted? evidence))
      ;; Build/test composition supplies this input; resource authors never do it.
      (def artifact-path (if (getenv "AGENTIC_AI_LAB_OPENTOFU_ARTIFACT" #f)
                            (.get OpenTofuScope. modules aws config provider-artifact)
                            "t/fixtures/opentofu/aws-5.100.0"))
      (.def (Selected @ OpenTofuModule.)
        config: (.o provider-artifact: artifact-path))
      (assert 'module-construction-inert (not (.ref/cached Selected 'provider)))
      (let (tf 'outside)
        (assert 'scope-binds-once (use-module Selected as tf (eq? tf Selected)))
        (assert 'alias-not-leaked (eq? tf 'outside)))
      (assert 'binding-does-not-read-package (not (.ref/cached Selected 'provider)))
      (def Resources (use-module Selected as tf (.get tf types resources)))
      (assert 'catalog-does-not-compile-security-group
        (not (.ref/cached Resources 'aws_security_group)))
      (def Web
        (.o name: "web" ingress:
          (list (.o from_port: 443 to_port: 443 protocol: "tcp"
                    cidr_blocks: '("10.0.0.0/16")))))
      ;; The complete downstream admission expression: only the module scope.
      (assert 'downstream-admit
        (use-module Selected as tf
          (accepted? (.call (.get tf types resources aws_security_group) .admit Web #f))))
      (def SecurityGroup (.get Resources aws_security_group))
      (assert 'contract-slot-stable (eq? SecurityGroup (.get Resources aws_security_group)))
      (assert 'unselected-check-still-lazy
        (not (.ref/cached Resources 'aws_iam_group_membership)))
      (def origin (.get Selected source))
      (assert 'generated-source (eq? (.get origin kind) 'generated))
      (assert 'package-source-retained (equal? (.get origin value) artifact-path))
      (assert 'provider-retained
        (equal? (.get SecurityGroup provider) (.get origin metadata provider)))
      (assert 'version-retained
        (equal? (.get SecurityGroup version) (.get origin metadata version)))
      (assert 'schema-digest-retained
        (equal? (.get SecurityGroup schema-digest) (.get origin metadata schema-digest)))
      (assert 'port-type-rejected
        (use-module Selected as tf
          (not (accepted? (.call (.get tf types resources aws_security_group) .admit
            (.cc Web 'ingress (list (.o from_port: "wrong" to_port: 443 protocol: "tcp"))) #f)))))
      (assert 'cidr-validator-still-provider-owned
        (use-module Selected as tf
          (accepted? (.call (.get tf types resources aws_security_group) .admit
            (.cc Web 'ingress (list (.o from_port: 443 to_port: 443 protocol: "tcp"
                                      cidr_blocks: '("10.0.0.1/16")))) #f))))
      ;; Parent provider and resource catalogs are already cached above.
      (def child-demands 0)
      (.def (Retargeted @ Selected)
        config:
        (.o provider-artifact:
            (begin (set! child-demands (+ child-demands 1)) artifact-path)))
      (assert 'configured-child-has-own-contract
        (not (eq? SecurityGroup
                 (use-module Retargeted as tf (.get tf types resources aws_security_group)))))
      (assert 'configured-child-reads-own-config-once (= child-demands 1))
      (.def (Unconfigured @ Selected)
        config: (.o provider-artifact: #f))
      (assert 'unconfigured-alias-remains-inert
        (use-module Unconfigured as tf (eq? tf Unconfigured)))
      (assert 'child-cannot-reuse-cached-parent-provider
        (with-catch (lambda (_) #t)
          (lambda ()
            (use-module Unconfigured as tf (.get tf types resources aws_security_group)) #f)))
      ;; Devenv supplies the exported default object, without user composition.
      (when (getenv "AGENTIC_AI_LAB_OPENTOFU_ARTIFACT" #f)
        (assert 'devenv-default-module-admit
          (use-module OpenTofuScope. as tf
            (accepted? (.call (.get tf types configuration) .admit
              (.o resource: (.o aws_security_group: (.o web: Web))) #f)))))
      (displayln "OPENTOFU-MODULE-SCOPE-OK"))))
