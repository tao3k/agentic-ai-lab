;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :std/encoding/json write-json)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :yuanxu/profile-composition/selection-syntax
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope.) :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-reselected-artifact-test)
(def (assert label value)
  (unless value (error "assertion failed" label))
  (displayln "ASSERT-OK " label) (force-output))
(def (accepted? result) (yuanxu-validation-evidence-accepted? result))
(def opentofu-reselected-artifact-test
  (test-suite "opentofu-reselected-artifact-test"
    (yuanxu-test-case "cached AWS parent, explicit rebuild, new native child scope"
      (.def Configuration
        resource: (.o aws_security_group: (.o web: (.o name: "web"))))
      (def ParentContract (.get OpenTofuScope. types configuration))
      (def parent-result (.call ParentContract .admit Configuration #f))
      (assert 'parent-admitted-before-reselection (accepted? parent-result))
      (def ParentAWS (.get OpenTofuScope. modules aws provider))
      (.def (Release @ Configuration)
        resource: =>.+
        (.o null_resource: (.o smoke: (.o triggers: (.o release: "smoke")))))
      (def Demand (.call OpenTofuScope. .build-inputs Release))
      (assert 'final-demand-includes-new-provider
        (equal? (.get Demand providers) '("aws" "null")))
      (assert 'old-collection-rejects-new-provider
        (not (accepted? (.call ParentContract .admit Release #f))))
      (let (output (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_SELECTION" #f))
        (when output
          (call-with-output-file output
            (lambda (port)
              (write-json port (list->hash-table
                (list (cons 'providers (list->vector (.get Demand providers))))))))))
      (let (rebuilt (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_REBUILT" #f))
        (when rebuilt
          (let ()
            (.def (Updated @ OpenTofuScope.)
              config: =>.+ (.o artifact: rebuilt))
            (assert 'child-module-registry-initially-lazy (not (.ref/cached Updated 'modules)))
            (def result
              (use-module Updated as tf
                (.call (.get tf types configuration) .admit Release #f)))
            (assert 'rebuilt-child-admitted (accepted? result))
            (assert 'both-resources-admitted (= (length (.get result classification children)) 2))
            (assert 'child-contract-is-distinct
              (not (eq? ParentContract (.get Updated types configuration))))
            (assert 'awscc-not-in-child-collection (not (.slot? (.get Updated modules) 'awscc)))
            (assert 'null-version-locked (equal? (.get Updated modules null provider version) "3.2.4"))
            (assert 'null-type-read-once
              (= (.call (.get Updated modules null provider artifact)
                         .entry-read-count 'null_resource 'resource) 1))
            (assert 'null-data-unread
              (not (.call (.get Updated modules null provider artifact) .index-loaded? 'data)))
            (assert 'parent-contract-still-cached (eq? ParentContract (.get OpenTofuScope. types configuration)))
            (assert 'parent-provider-still-cached (eq? ParentAWS (.get OpenTofuScope. modules aws provider)))
            (assert 'parent-still-aws-only (not (.slot? (.get OpenTofuScope. modules) 'null)))
            (assert 'parent-admission-unchanged (= (length (.get parent-result classification children)) 1))))))))
