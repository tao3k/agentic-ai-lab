;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Collection policy x candidate-binding transport. The binding prevents stale
;;; reuse; it is not provider authentication. package management owns artifact provenance.
;;; No provider execution, persistent certificate, or Loader is implied.
(import :clan/poo/object
        ;; Only declaration syntax is required. Reflection, class evolution and
        ;; load-form publication are not collection-evidence dependencies.
        (only-in :yuanxu/poo-clos/generic-syntax .defgeneric .defmethod)
        (only-in :clan/poo/mop element?)
        "./types.ss" "./aws-hash.ss"
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :yuanxu/modules/json-schema/functional
                 yuanxu-contract-json-object? yuanxu-contract-key->string
                 yuanxu-contract-object-ref yuanxu-contract-key->symbol)
        (only-in :yuanxu/modules/json-schema/json-schema-validation-core
                 yuanxu-json-schema-candidate-rows))
(export agentic-ai-lab-opentofu-string-set-authority
        agentic-ai-lab-opentofu-value-digest
        agentic-ai-lab-opentofu-hash-string-authority)

;; Canonical, tagged wire snapshots; order-independent object keys, ordered
;; arrays, no live receiver/pointer retained. Schema and candidate are separate.
(def (freeze value)
  (cond
   ((or (object? value) (hash-table? value)
        (and (pair? value) (yuanxu-contract-json-object? value)))
    (cons 'object
      (list-sort (lambda (a b) (string<? (car a) (car b)))
        (map (lambda (row)
                   (cons (yuanxu-contract-key->string (car row)) (freeze (cdr row))))
                 (yuanxu-json-schema-candidate-rows value)))))
   ((vector? value) (cons 'array (map freeze (vector->list value))))
   ((list? value) (cons 'array (map freeze value)))
   (else value)))

(def (agentic-ai-lab-opentofu-value-digest value)
  (hex-encode
    (sha256 (string->utf8
      (call-with-output-string (lambda (port) (write (freeze value) port)))))))

(.def LiteralStringSetPolicy.
  identity: 'literal-string-equality-v1
  .field: (lambda (path) path)
  .normalize: (lambda (values) values)
  .valid-input?: (lambda (_values) #t))
(.def AwsHashStringPolicy.
  identity: 'sdk-hash-string-crc32-v2.36.1
  .field: (lambda (path) (filter (lambda (key) (not (integer? key))) path))
  .normalize: agentic-ai-lab-opentofu-aws-string-set
  .valid-input?:
  (lambda (values)
    (not (agentic-ai-lab-opentofu-aws-string-collision? values))))
(.def CollectionBinding.)
(.def MissingCollectionBinding.)

;; Independent axes: upstream collection policy and evidence transport kind.
;; Unsupported/custom provider policies and foreign evidence fail closed.
(.defgeneric collection-binding-reason (policy evidence request now lookup))
(.defmethod (collection-binding-reason policy evidence request now lookup)
  'provider-set-evidence-forged)
(.defmethod (collection-binding-reason policy
               (evidence (prototype MissingCollectionBinding.)) request now lookup)
  'provider-set-identity-unresolved)
(def (registered-receipt-reason evidence request now lookup)
  (let (record (lookup evidence))
    (cond
     ((or (not record) (not (element? CollectionReceiptType evidence)))
      'provider-set-evidence-forged)
     ((>= now (.get record expires)) 'provider-set-evidence-expired)
     ((not (equal? (.get record binding) (.get request binding)))
      'provider-set-evidence-source-mismatch)
     ((not (equal? (.get record path) (.get request path)))
      'provider-set-evidence-path-mismatch)
     ((not (equal? (.get record candidate) (.get request candidate)))
      'provider-set-evidence-candidate-mismatch)
     ((not (equal? (.get record values) (.get request values)))
      'provider-set-evidence-candidate-mismatch)
     (else #f))))

;; Two independent dispatch axes, no hand-written specializer/lambda lists.
(defrules local-policy-method ()
  ((_ target)
   (.defmethod (collection-binding-reason
                 (policy (prototype target))
                 (evidence (prototype CollectionBinding.)) request now lookup)
     (registered-receipt-reason evidence request now lookup))))
(local-policy-method LiteralStringSetPolicy.)
(local-policy-method AwsHashStringPolicy.)

(def (agentic-ai-lab-opentofu-string-set-authority provider version block paths
       (clock (lambda () (time->seconds (current-time)))))
  (set-authority provider version block paths clock
                 (.o (:: @ LiteralStringSetPolicy.))
                 (lambda () #t)))

;; The source owner supplies the verification closure; downstream never selects
;; this policy by writing a symbol in a configuration value.
(def (agentic-ai-lab-opentofu-hash-string-authority provider version block paths source-check)
  (set-authority provider version block paths
                 (lambda () (time->seconds (current-time)))
                 (.o (:: @ AwsHashStringPolicy.))
                 source-check))

(def (authorized-field? policy paths field)
  (member (.call policy .field field) paths))

(def (receipt-for-path ledger receipts path missing)
  (or (find (lambda (item)
              (let (record (hash-ref ledger item #f))
                (and record (equal? (.get record path) path)))) receipts)
      (and (pair? receipts) (car receipts)) missing))

(def (set-authority provider version block paths clock policy source-check)
  (unless (and (string? provider) (> (string-length provider) 0)
               (string? version) (> (string-length version) 0)
               (not (member version '("unknown" "latest")))
               (list? paths) (every list? paths) (procedure? clock))
    (error "evidence authority requires an explicit provider/version and paths"))
  (let* ((provider (string-copy provider))
         (version (string-copy version))
         (schema (agentic-ai-lab-opentofu-value-digest block))
         (binding (agentic-ai-lab-opentofu-value-digest
                    (list provider version schema (.get policy identity) paths)))
         ;; Private identity ledger. Copying a prototype or its visible audit
         ;; fields cannot enroll a receipt here. Weak keys follow Core's native
         ;; verification boundary: discarded plan bindings are not retained by
         ;; a long-lived authority. The authority is a trust root.
         (ledger (make-hash-table-eq weak-keys: #t))
         (missing (.o (:: @ MissingCollectionBinding.)))
         (allowed-paths (map (lambda (path)
                              (map (lambda (key)
                                     (if (integer? key) key (yuanxu-contract-key->symbol key))) path)) paths)))
    (def (request candidate path values)
      (.cc (.o) 'binding binding 'path (map (lambda (key) key) path)
           'candidate (agentic-ai-lab-opentofu-value-digest candidate)
           'values (agentic-ai-lab-opentofu-value-digest values)))
    (def (issue candidate path values literal? lifetime (field path))
      (and (source-check) literal? (authorized-field? policy allowed-paths field)
           (.call policy .valid-input? values)
           (real? lifetime) (> lifetime 0) (<= lifetime 3600)
           (let* ((req (request candidate path values))
                  (expires (+ (clock) lifetime))
                  (receipt (.+ CollectionBinding. (.cc (.o)
                             'provider (string-copy provider)
                             'version (string-copy version) 'schema (string-copy schema)
                             'field (map (lambda (key) key) path)
                             'candidate-digest (string-copy (.get req candidate))
                             'expires expires))))
             (hash-put! ledger receipt (.cc req 'expires expires))
             receipt)))
    (def (verify candidate path values literal? context (field path))
      (let* ((receipts (yuanxu-contract-object-ref
                        (yuanxu-json-schema-candidate-rows context) 'receipts '()))
             (req (request candidate path values)))
        (cond
         ((not (source-check)) 'provider-source-mismatch)
         ((and literal? (not (.call policy .valid-input? values)))
          'provider-set-hash-collision)
         ((or (not literal?) (not (authorized-field? policy allowed-paths field)))
          'provider-set-identity-unresolved)
         ((not (list? receipts)) 'provider-set-evidence-forged)
         (else
          (let (receipt (receipt-for-path ledger receipts path missing))
            (collection-binding-reason policy receipt req (clock)
              (lambda (item) (hash-ref ledger item #f))))))))
    (.cc (.o) 'provider (string-copy provider) 'version (string-copy version)
         'schema (string-copy schema)
         '.matches? (lambda (candidate-block)
                      (equal? schema (agentic-ai-lab-opentofu-value-digest candidate-block)))
         '.normalize-values (.get policy .normalize)
         '.issue issue '.verify verify)))
