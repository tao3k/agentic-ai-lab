;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :std/encoding/json write-json)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/modules/services/opentofu/objects OpenTofuScope. agentic-ai-lab-opentofu-provider-from-directory agentic-ai-lab-opentofu-block-contract) (only-in :yuanxu/modules/json-schema/json-schema-source yuanxu-json-schema-read-file)
        (only-in :yuanxu/modules/json-schema/json-schema-diagnostics yuanxu-json-schema-validation-diagnostic-metadata)
        :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-indexed-inputs-test)

(def (assert label value)
  (unless value (error "assertion failed" label))
  (displayln "ASSERT-OK " label) (force-output))
(def (accepted? result) (yuanxu-validation-evidence-accepted? result))
(def (rejects? message thunk)
  (with-catch
    (lambda (exception)
      (pregexp-match message
        (call-with-output-string (cut display-exception exception <>))))
    (lambda () (thunk) #f)))
(def (digest-file path)
  (hex-encode (sha256 (call-with-input-file path read-all-as-u8vector))))
(def (write-json-file path rows)
  (call-with-output-file path (cut write-json <> (list->hash-table rows))))
(def (replace-row rows key value)
  (cons (cons key value) (filter (lambda (row) (not (eq? (car row) key))) rows)))
(def (ref rows key) (cdr (assoc key rows)))
(def (diagnostic-paths result)
  (map (lambda (diagnostic)
         (ref (yuanxu-json-schema-validation-diagnostic-metadata diagnostic) 'path))
       (.get result diagnostics)))

(def (verify-input directory name candidate unselected data-name data-candidate version)
  (def Scope (agentic-ai-lab-opentofu-provider-from-directory directory))
  (def Artifact (.get Scope artifact))
  (assert 'manifest-only-ready (eq? (.get Scope status) 'ready))
  (assert 'no-kind-index-loaded-on-open
    (every (lambda (kind) (not (.call Artifact .index-loaded? kind))) '(provider resource data)))
  (def Contract (.call Scope .find-contract name 'resource))
  (assert 'real-resource-admitted (accepted? (.call Contract .admit candidate #f)))
  (assert 'only-resource-index-loaded
    (and (.call Artifact .index-loaded? 'resource)
         (not (.call Artifact .index-loaded? 'provider))
         (not (.call Artifact .index-loaded? 'data))))
  (assert 'one-selected-input-read (= (.call Artifact .entry-read-count name 'resource) 1))
  (assert 'unselected-input-never-read (= (.call Artifact .entry-read-count unselected 'resource) 0))
  (assert 'version-preserved (equal? (.get Contract version) version))
  (assert 'input-digest-binds-actual-bytes
    (equal? (.get Contract input-digest)
            (digest-file (string-append directory "/inputs/resource/" (symbol->string name) ".json"))))
  (assert 'source-is-original (eq? (.get Contract source) (.get Scope source)))
  (assert 'memoized-contract (eq? Contract (.call Scope .find-contract name 'resource)))
  (assert 'memoized-contract-does-not-reread (= (.call Artifact .entry-read-count name 'resource) 1))
  (assert 'catalog-not-constructed (not (.ref/cached Scope 'types)))
  (def Data (.call Scope .find-contract data-name 'data))
  (assert 'real-data-admitted (accepted? (.call Data .admit data-candidate #f)))
  (assert 'one-data-input-read (= (.call Artifact .entry-read-count data-name 'data) 1))
  (assert 'resource-data-separated (not (eq? (.get Contract identity) (.get Data identity))))
  (assert 'provider-index-still-unread (not (.call Artifact .index-loaded? 'provider)))
  ;; Matched baseline only: deliberately parse the old WHOLE export here.
  ;; This test-side A/B control is not an input path of the runtime module.
  (def whole (yuanxu-json-schema-read-file (string-append directory "/schema.json")))
  (def original (ref (ref (ref whole 'provider_schemas)
                        (string->symbol (.get Scope provider))) 'resource_schemas))
  (def Baseline (agentic-ai-lab-opentofu-block-contract 'whole-export-control
                   (ref (ref original name) 'block)))
  (assert 'whole-vs-indexed-contract-shape-equal (equal? (.get Baseline schema) (.get Contract schema)))
  (assert 'whole-vs-indexed-valid-admission-equal
    (eq? (accepted? (.call Baseline .admit candidate #f))
         (accepted? (.call Contract .admit candidate #f))))
  (def invalid (.cc candidate 'not_a_field 1))
  (def baseline-failure (.call Baseline .admit invalid #f))
  (def indexed-failure (.call Contract .admit invalid #f))
  (assert 'whole-vs-indexed-invalid-paths-equal
    (and (not (accepted? baseline-failure)) (not (accepted? indexed-failure))
         (equal? (diagnostic-paths baseline-failure) (diagnostic-paths indexed-failure))))
  ;; A shadow of REAL Nix bytes contains only the requested kind/index/input.
  ;; It has no schema.json and no unselected type files, not merely counters.
  (call-with-temporary-directory "opentofu-indexed"
    (lambda (tmp)
      (def (path relative) (string-append tmp "/" relative))
      (def relative (string-append "inputs/resource/" (symbol->string name) ".json"))
      (create-directory (path "indexes"))
      (create-directory (path "inputs"))
      (create-directory (path "inputs/resource"))
      (copy-file (string-append directory "/manifest.json") (path "manifest.json"))
      (copy-file (string-append directory "/indexes/resource.json") (path "indexes/resource.json"))
      (copy-file (string-append directory "/" relative) (path relative))
      (def (selected)
        (.call (agentic-ai-lab-opentofu-provider-from-directory tmp) .contract name))
      (assert 'real-admission-without-whole-export
        (and (not (file-exists? (path "schema.json")))
             (accepted? (.call (selected) .admit candidate #f))))
      (call-with-output-file (path "schema.json") (cut display "not valid JSON" <>))
      (assert 'poisoned-whole-export-never-read (accepted? (.call (selected) .admit candidate #f)))
      (assert 'missing-unselected-input-not-read
        (not (file-exists? (path (string-append "inputs/resource/" (symbol->string unselected) ".json")))))
      (delete-file (path relative))
      (assert 'missing-selected-input-build-required
        (rejects? "build-required" selected))
      (call-with-output-file (path relative) (cut display "{}" <>))
      (assert 'changed-selected-input-rejected
        (rejects? "provider-artifact-input-digest-mismatch" selected))
      (delete-file (path relative))
      (copy-file (string-append directory "/" relative) (path relative))
      (delete-file (path "indexes/resource.json"))
      (assert 'missing-selected-index-build-required (rejects? "build-required" selected))
      (call-with-output-file (path "indexes/resource.json") (cut display "{}" <>))
      (assert 'changed-index-rejected
        (rejects? "provider-artifact-input-digest-mismatch" selected))
      ;; Matching a modified index digest is insufficient: source bindings
      ;; must also match the manifest. This deliberately modifies real bytes.
      (def manifest (yuanxu-json-schema-read-file (path "manifest.json")))
      (def index (yuanxu-json-schema-read-file (string-append directory "/indexes/resource.json")))
      (for-each
        (lambda (key value)
          (delete-file (path "indexes/resource.json"))
          (write-json-file (path "indexes/resource.json")
            (map (lambda (row)
                   (if (eq? (car row) 'entries)
                     (cons 'entries (list->hash-table (cdr row))) row))
                 (replace-row index key value)))
          (delete-file (path "manifest.json"))
          (write-json-file (path "manifest.json")
            (replace-row manifest 'indexes
              (list->hash-table
                (replace-row (cdr (assoc 'indexes manifest)) 'resource
                             (digest-file (path "indexes/resource.json"))))))
          (assert 'modified-index-binding-rejected
            (rejects? "provider-type-index-binding-mismatch" selected)))
        '(provider version schema-sha256 kind)
        (list "other/provider" "0.0.0" (make-string 64 #\0) "data"))
      (assert 'unsafe-type-path-rejected
        (rejects? "invalid-provider-type-name"
          (lambda () (.call Scope .find-contract 'escape/../../x 'resource)))))))

(def opentofu-indexed-inputs-test
  (test-suite "opentofu-indexed-inputs-test"
    (yuanxu-test-case "real AWS indexed input and integrity"
      (verify-input (.get OpenTofuScope. modules aws config provider-artifact)
        'aws_security_group (.o name: "web") 'aws_iam_group
        'aws_region (.o name: "us-east-1") "5.100.0"))
    (yuanxu-test-case "real awscc indexed input and same-name data"
      (verify-input (.get OpenTofuScope. modules awscc config provider-artifact)
        'awscc_ec2_security_group (.o group_description: "web") 'awscc_s3_bucket
        'awscc_ec2_security_group (.o id: "sg-1234") "1.77.0"))
    (yuanxu-test-case "real Null indexed input"
      ;; Null's single resource is selected. The absent name is an IO-negative
      ;; fixture, not a claim of a second real exported resource.
      (verify-input (.get OpenTofuScope. modules null config provider-artifact)
        'null_resource (.o triggers: (.o release: "smoke")) 'not_exported
        'null_data_source (.o inputs: (.o release: "smoke")) "3.2.4"))))
