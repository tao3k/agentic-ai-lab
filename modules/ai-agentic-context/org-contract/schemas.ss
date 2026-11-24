;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Extensible POO Org Contract schema prototypes and catalog dispatch.
(import (only-in :clan/poo/object .o .ref .slot? .alist/sort object?)
        (only-in :clan/poo/mop .defgeneric)
        (only-in :std/list/list find)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-org-properties
                 agentic-ai-lab-ai-agentic-context-org-property-key?))
(export org-contract-schema-admit!
        OrgContractSchema.
        ConsumerOrgContractSchema.
        SessionSeedOrgContractSchema.
        TopologyOrgContractSchema.
        GovernedWorkOrgContractSchema.
        GovernedTaskOrgContractSchema.
        CrossRepoTopologyOrgContractSchema.
        DefaultOrgContractCatalog
        resolve-org-contract-schema
        admit-org-contract-properties!)

(.defgeneric (org-contract-schema-admit! schema at-root section-drawers)
  slot: .admit-properties)

(def (text? v) (and (string? v) (< 0 (string-length v) 257)))

(def (sha256-session-id? text)
  (and (text? text)
       (= (string-length text) 71)
       (string=? (substring text 0 7) "sha256:")
       (andmap (lambda (ch) (or (char<=? #\0 ch #\9) (char<=? #\a ch #\f)))
               (string->list (substring text 7 71)))))

(def (drawer-value props key)
  (let (p (find (cut agentic-ai-lab-ai-agentic-context-org-property-key? <> key) props))
    (and p (.ref p 'value))))

(def (section-drawers props)
  (let loop ((rest props) (groups '()))
    (if (null? rest)
      (map (lambda (g) (reverse (cdr g))) (reverse groups))
      (let (p (car rest))
        (if (not (eq? (.ref p 'container-kind) 'OrgSection))
          (loop (cdr rest) groups)
          (let (k (list (.ref p 'container-start) (.ref p 'container-end)))
            (if (assoc k groups)
              (loop (cdr rest)
                    (map (lambda (g) (if (equal? (car g) k) (cons k (cons p (cdr g))) g)) groups))
              (loop (cdr rest) (cons (list k p) groups)))))))))

(def (admit-root-groups! schema-identity required-groups at-root)
  (for-each
   (lambda (keys)
     (unless (find (lambda (k) (text? (at-root k))) keys)
       (error "Org Contract missing required root property" schema-identity keys)))
   required-groups))

(def OrgContractSchema.
  (let ((kind 'context.org-contract-schema.v1)
        (family "context.org")
        (revision "1")
        (required-root-any '()))
    (.o kind family revision
        identity: (string-append family ".v" revision)
        required-root-any
        .admit-properties:
        (lambda (at-root _sections)
          (admit-root-groups! identity required-root-any at-root)
          #t))))

(def ConsumerOrgContractSchema.
  (let ((family "context.consumer"))
    (.o (:: @ OrgContractSchema. identity required-root-any)
        family
        .admit-properties:
        (lambda (at-root _sections)
          (admit-root-groups! identity required-root-any at-root)
          (unless (sha256-session-id? (at-root "SESSION_ID"))
            (error "Consumer Org Contract requires its owner-derived Session ID"))
          #t))))

(def SessionSeedOrgContractSchema.
  (let ((family "context.session.seed")
        (required-root-any '(("PROJECT_ID" "GITOPS_PROJECT"))))
    (.o (:: @ OrgContractSchema. identity)
        family required-root-any)))

(def TopologyOrgContractSchema.
  (let ((family "context.gitops.topology")
        (required-root-any '(("PROJECT_ID" "GITOPS_PROJECT"))))
    (.o (:: @ OrgContractSchema. identity)
        family required-root-any
        .admit-properties:
        (lambda (at-root sections)
          (admit-root-groups! identity required-root-any at-root)
          (for-each
           (lambda (sec)
             (when (drawer-value sec "ARCH_COMPONENT")
               (unless (and (text? (drawer-value sec "ID"))
                            (text? (drawer-value sec "ENTRY_SOURCE")))
                 (error "Topology component headline requires local ID and ENTRY_SOURCE"))))
           sections)
          #t))))

(def GovernedWorkOrgContractSchema.
  (let ((family "context.governance.work")
        (required-root-any '(("PROJECT_ID" "GITOPS_PROJECT"))))
    (.o (:: @ OrgContractSchema. identity)
        family required-root-any
        .admit-properties:
        (lambda (at-root sections)
          (admit-root-groups! identity required-root-any at-root)
          (for-each
           (lambda (sec)
             (when (or (drawer-value sec "AGENT_ID")
                       (drawer-value sec "REVIEWER_AGENT_ID"))
               (unless (and (text? (drawer-value sec "ID"))
                            (text? (drawer-value sec "AGENT_ID"))
                            (text? (drawer-value sec "TASK_ID")))
                 (error "Governed Org section requires local ID, AGENT_ID, and TASK_ID"))))
           sections)
          #t))))

(def GovernedTaskOrgContractSchema.
  (let ((family "context.governance.task"))
    (.o (:: @ GovernedWorkOrgContractSchema.)
        family)))

(def CrossRepoTopologyOrgContractSchema.
  (let ((family "context.gitops.cross-repo")
        (required-root-any '(("PROJECT_ID" "GITOPS_PROJECT")
                             ("RELATES_PROJECT" "RELATED_PROJECT"))))
    (.o (:: @ TopologyOrgContractSchema.)
        family required-root-any)))

(def DefaultOrgContractCatalog
  (let ((consumer ConsumerOrgContractSchema.)
        (session-seed SessionSeedOrgContractSchema.)
        (topology TopologyOrgContractSchema.)
        (governed-work GovernedWorkOrgContractSchema.)
        (governed-task GovernedTaskOrgContractSchema.)
        (cross-repo CrossRepoTopologyOrgContractSchema.))
    (.o consumer session-seed topology governed-work governed-task cross-repo)))

(def (org-contract-schema? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'context.org-contract-schema.v1)
       (text? (.ref v 'identity))))

(def (resolve-org-contract-schema contract-identity (catalog DefaultOrgContractCatalog))
  (unless (and (text? contract-identity) (object? catalog))
    (error "Invalid Org Contract catalog lookup"))
  (let (entry (find (lambda (kv)
                      (let (schema (cdr kv))
                        (and (org-contract-schema? schema)
                             (equal? (.ref schema 'identity) contract-identity))))
                    (.alist/sort catalog)))
    (if entry (cdr entry) OrgContractSchema.)))

(def (admit-org-contract-properties! contract-identity at-root props (catalog DefaultOrgContractCatalog))
  (org-contract-schema-admit!
   (resolve-org-contract-schema contract-identity catalog)
   at-root
   (section-drawers props)))
