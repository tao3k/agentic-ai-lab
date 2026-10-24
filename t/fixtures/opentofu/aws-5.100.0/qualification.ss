;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :clan/poo/object
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (only-in :yuanxu/feature-system/source-lock-feature
                 sources-lock-value sources-lock? sources-lock-ref
                 source-lock-verify-payload)
        (only-in :std/crypto/digest Digest::sha256 digest-from-reader!)
        (only-in :std/io/file call-with-file-reader)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/encoding/json read-json JSONReadOptions current-json-read-options)
        (only-in :yuanxu/modules/json-schema/json-schema-source yuanxu-json-schema-source->json-like)
        (only-in :yuanxu/modules/json-schema/functional yuanxu-contract-object-ref)
        :agentic-ai-lab/modules/services/opentofu/types "./release.ss"
        :agentic-ai-lab/modules/services/opentofu/collections :agentic-ai-lab/modules/services/opentofu/objects
        "./request-types.ss")
(export AwsProviderBinaryContract AwsProviderSourceContract agentic-ai-lab-opentofu-aws-sources-lock agentic-ai-lab-opentofu-aws-provider)

(def (agentic-ai-lab-opentofu-aws-sources-lock)
  (sources-lock-value "opentofu/aws" "5.100.0" #f (.get Aws5100Release sources)))

(def (failure reason path)
  (.cc (.o) 'reason reason 'path path))

(def (entry-failure trusted-lock lock read-source expected)
  (let* ((id (.get expected identity)) (actual (sources-lock-ref lock id))
         (same? (and actual
                     (every (lambda (key) (equal? (.ref expected key) (.ref actual key)))
                            '(identity canonical-uri exact-version digest size-bytes))))
         (valid? (and same? (.get (source-lock-verify-payload trusted-lock id (read-source id)) valid?))))
    (cond ((not same?) (failure 'provider-source-lock-mismatch (list 'source id)))
          ((not valid?) (failure (if (string=? id "schema.json")
                                  'provider-schema-mismatch 'provider-source-payload-mismatch)
                                (list 'source id)))
          (else #f))))

(def (selection-failures selection)
  (let (admission (.call ProviderSelectionContract .admit selection #f))
    (cond
     ((not (yuanxu-validation-evidence-accepted? admission)) (.get admission diagnostics))
     ((not (equal? (.get selection provider) (.get Aws5100Release provider)))
      (list (failure 'provider-identity-mismatch '(selection provider))))
     ((not (equal? (.get selection version) (.get Aws5100Release version)))
      (list (failure 'provider-version-mismatch '(selection version))))
     (else '()))))

(def (source-obligations request _context)
  (let* ((lock (.get request lock)) (read-source (.get request read))
         (trusted-lock (agentic-ai-lab-opentofu-aws-sources-lock))
         (selection-errors (selection-failures (.get request selection))))
    (cond
     ((pair? selection-errors) selection-errors)
     ((not (and (sources-lock? lock) (.get lock .valid?)
                (equal? (.get lock digest) (.get trusted-lock digest))))
      (list (failure 'provider-source-lock-mismatch '(lock))))
     (else
      (filter-map (cut entry-failure trusted-lock lock read-source <>) (.get Aws5100Release sources))))))

;; Explicit binary-source admission streams via the standard digest Reader;
;; the 649 MiB plugin is never loaded into a Scheme bytevector or a fixture.
(def (binary-obligations request _context)
  (let (selection-errors (selection-failures (.get request selection)))
    (if (pair? selection-errors) selection-errors
      (let (digest
             (call-with-file-reader (.get request path)
               (lambda (reader)
                 (string-append "sha256:"
                   (hex-encode (digest-from-reader! (Digest::sha256) reader))))))
        (if (equal? digest (.get Aws5100Release binary-digest)) '()
          (list (failure 'provider-binary-mismatch '(path))))))))

(def AwsProviderBinaryContract
  (.cc ProviderBinaryRequestContract '.obligations binary-obligations))

(def AwsProviderSourceContract
  (.cc ProviderSourceRequestContract '.obligations source-obligations))

(def (decode-schema bytes)
  (parameterize ((current-json-read-options (JSONReadOptions key-as-symbol: #t)))
    (yuanxu-json-schema-source->json-like
      (call-with-input-string (if (u8vector? bytes) (utf8->string bytes) bytes) read-json))))

(def (verified-schema lock read-source)
  (let* ((bytes (read-source "schema.json"))
         (receipt (source-lock-verify-payload
                    (agentic-ai-lab-opentofu-aws-sources-lock) "schema.json" bytes)))
    (unless (.get receipt valid?) (error "provider-schema-mismatch"))
    (decode-schema bytes)))

(def (resource-block schema resource)
  (foldl (lambda (key value) (yuanxu-contract-object-ref value key #f)) schema
         (list 'provider_schemas 'registry.terraform.io/hashicorp/aws
               'resource_schemas resource 'block)))

;; Lock + byte reader is the existing publication boundary. The retained
;; closure rechecks pinned source bytes, never trusts user-provided flags.
(def (agentic-ai-lab-opentofu-aws-provider selection lock read-source)
  (let* ((request (.cc (.o) 'selection selection 'lock lock 'read read-source))
         (admission (.call AwsProviderSourceContract .admit request #f)))
    (unless (yuanxu-validation-evidence-accepted? admission)
      (error "AWS source admission rejected" (.get admission diagnostics)))
    (let (source-check (lambda () (null? (source-obligations request #f))))
      (def (fresh-block resource)
        (resource-block (verified-schema lock read-source) resource))
      (def (authority resource)
        (let ((block (fresh-block resource))
              (paths (.ref (.get Aws5100Release collections) resource)))
          (agentic-ai-lab-opentofu-hash-string-authority
            (.get selection provider) (.get selection version) block paths source-check)))
      (.cc (.o) 'selection selection 'release Aws5100Release 'source-admission admission
           '.block fresh-block
           '.authority authority
           '.contract
           (lambda (resource)
             (let (contract (agentic-ai-lab-opentofu-block-contract resource
                              (fresh-block resource) (authority resource)))
               ;; Source integrity is independent of collection identity. A
               ;; configuration caller does not mint or retain collection proofs.
               (.cc contract '.obligations
                 (lambda (_candidate _context)
                   (if (source-check) '()
                     (list (failure 'provider-source-mismatch '(source))))))))))))
