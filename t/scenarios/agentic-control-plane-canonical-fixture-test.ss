;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        (only-in :agentic-ai-lab/modules/query/semantic/organization-bundle
                 agentic-ai-lab-organization-bundle-normalize
                 agentic-ai-lab-organization-digest)
        :agentic-ai-lab/modules/workflow/qualification/agentic-control-plane-fixture)


(def canonical-fixture
  (agentic-ai-lab-agentic-control-plane-canonical-fixture))

;; f30b858b changed the two hashed schema tags. Keep the preceding golden
;; identity as a control: every other canonical field must remain identical.
(def (pre-rename-schema-tags datum)
  (cond
   ((pair? datum)
    (cons (pre-rename-schema-tags (car datum))
          (pre-rename-schema-tags (cdr datum))))
   ((eq? datum 'agentic-ai-lab.organization-bundle.draft.3)
    'poo-flow.organization-bundle.draft.3)
   ((eq? datum 'agentic-ai-lab.organization-facet.draft.3)
    'poo-flow.organization-facet.draft.3)
   (else datum)))

(export agentic-control-plane-canonical-fixture-test)

(def agentic-control-plane-canonical-fixture-test
  (test-suite "AC-10 S3 canonical vertical fixture"
    (yuanxu-test-case "one fixture joins every accepted owner identity"
      (let (left canonical-fixture)
        (check (.ref left 'status) => 'qualified)
        (check (map car (.ref left 'identities))
               => '(bundle policy entities decision token effect semantic-root
                           execution-root proof-schema proof-vector))
        (check (cdr (assq 'bundle (.ref left 'identities)))
               => "2cde56396a49851dd2c66e52d0aa6455ce0760f6a4b0aba0fc7573ca9fea800f")
        (check (agentic-ai-lab-organization-digest
                (pre-rename-schema-tags
                 (agentic-ai-lab-organization-bundle-normalize (.ref left 'bundle))))
               => "db1b99c9640ce9d5664ad70efb79280a918093a2053da2b13d3b3717fc87ed5b")
        (check (u8vector-length (.ref left 'proof-vector)) => 424)
        (check (cdr (assq 'proof-vector (.ref left 'identities)))
               => "9febbd6923bedf231cc9b076382bad95fdf0cef82d841fb4ba764e3e9d3e378a")
        (check (.ref left 'required-consumers)
               => '(runtime-c-installed python-cffi-wheel lean-ffi-smoke))))
    (yuanxu-test-case "runtime event preserves batch authorization identity"
      (let (fields (.ref canonical-fixture 'runtime-native-fields))
        (check (cdr (assq 'layout-version fields)) => 1)
        (check (cdr (assq 'header-bytes fields)) => 96)
        (check (cdr (assq 'authorization-identity fields)) => '(3 1))
        (check (cdr (assq 'required-evidence-bits fields)) => 255)))
    (yuanxu-test-case "negative family rejects every required mutation"
      (let (negative
            (agentic-ai-lab-agentic-control-plane-negative-fixtures
             canonical-fixture))
        (check (map (lambda (value) (.ref value 'mutation)) negative)
               => '(deny replay revocation binding-substitution stale-proof))
        (check (map (lambda (value) (.ref value 'code)) negative)
               => '(cedar-deny token-reuse stale-revocation-epoch
                              binding-substitution proof-vector-mismatch))
        (check (andmap (lambda (value) (not (.ref value 'accepted?))) negative)
               => #t)))))
