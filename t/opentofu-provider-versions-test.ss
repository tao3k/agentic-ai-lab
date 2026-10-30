;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :yuanxu/profile-composition/selection-syntax
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuModule.)
        :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-provider-versions-test)

(def (assert label value)
  (unless value (error "assertion failed" label))
  (displayln "ASSERT-OK " label) (force-output))

(def (accepted? evidence) (yuanxu-validation-evidence-accepted? evidence))

(def (verify-isolation parent-path child-path parent-version child-version)
  (unless (and (string? parent-path) (string? child-path))
    (error "two real Nix Provider Schema outputs are required"))
  (assert 'two-artifact-paths (not (equal? parent-path child-path)))
  (displayln "VERSION-DIRECTION " parent-version " -> " child-version)
  ;; Upstream/build composition owns package injection.
  (.def (Parent @ OpenTofuModule.)
    config: (.o provider-artifact: parent-path purpose: 'deployment))
  (def Web
    (.o name: "web" ingress:
      (list (.o from_port: 443 to_port: 443 protocol: "tcp"
                cidr_blocks: '("10.0.0.0/16")))))
  (def parent-result
    (use-module Parent as tf
      (.call (.get tf types resources aws_security_group) .admit Web #f)))
  (assert 'parent-admitted-before-child (accepted? parent-result))
  (def parent-contract (.get Parent types resources aws_security_group))
  (def parent-provider (.get Parent provider))
  (def parent-source (.get Parent source))
  (def parent-resources (.get Parent types resources))
  (assert 'parent-contract-cached
    (eq? parent-contract (.ref/cached parent-resources 'aws_security_group)))
  (assert 'parent-package-version (equal? (.get parent-contract version) parent-version))
  (assert 'parent-origin-path (equal? (.get parent-source value) parent-path))

  ;; The only child override is the config artifact reference. All publication
  ;; and source/type methods are inherited from the already-cached Parent.
  (.def (Child @ Parent)
    config: =>.+ (.o provider-artifact: child-path))
  (assert 'child-provider-starts-unforced (not (.ref/cached Child 'provider)))
  (assert 'child-alias-inert (use-module Child as tf (eq? tf Child)))
  (assert 'child-alias-does-not-read-artifact (not (.ref/cached Child 'provider)))
  (assert 'unmodified-config-value-inherited (eq? (.get Child config purpose) 'deployment))
  (def child-result
    (use-module Child as tf
      (.call (.get tf types resources aws_security_group) .admit Web #f)))
  (assert 'child-admitted (accepted? child-result))
  (def child-contract (.get Child types resources aws_security_group))
  (def child-source (.get Child source))
  (assert 'distinct-provider-scopes (not (eq? parent-provider (.get Child provider))))
  (assert 'distinct-resource-catalogs (not (eq? parent-resources (.get Child types resources))))
  ;; Actual export difference: this resource is present only in 5.100.0.
  ;; Slot discovery must use each version's catalog without compiling it.
  (assert 'parent-catalog-matches-actual-version
    (eq? (if (.slot? parent-resources 'aws_dsql_cluster) #t #f)
         (string=? parent-version "5.100.0")))
  (assert 'child-catalog-matches-actual-version
    (eq? (if (.slot? (.get Child types resources) 'aws_dsql_cluster) #t #f)
         (string=? child-version "5.100.0")))
  (assert 'catalog-discovery-does-not-compile-new-resource
    (and (not (.ref/cached parent-resources 'aws_dsql_cluster))
         (not (.ref/cached (.get Child types resources) 'aws_dsql_cluster))))
  (assert 'distinct-native-contracts (not (eq? parent-contract child-contract)))
  (assert 'distinct-contract-identities
    (not (eq? (.get parent-contract identity) (.get child-contract identity))))
  (assert 'this-pair-has-equal-security-group-shapes
    (equal? (.get parent-contract schema) (.get child-contract schema)))
  (assert 'same-provider-family
    (equal? (.get parent-contract provider) (.get child-contract provider)))
  (assert 'child-package-version (equal? (.get child-contract version) child-version))
  (assert 'child-origin-kind (eq? (.get child-source kind) 'generated))
  (assert 'child-origin-path (equal? (.get child-source value) child-path))
  (assert 'child-origin-provider
    (equal? (.get child-source metadata provider) (.get child-contract provider)))
  (assert 'child-origin-version
    (equal? (.get child-source metadata version) child-version))
  (assert 'child-origin-schema
    (equal? (.get child-source metadata schema-digest) (.get child-contract schema-digest)))
  ;; These two actual exports differ; differing digests are NOT a general rule
  ;; that every Provider version must export a different schema.
  (assert 'this-pair-has-distinct-export-digests
    (not (equal? (.get parent-contract schema-digest) (.get child-contract schema-digest))))
  (assert 'child-admission-uses-child-contract
    (eq? (.get child-result contract-identity) (.get child-contract identity)))
  (assert 'parent-evidence-still-identifies-parent
    (eq? (.get parent-result contract-identity) (.get parent-contract identity)))
  (assert 'child-contract-cache-stable
    (eq? child-contract (.get Child types resources aws_security_group)))
  (assert 'parent-contract-cache-unchanged
    (eq? parent-contract (.get Parent types resources aws_security_group)))
  (assert 'parent-provider-unchanged (eq? parent-provider (.get Parent provider)))
  (assert 'parent-catalog-unchanged (eq? parent-resources (.get Parent types resources)))
  (assert 'parent-source-unchanged (eq? parent-source (.get Parent source)))
  (assert 'parent-version-unchanged (equal? (.get Parent provider version) parent-version))
  (assert 'parent-origin-version-unchanged
    (equal? (.get Parent source metadata version) parent-version))
  (assert 'parent-config-unchanged (equal? (.get Parent config provider-artifact) parent-path))
  (assert 'child-config-changed (equal? (.get Child config provider-artifact) child-path))
  (assert 'parent-admits-after-child
    (use-module Parent as tf
      (accepted? (.call (.get tf types resources aws_security_group) .admit Web #f))))
  (def wrong (.cc Web 'ingress (list (.o from_port: "wrong" to_port: 443 protocol: "tcp"))))
  (assert 'parent-type-rejection-remains
    (use-module Parent as tf
      (not (accepted? (.call (.get tf types resources aws_security_group) .admit wrong #f)))))
  (assert 'child-type-rejection-remains
    (use-module Child as tf
      (not (accepted? (.call (.get tf types resources aws_security_group) .admit wrong #f)))))
  (assert 'unselected-parent-contract-stays-lazy
    (not (.ref/cached parent-resources 'aws_iam_group_membership)))
  (assert 'unselected-child-contract-stays-lazy
    (not (.ref/cached (.get Child types resources) 'aws_iam_group_membership))))

(def opentofu-provider-versions-test
  (test-suite "opentofu-provider-versions-test"
    (yuanxu-test-case "real AWS upgrade after parent Contract caching"
      (verify-isolation
        (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_PARENT_ARTIFACT" #f)
        (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_CHILD_ARTIFACT" #f)
        "5.99.0" "5.100.0"))
    (yuanxu-test-case "real AWS rollback after parent Contract caching"
      (verify-isolation
        (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_CHILD_ARTIFACT" #f)
        (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_PARENT_ARTIFACT" #f)
        "5.100.0" "5.99.0"))))
