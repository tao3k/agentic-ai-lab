;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .ref)
        :yuanxu/object-family/role-syntax
        :agentic-ai-lab/modules/workflow/qualification/capability-prototypes)


(def capability-prototypes-test
  (test-suite "qualification POO capability prototypes"
    (yuanxu-test-case "multiple parents preserve orthogonal inherited slots"
      (let (left
            (poo-core-role-object
             (slots ((kind 'left)))
             (supers (agentic-ai-lab-versioned-capability 'schema.v1 1)
                     (agentic-ai-lab-revision-bound-capability "revision")
                     (agentic-ai-lab-owner-bound-capability '(owner-a)))))
        (check (.ref left 'schema-id) => 'schema.v1)
        (check (.ref left 'schema-version) => 1)
        (check (.ref left 'source-revision) => "revision")
        (check (.ref left 'owner-artifacts) => '(owner-a))
        (check (agentic-ai-lab-qualification-capabilities-valid?
                left
                (list agentic-ai-lab-versioned-capability-valid?
                      agentic-ai-lab-revision-bound-capability-valid?
                      agentic-ai-lab-owner-bound-capability-valid?))
               => #t)))
    (yuanxu-test-case "orthogonal parent order does not change capability values"
      (let ((left
             (poo-core-role-object
              (slots ((kind 'left)))
              (supers (agentic-ai-lab-versioned-capability 'schema.v1 1)
                      (agentic-ai-lab-revision-bound-capability "revision"))))
            (right
             (poo-core-role-object
              (slots ((kind 'right)))
              (supers (agentic-ai-lab-revision-bound-capability "revision")
                      (agentic-ai-lab-versioned-capability 'schema.v1 1)))))
        (check (.ref left 'schema-id) => (.ref right 'schema-id))
        (check (.ref left 'source-revision) => (.ref right 'source-revision))))
    (yuanxu-test-case "local extension intentionally overrides inherited value"
      (let (extended
            (poo-core-role-object
             (slots ((schema-id 'schema.v2)))
             (supers (agentic-ai-lab-versioned-capability 'schema.v1 1))))
        (check (.ref extended 'schema-id) => 'schema.v2)
        (check (.ref extended 'schema-version) => 1)))
    (yuanxu-test-case "separate compositions remain isolated"
      (let ((first (agentic-ai-lab-owner-bound-capability '(owner-a)))
            (second (agentic-ai-lab-owner-bound-capability '(owner-b))))
        (check (.ref first 'owner-artifacts) => '(owner-a))
        (check (.ref second 'owner-artifacts) => '(owner-b))))
    (yuanxu-test-case "missing required capability slot fails validation"
      (check (agentic-ai-lab-versioned-capability-valid?
              (agentic-ai-lab-versioned-capability #f 1))
             => #f)
      (check (agentic-ai-lab-versioned-capability-valid?
              (agentic-ai-lab-owner-bound-capability '(owner-a)))
             => #f))
    (yuanxu-test-case "duplicate capability and slot ownership conflict fail closed"
      (check
       (agentic-ai-lab-qualification-capability-composition-diagnostics
        '((versioned schema-id schema-version)
          (versioned schema-id schema-version)))
       => '((slot-owner-conflict schema-version)
            (slot-owner-conflict schema-id)
            (duplicate-capability versioned)))
      (check
       (agentic-ai-lab-qualification-capability-composition-diagnostics
        '((left unique-a shared) (right unique-b shared)))
       => '((slot-owner-conflict shared))))))
