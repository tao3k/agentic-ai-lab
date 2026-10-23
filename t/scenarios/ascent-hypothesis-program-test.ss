;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test check check-exception test-case test-suite)
        (only-in :clan/poo/object .o .mix .ref .call)
        (only-in :clan/poo/trie UIntTrieSet)
        (only-in :agentic-ai-lab/modules/workflow/qualification/ascent-table-expression
                 agentic-ai-lab-ascent-table-expression-prototype)
        :agentic-ai-lab/modules/query/semantic/organization-bundle
        :agentic-ai-lab/user-interface/scenarios/crewai/ascent-hypothesis-program)

(export ascent-hypothesis-program-test)

(def (research-organization)
  (agentic-ai-lab-organization-bundle
   1
   (agentic-ai-lab-organization-organization-facet
    (list (agentic-ai-lab-organization-principal 'parent-principal)
          (agentic-ai-lab-organization-principal 'worker-principal)
          (agentic-ai-lab-organization-role 'role/researcher)
          (agentic-ai-lab-organization-role 'role/worker)
          (agentic-ai-lab-organization-agent
           'researcher 'parent-principal 'role/researcher #f
           '(search review) '(public))
          (agentic-ai-lab-organization-agent
           'worker 'worker-principal 'role/worker 'researcher
           '(search) '(public))))
   (agentic-ai-lab-organization-authority-facet
    (list (agentic-ai-lab-organization-capability 'search #t)
          (agentic-ai-lab-organization-capability 'review #t))
    (list (agentic-ai-lab-organization-delegation
           'researcher 'worker 'search)))
   (agentic-ai-lab-organization-context-facet
    (list (agentic-ai-lab-organization-context-projection
           'worker '(public))))
   (agentic-ai-lab-organization-protocol-facet
    (list (agentic-ai-lab-organization-tool-effect
           'search-tool 'search 'external-tool))
    '())
   (agentic-ai-lab-organization-empty-evidence-facet)))

(def (expression-from-pairs pairs)
  (.mix agentic-ai-lab-ascent-table-expression-prototype
        (.o source-pairs: (.call UIntTrieSet .<-list pairs)
            radix: 8)))

(def (agent-count bundle)
  (length
   (filter (lambda (value) (eq? (.ref value 'kind) 'agent))
           (.ref (.ref bundle 'organization) 'entities))))

(def ascent-hypothesis-program-test
  (test-suite "Scheme Ascent candidate revises an Agent society"
   (test-case "source withdrawal falsifies a predicted closure pair"
     (let* ((base (research-organization))
            (cycle (expression-from-pairs '(10 19 28 34 11)))
            (withdrawn (expression-from-pairs '(10 19 28 11)))
            (predictions
             (list (agentic-ai-lab-ascent-prediction 11 #t)
                   (agentic-ai-lab-ascent-prediction 36 #t)))
            (cycle-program
             (agentic-ai-lab-ascent-hypothesis-program
              'research-cycle "source/cycle" cycle predictions base 3))
            (withdrawn-program
             (agentic-ai-lab-ascent-hypothesis-program
              'research-withdrawn "source/withdrawn" withdrawn
              predictions base 3))
            (cycle-demand (agentic-ai-lab-ascent-hypothesis-demand cycle-program))
            (withdrawn-demand
             (agentic-ai-lab-ascent-hypothesis-demand withdrawn-program))
            (cycle-observation
             (agentic-ai-lab-ascent-hypothesis-observe
              cycle-program cycle-demand cycle base))
            (withdrawn-observation
             (agentic-ai-lab-ascent-hypothesis-observe
              withdrawn-program withdrawn-demand withdrawn base)))
       (let-values
        (((cycle-successor cycle-organization)
          (agentic-ai-lab-ascent-hypothesis-revise
           cycle-program cycle-demand cycle-observation base))
         ((withdrawn-successor withdrawn-organization)
          (agentic-ai-lab-ascent-hypothesis-revise
           withdrawn-program withdrawn-demand withdrawn-observation base)))
        (check (.ref cycle-successor 'prediction-verdict) => 'matched)
        (check (eq? cycle-organization base) => #t)
        (check (.ref withdrawn-successor 'prediction-verdict) => 'falsified)
        (check (.ref withdrawn-successor 'failed-pairs) => '(36))
        (check (agent-count withdrawn-organization) => 3)
        (check (agentic-ai-lab-organization-validation-accepted?
                (agentic-ai-lab-organization-bundle-validate
                 withdrawn-organization)) => #t)
        (check (.ref withdrawn-successor 'activation-authority?) => #f)
        (check (.ref withdrawn-successor 'mrr-admitted?) => #f)
        (check (.ref withdrawn-observation 'external-effect-executed?) => #f)
        (check (.ref cycle 'closure-pairs)
               => '(10 11 12 18 19 20 26 27 28 34 35 36))
        (check (.ref withdrawn 'closure-pairs)
               => '(10 11 12 19 20 28))
        (check-exception
         (agentic-ai-lab-ascent-hypothesis-observe
          cycle-program cycle-demand withdrawn base)
         true))))

   (test-case "prediction count is bounded and demand is generation-bound"
     (let* ((base (research-organization))
            (expression (expression-from-pairs '(10 19 28 11)))
            (predictions
             (list (agentic-ai-lab-ascent-prediction 36 #t)
                   (agentic-ai-lab-ascent-prediction 35 #t)))
            (program
             (agentic-ai-lab-ascent-hypothesis-program
              'bounded-research "source/withdrawn" expression
              predictions base 1))
            (demand (agentic-ai-lab-ascent-hypothesis-demand program))
            (observation
             (agentic-ai-lab-ascent-hypothesis-observe
              program demand expression base)))
       (let-values
        (((successor organization)
          (agentic-ai-lab-ascent-hypothesis-revise
           program demand observation base)))
        (check (.ref successor 'failed-pairs) => '(36 35))
        (check (agent-count organization) => 3)
        (check (.ref organization 'epoch) => 2)
        (check-exception
         (agentic-ai-lab-ascent-hypothesis-revise
          successor demand observation organization)
         true)
        (check-exception
         (agentic-ai-lab-ascent-hypothesis-revise
          program demand observation organization)
         true))))

   (test-case "source specialization demands a new snapshot before revision"
     (let* ((base (research-organization))
            (cycle (expression-from-pairs '(10 19 28 34 11)))
            (withdrawn (expression-from-pairs '(10 19 28 11)))
            (program
             (agentic-ai-lab-ascent-hypothesis-program
              'counterfactual "source/cycle" cycle
              (list (agentic-ai-lab-ascent-prediction 36 #t)) base 1))
            (old-demand (agentic-ai-lab-ascent-hypothesis-demand program))
            (specialized
             (agentic-ai-lab-ascent-hypothesis-specialize-source
              program "source/withdrawn" withdrawn base))
            (new-demand (agentic-ai-lab-ascent-hypothesis-demand specialized))
            (old-observation
             (agentic-ai-lab-ascent-hypothesis-observe
              program old-demand cycle base))
            (new-observation
             (agentic-ai-lab-ascent-hypothesis-observe
              specialized new-demand withdrawn base)))
       (check (equal? (.ref old-demand 'identity)
                      (.ref new-demand 'identity)) => #f)
       (check (.ref specialized 'predecessor-identity)
              => (.ref program 'identity))
       (check (.ref specialized 'external-effect-executed?) => #f)
       (check (.ref specialized 'activation-authority?) => #f)
       (check-exception
        (agentic-ai-lab-ascent-hypothesis-revise
         specialized old-demand new-observation base)
        true)
       (check-exception
        (agentic-ai-lab-ascent-hypothesis-revise
         specialized new-demand old-observation base)
        true)
       (check-exception
        (agentic-ai-lab-ascent-hypothesis-revise
         specialized new-demand
         (.mix new-observation (.o failed-pairs: '(63))) base)
        true)
       (check-exception
        (agentic-ai-lab-ascent-hypothesis-specialize-source
         program "source/cycle" cycle base)
        true)
       (check-exception
        (agentic-ai-lab-ascent-hypothesis-specialize-source
         program "source/cycle" withdrawn base)
        true)
       (let-values
        (((successor society)
          (agentic-ai-lab-ascent-hypothesis-revise
           specialized new-demand new-observation base)))
        (check (.ref successor 'prediction-verdict) => 'falsified)
        (check (.ref successor 'failed-pairs) => '(36))
        (check (.ref successor 'cause-observation-identity)
               => (.ref new-observation 'identity))
        (check (agent-count society) => 3)
        (check (.ref successor 'external-effect-executed?) => #f)
        (check (.ref successor 'mrr-admitted?) => #f))))

   (test-case "duplicate pair predictions cannot define a program"
     (let ((base (research-organization))
           (expression (expression-from-pairs '(10 19))))
       (check-exception
        (agentic-ai-lab-ascent-hypothesis-program
         'duplicate "source/duplicate" expression
         (list (agentic-ai-lab-ascent-prediction 11 #t)
               (agentic-ai-lab-ascent-prediction 11 #f))
         base 2)
        true)))))
