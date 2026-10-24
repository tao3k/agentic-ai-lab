;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Package input: manifest -> kind index -> one hashed Contract input.
;;; schema.json is an audit export, never a runtime input. No legacy fallback.
(import :clan/poo/object
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :std/encoding/json read-json JSONReadOptions current-json-read-options)
        (only-in :yuanxu/modules/json-schema/json-schema-source
                 yuanxu-json-schema-source->json-like yuanxu-json-schema-read-port)
        (only-in :yuanxu/modules/json-schema/functional yuanxu-contract-object-ref)
        "./types.ss")
(export agentic-ai-lab-opentofu-read-provider-artifact)

(def (required rows key)
  (or (yuanxu-contract-object-ref rows key #f)
      (error "provider-schema-field-missing" key)))

(def (decode-input bytes)
  (parameterize ((current-json-read-options (JSONReadOptions key-as-symbol: #t)))
    (yuanxu-json-schema-source->json-like
      (call-with-input-string (utf8->string bytes) read-json))))

(def (admit-artifact contract value message)
  (let (result (.call contract .admit value #f))
    (unless (yuanxu-validation-evidence-accepted? result)
      (error message (.get result diagnostics)))))

(def (indexed-artifact directory manifest manifest-input)
  (let ((indexes (make-hash-table-eq)) (reads (make-hash-table test: equal?))
        (snapshots (make-hash-table test: equal?)))
    (def (verified-input relative expected)
      (let (path (string-append directory "/" relative))
        (unless (file-exists? path)
          (error "build-required: Provider artifact input missing" path))
        (let (bytes (call-with-input-file path read-all-as-u8vector))
          (unless (equal? (hex-encode (sha256 bytes)) expected)
            (error "provider-artifact-input-digest-mismatch" relative))
          (hash-put! snapshots relative (cons path (utf8->string bytes)))
          ;; Hash and parse the same selected bytes.
          (decode-input bytes))))
    (def (index kind)
      (unless (memq kind '(provider resource data))
        (error "unsupported-provider-contract-kind" kind))
      (or (hash-ref indexes kind #f)
          (let (value
                 (verified-input (string-append "indexes/" (symbol->string kind) ".json")
                                 (required (required manifest 'indexes) kind)))
            (admit-artifact ProviderTypeIndexContract value "provider-type-index-rejected")
            (unless (and (equal? (required value 'kind) (symbol->string kind))
                         (every (lambda (key) (equal? (required manifest key) (required value key)))
                                '(provider version schema-sha256)))
              (error "provider-type-index-binding-mismatch" kind))
            (let (table (list->hash-table (required value 'entries) test: eq?))
              (hash-put! indexes kind table)
              table))))
    (def (entry-digest name kind)
      ;; Names, not arbitrary manifest paths, determine package-relative inputs.
      (unless (and (symbol? name) (pregexp-match "^[A-Za-z0-9_]+$" (symbol->string name)))
        (error "invalid-provider-type-name" name))
      (hash-ref (index kind) name #f))
    (def (read-entry name kind)
      (let (digest (or (entry-digest name kind) (error "provider-schema-type-missing" kind name)))
        (let (value (verified-input
                     (string-append "inputs/" (symbol->string kind) "/" (symbol->string name) ".json")
                     digest))
          (hash-update! reads (cons kind name) 1+ 0)
          (.cc (.o) 'schema value 'digest digest
            'source-inputs
            (list manifest-input
              (hash-ref snapshots (string-append "indexes/" (symbol->string kind) ".json"))
              (hash-ref snapshots
                (string-append "inputs/" (symbol->string kind) "/" (symbol->string name) ".json")))))))
    (.cc (.o) 'status 'ready 'manifest manifest
         '.names (lambda (kind) (hash-keys (index kind)))
         '.contains? (lambda (name kind) (if (entry-digest name kind) #t #f))
         '.read-entry read-entry
         '.index-loaded? (lambda (kind) (hash-key? indexes kind))
         '.entry-read-count (lambda (name kind) (hash-ref reads (cons kind name) 0)))))

(def (agentic-ai-lab-opentofu-read-provider-artifact directory)
  (let (path (string-append directory "/manifest.json"))
    (if (not (file-exists? path))
      (.cc (.o) 'status 'build-required 'directory directory 'missing '("manifest.json"))
      (let* ((text (call-with-input-file path (lambda (port) (utf8->string (read-all-as-u8vector port)))))
             (manifest (call-with-input-string text yuanxu-json-schema-read-port)))
        (admit-artifact ProviderArtifactContract manifest "provider-artifact-manifest-rejected")
        (indexed-artifact directory manifest (cons path text))))))
