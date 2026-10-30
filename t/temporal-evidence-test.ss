;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :clan/poo/object .ref)
        :std/test
        :agentic-ai-lab/modules/temporal-causality/evidence/interface)
(export temporal-evidence-test)

(def (use id evidence claim source claim-digest)
  (agentic-ai-lab-evidence-use id evidence claim source claim-digest))
(def (assessment id use verdict)
  (agentic-ai-lab-evidence-assessment
   id use (string-append "reviewer/" id) "method-1" verdict
   (string-append "sha256:basis/" id)))

(def temporal-evidence-test
  (test-suite "evidence use assessment and downstream reachability"
    (yuanxu-test-case "retrieval does not imply use or assessed support"
      (let* ((primary (agentic-ai-lab-evidence-retrieval
                       "r1" "q1" "e1" "sha256:source-1"))
             (unused (agentic-ai-lab-evidence-retrieval
                      "r2" "q1" "e2" "sha256:source-2"))
             (citation (use "u1" "e1" "claim"
                            "sha256:source-1" "sha256:claim-1"))
             (edge (agentic-ai-lab-evidence-dependency "d1" "claim" "report"))
             (lineage (agentic-ai-lab-evidence-lineage
                       "l1" (list unused primary) (list citation) '()
                       (list edge)))
             (audit (agentic-ai-lab-evidence-use-audit "a1" lineage))
             (frontier (agentic-ai-lab-evidence-impact-frontier
                        "f1" lineage '("e1"))))
        (check (.ref audit 'retrieved-unused-evidence) => '("e2"))
        (check (.ref audit 'unreviewed-use-identities) => '("u1"))
        (check (.ref audit 'status) => 'needs-review)
        (check (.ref frontier 'reachable-claim-identities)
               => '("claim" "report"))
        (check (.ref frontier 'actual-impact-admitted?) => #f)
        (check (.ref lineage 'semantic-digest)
               => (.ref (agentic-ai-lab-evidence-lineage
                         "l1" (list primary unused) (list citation) '()
                         (list edge)) 'semantic-digest))))

    (yuanxu-test-case "assessment binds one exact use and claim version"
      (let* ((retrieval (agentic-ai-lab-evidence-retrieval
                         "r" "q" "e" "sha256:source"))
             (citation (use "u" "e" "c" "sha256:source"
                            "sha256:claim-v1"))
             (checked (assessment "a" citation 'supports))
             (lineage (agentic-ai-lab-evidence-lineage
                       "l" (list retrieval) (list citation)
                       (list checked) '()))
             (audit (agentic-ai-lab-evidence-use-audit "audit" lineage)))
        (check (.ref audit 'supported-use-identities) => '("u"))
        (check (.ref audit 'status) => 'declared-reviewed)
        (check (.ref (agentic-ai-lab-evidence-use-audit
                      "unused" (agentic-ai-lab-evidence-lineage
                                "only-search" (list retrieval) '() '() '()))
                     'status) => 'declared-reviewed)
        (check-exception
         (agentic-ai-lab-evidence-lineage
          "changed" (list retrieval)
          (list (use "u" "e" "c" "sha256:source" "sha256:claim-v2"))
          (list checked) '()) true)
        (check-exception
         (agentic-ai-lab-evidence-lineage
          "changed-source" (list retrieval)
          (list (use "u2" "e" "c" "sha256:other" "sha256:claim-v1"))
          '() '()) true)
        (check-exception
         (agentic-ai-lab-evidence-lineage
          "changed-claim" '()
          (list citation
                (use "u2" "e2" "c" "sha256:source-2"
                     "sha256:claim-v2"))
          '() '()) true)))

    (yuanxu-test-case "conflicting assessments remain disputed"
      (let* ((citation (use "u" "e" "c" "sha256:source"
                            "sha256:claim"))
             (yes (assessment "yes" citation 'supports))
             (no (assessment "no" citation 'refutes))
             (lineage (agentic-ai-lab-evidence-lineage
                       "l" '() (list citation) (list yes no) '()))
             (audit (agentic-ai-lab-evidence-use-audit "a" lineage)))
        (check (.ref audit 'cited-unretrieved-evidence) => '("e"))
        (check (.ref audit 'contested-use-identities) => '("u"))
        (check (.ref audit 'supported-use-identities) => '())
        (check (.ref audit 'status) => 'needs-review)
        (check (.ref lineage 'semantic-digest)
               => (.ref (agentic-ai-lab-evidence-lineage
                         "l" '() (list citation) (list no yes) '())
                        'semantic-digest))))

    (yuanxu-test-case "uncertainty and refutation have separate buckets"
      (let* ((u1 (use "u1" "e1" "c1" "sha256:s1" "sha256:c1"))
             (u2 (use "u2" "e2" "c2" "sha256:s2" "sha256:c2"))
             (lineage (agentic-ai-lab-evidence-lineage
                       "l" '() (list u1 u2)
                       (list (assessment "a1" u1 'uncertain)
                             (assessment "a2" u2 'refutes)) '()))
             (audit (agentic-ai-lab-evidence-use-audit "a" lineage)))
        (check (.ref audit 'uncertain-use-identities) => '("u1"))
        (check (.ref audit 'refuted-use-identities) => '("u2"))))

    (yuanxu-test-case "dependency cycles terminate without causal admission"
      (let* ((citation (use "u" "e" "a"
                            "sha256:source" "sha256:claim"))
             (lineage (agentic-ai-lab-evidence-lineage
                       "l" '() (list citation) '()
                       (list (agentic-ai-lab-evidence-dependency "d1" "a" "b")
                             (agentic-ai-lab-evidence-dependency "d2" "b" "a"))))
             (frontier (agentic-ai-lab-evidence-impact-frontier
                        "f" lineage '("e"))))
        (check (.ref frontier 'reachable-claim-identities) => '("a" "b"))
        (check-exception
         (agentic-ai-lab-evidence-impact-frontier "bad" lineage '("missing"))
         true)))))
