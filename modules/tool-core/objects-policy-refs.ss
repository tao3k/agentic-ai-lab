;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: pure policy-grant reference collection and merge operations.

(import (only-in :std/list/list delete-duplicates/hash)
        (only-in :std/list/list filter map)
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy)

(export agentic-ai-lab-tool-policy-grant-tool-refs
        agentic-ai-lab-tool-policy-grants
        agentic-ai-lab-tool-unique-symbols
        agentic-ai-lab-tool-merge-policy-tool-refs
        agentic-ai-lab-tool-policy-tool-refs)

;; : (-> [PooSessionToolGrant] [Symbol])
(def (agentic-ai-lab-tool-policy-grant-tool-refs grants)
  (map agentic-ai-lab-session-tool-grant-tool-ref grants))

;; : (-> PooSessionPolicy [PooSessionToolGrant])
(def (agentic-ai-lab-tool-policy-grants policy)
  (agentic-ai-lab-session-alist-ref
   (agentic-ai-lab-session-policy->alist policy)
   'tool-grants
   '()))

;; : (-> [Symbol] [Symbol] [Symbol])
(def (agentic-ai-lab-tool-unique-symbols values seen)
  (let (seen-table (make-hash-table-eq))
    (for-each (lambda (value) (hash-put! seen-table value #t)) seen)
    (delete-duplicates/hash
     (filter (lambda (value) (not (eq? value '*))) values)
     table: seen-table
     from-end?: #t)))

;; : (-> [Symbol] [Symbol] [Symbol])
(def (agentic-ai-lab-tool-merge-policy-tool-refs agent-tool-refs hook-tool-refs)
  (agentic-ai-lab-tool-unique-symbols
   (append agent-tool-refs hook-tool-refs)
   '()))

;; : (-> PooSessionPolicy [Symbol])
(def (agentic-ai-lab-tool-policy-tool-refs policy)
  (agentic-ai-lab-tool-unique-symbols
   (agentic-ai-lab-tool-policy-grant-tool-refs
    (agentic-ai-lab-tool-policy-grants policy))
   '()))
