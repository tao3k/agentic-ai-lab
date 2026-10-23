;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Reference Delta admission always independently reprojects the target bytes.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list every delete-duplicates/hash)
        "types.ss" "objects.ss" "funs-projection.ss" "funs-scope.ss")
(export agentic-ai-lab-ai-agentic-context-delta-between
        agentic-ai-lab-ai-agentic-context-delta-apply
        agentic-ai-lab-ai-agentic-context-delta-admit
        agentic-ai-lab-ai-agentic-context-delta-admit-incremental)
(def (reject reason-value) (.o accepted?: #f reason: reason-value))
(def (accept content-value) (.o accepted?: #t content: content-value
  stage: 'reconstructed action-authorized?: #f))
(def (unique? ids) (= (length ids) (length (delete-duplicates/hash ids))))
(def (lookup units id) (assoc id units))
(def (agentic-ai-lab-ai-agentic-context-delta-between base target)
  (let* ((old (.ref base 'content)) (new (.ref target 'content))
         (ids (delete-duplicates/hash (append (map car old) (map car new))))
         (changes (filter (lambda (id) (not (equal? (lookup old id) (lookup new id)))) ids)))
    (.o (:: @ AiAgenticContextDelta.)
        base-digest: (.ref base 'semantic-digest) target-digest: (.ref target 'semantic-digest)
        order: (map car new)
        edits: (map (lambda (id)
          (.o (:: @ AiAgenticContextEdit.) identity: id
              expected: (or (lookup old id) #f) replacement: (or (lookup new id) #f))) changes))))
(def (agentic-ai-lab-ai-agentic-context-delta-apply base delta)
  (cond
    ((not (agentic-ai-lab-ai-agentic-context-delta-shape? delta)) (reject 'invalid-delta))
    ((not (equal? (.ref base 'semantic-digest) (.ref delta 'base-digest))) (reject 'wrong-base))
    (else
      (let ((units (.ref base 'content)) (edits (.ref delta 'edits)) (order (.ref delta 'order)))
        (cond
          ((not (and (unique? (map car units)) (unique? (map (lambda (e) (.ref e 'identity)) edits))
                     (unique? order))) (reject 'duplicate-identity))
          ((not (every (lambda (e) (equal? (or (lookup units (.ref e 'identity)) #f)
                                          (.ref e 'expected))) edits)) (reject 'wrong-unit-version))
          (else
            (let* ((changed-ids (map (lambda (e) (.ref e 'identity)) edits))
                   (survivors (filter (lambda (u) (not (member (car u) changed-ids))) units))
                   (replacements (filter values (map (lambda (e) (.ref e 'replacement)) edits)))
                   (result (append survivors replacements)))
              (if (and (= (length result) (length order))
                       (every (lambda (id) (lookup result id)) order))
                (accept (map (lambda (id) (lookup result id)) order))
                (reject 'incomplete-order)))))))))
(def (admit-delta base-source base delta target-source scope restriction profile incremental?)
  ;; Proposal payloads are never returned. Replay both sources and return fresh values.
  (let* ((verified-base (agentic-ai-lab-ai-agentic-context-org-replay base-source base (.ref base 'scope)))
         (admitted-scope (agentic-ai-lab-ai-agentic-context-scope-admit scope))
         (old-scope (.ref verified-base 'scope))
         (same-scope? (every (lambda (k) (equal? (.ref old-scope k) (.ref admitted-scope k)))
           '(bundle organization epoch project worktree actor task destination session turn)))
         (target (if incremental?
           (agentic-ai-lab-ai-agentic-context-org-project-incremental base-source verified-base
             admitted-scope target-source restriction profile)
           (agentic-ai-lab-ai-agentic-context-org-project admitted-scope target-source restriction profile
             (.ref verified-base 'row-budget) (.ref verified-base 'byte-budget))))
         (compatible? (and same-scope?
           (equal? (.ref verified-base 'feature-ids) (.ref target 'feature-ids))
           (equal? (.ref (.ref verified-base 'restriction) 'semantic-digest)
                   (.ref (.ref target 'restriction) 'semantic-digest))))
         (applied (agentic-ai-lab-ai-agentic-context-delta-apply verified-base delta)))
    (cond
      ((not compatible?) (reject 'contract-mismatch))
      ((not (.ref applied 'accepted?)) applied)
      ((not (equal? (.ref delta 'target-digest) (.ref target 'semantic-digest))) (reject 'wrong-target))
      ((not (equal? (.ref applied 'content) (.ref target 'content))) (reject 'target-content-mismatch))
      (else (.o accepted?: #t projection: target coverage: (if incremental? 'local-query-complete-domain 'full-reprojection)
                source-authenticated?: #f action-authorized?: #f durable?: #f)))))

(def (agentic-ai-lab-ai-agentic-context-delta-admit base-source base delta target-source scope restriction profile)
  (admit-delta base-source base delta target-source scope restriction profile #f))
(def (agentic-ai-lab-ai-agentic-context-delta-admit-incremental base-source base delta target-source scope restriction profile)
  (admit-delta base-source base delta target-source scope restriction profile #t))
