;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Parser-owned events only; no text/regex parser and no source-block execution.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/list/list find delete-duplicates/hash)
        (only-in :tao3k/agentic-ai-lab/modules/query/semantic/orgize-source-interface
                 org-source-headline-elements
                 org-source-headline-parser-identity)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-scope
                 agentic-ai-lab-ai-agentic-context-digest)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-org-properties
                 agentic-ai-lab-ai-agentic-context-org-properties
                 agentic-ai-lab-ai-agentic-context-org-property-key?)
        "schemas.ss")
(export context-org-source
        (import: "schemas.ss"))

(def (text? v) (and (string? v) (< 0 (string-length v) 257)))

(def (contract-properties source)
  (let (props (agentic-ai-lab-ai-agentic-context-org-properties source))
    (unless (andmap (cut .ref <> 'value) props)
      (error "Empty Org Contract property"))
    props))

(def (property-slot p)
  (list (.ref p 'container-kind) (.ref p 'container-start) (string-upcase (.ref p 'key))))

;;; Consume the shared property projection, including structural ownership of drawers.
;;; ID-looking text inside a source block is not a document/headline property.
;;; IDs are local anchors; the registered source identity qualifies them.
(def (context-org-source identity generation source (active? #t) (catalog DefaultOrgContractCatalog))
  (unless (and (text? identity)
               (exact-integer? generation) (<= 1 generation 65534)
               (string? source) (<= (u8vector-length (string->utf8 source)) 1048576)
               (boolean? active?))
    (error "Invalid Org source cut"))
  (let* ((source (string-copy source))
         (identity (string-copy identity))
         (projection (org-source-headline-elements source))
         (source-digest (.ref projection 'source-sha256))
         (props (contract-properties source)))
    (unless (.ref projection 'complete?) (error "Incomplete Org source"))
    (let* ((at-root (lambda (key)
                      (let (p (find (lambda (p)
                                      (and (eq? (.ref p 'container-kind) 'OrgFile)
                                           (agentic-ai-lab-ai-agentic-context-org-property-key? p key)))
                                    props))
                        (and p (.ref p 'value)))))
           (contract-identity (at-root "CONTRACT_ID"))
           (contract-revision (at-root "CONTRACT_REVISION"))
           (session-identity (at-root "SESSION_ID"))
           (id-props (filter (cut agentic-ai-lab-ai-agentic-context-org-property-key? <> "ID") props))
           (ids (map (cut .ref <> 'value) id-props)))
      (unless (and (text? (at-root "ID")) (text? contract-identity) (text? contract-revision)
                   (<= 1 (length ids) 32) (andmap text? ids)
                   (= (length ids) (length (delete-duplicates/hash ids)))
                   (= (length props) (length (delete-duplicates/hash (map property-slot props)))))
        (error "Org Contract requires unique local IDs and root contract revision"))
      (admit-org-contract-properties! contract-identity at-root props catalog)
      (let ((semantic-digest
             (agentic-ai-lab-ai-agentic-context-digest
              (list 'org-contract-cut.v1 identity generation source-digest
                    contract-identity contract-revision active?)))
            (nodes
             (map (lambda (p)
                    (let ((label 'OrgElement)
                          (elem-id (agentic-ai-lab-ai-agentic-context-digest
                                    (list 'org-element.v1 identity (.ref p 'value))))
                          (propertyId (string-copy (.ref p 'value)))
                          (sourceId identity)
                          (sourceRevision generation)
                          (sourceDigest source-digest)
                          (contractIdentity contract-identity)
                          (contractRevision contract-revision)
                          (elementKind (symbol->string (.ref p 'container-kind)))
                          (byteStart (.ref p 'container-start))
                          (parserIdentity org-source-headline-parser-identity))
                      (let ((identity elem-id))
                        (.o label identity propertyId sourceId sourceRevision sourceDigest
                            contractIdentity contractRevision elementKind byteStart parserIdentity))))
                  id-props))
            (kind 'context.org-source.v1)
            (parser-identity org-source-headline-parser-identity))
        (.o kind identity generation source source-digest
            contract-identity contract-revision session-identity
            parser-identity active? nodes semantic-digest)))))
