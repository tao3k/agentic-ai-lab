;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; A development consumer. No ASCENT rules or graph algorithm live here.
(import (only-in :clan/poo/object .o .ref .get)
        (only-in :std/list/list find delete-duplicates/hash)
        (only-in "./init.ss" tao3k/agentic-ai-lab/dev/d2.init.exports))
(export main)
(def Scope (.get tao3k/agentic-ai-lab/dev/d2.init.exports modules d2))
(def Profile (.get Scope profiles ContextEvolution))
(def ExperienceWindow. (.get Profile Window))
(include "context-evolution-example.ss")

;; Only translate derived rows into the module's POO Diagram values. Neither
;; support/conflict decisions nor graph selection are implemented in this driver.
(def (window-diagram input result window-value)
  (def window-id (.ref window-value 'identity))
  (def version-id (.ref window-value 'revision))
  (def (rows relation) ((.get Profile rows) result relation))
  (def links (filter (lambda (row) (and (eq? (car row) window-id) (eq? (cadr row) version-id)))
                    (rows 'VisualEdge)))
  (def ids (delete-duplicates/hash (apply append (map (lambda (row) (list (caddr row) (cadddr row))) links))))
  (def (values-of key) (.ref input key))
  (def node-values (apply append (map values-of '(windows observations hypotheses proposals))))
  (def Node. (.get Scope prototypes Node))
  (def Relation. (.get Scope prototypes Relation))
  (def Diagram. (.get Scope prototypes Diagram))
  (.o (:: @ Diagram.) identity: window-id revision: version-id
      nodes:
      (map (lambda (name)
        (def original (or (find (lambda (value) (eq? (.ref value 'identity) name)) node-values)
                         (error "derived node has no POO source" name)))
        (def candidate? (member (list window-id version-id name) (rows 'KnowledgeCandidate)))
        (def conflict? (member (list window-id version-id name) (rows 'Conflicted)))
        (def kind-value
          (cond (conflict? 'conflicted) (candidate? 'candidate)
                ((memq original (.ref input 'windows)) 'window)
                ((memq original (.ref input 'observations)) 'observation)
                ((memq original (.ref input 'proposals)) 'proposal)
                (else 'hypothesis)))
        (def label-value (string-append (.ref original 'label)
                          (cond (conflict? "\nConflicting evidence")
                                (candidate? "\nReview candidate only") (else ""))))
        (.o (:: @ Node.) identity: name kind: kind-value label: label-value)) ids)
      relations:
      (map (lambda (row)
        (let ((source-id (caddr row)) (target-id (cadddr row)) (role-value (list-ref row 4)))
          (.o (:: @ Relation.) from: source-id to: target-id role: role-value))) links)))

(def (main (output "dev/d2/output"))
  ;; Prepare the init-owned source closure without running a build/compiler.
  (.get tao3k/agentic-ai-lab/dev/d2.init.exports std-make-spec)
  (def input (context-evolution-example))
  (def result ((.get Profile evaluate) input))
  (def snapshots
    (map (lambda (window-value)
      (let* ((diagram (window-diagram input result window-value))
             (view ((.get Scope infer) diagram)))
        (cons (.ref window-value 'identity) ((.get Scope source) view)))) (.ref input 'windows)))
  ;; Use the init owner's current-source boundary before publishing artifacts.
  ((.get tao3k/agentic-ai-lab/dev/d2.init.exports admit-current))
  (create-directory* output)
  (for-each (lambda (snapshot)
    (def destination (path-expand (string-append "ascent-" (symbol->string (car snapshot)) ".d2") output))
    (call-with-output-file (list path: destination truncate: #t)
      (lambda (port) (display (cdr snapshot) port)))
    (displayln "D2 " destination)) snapshots))
