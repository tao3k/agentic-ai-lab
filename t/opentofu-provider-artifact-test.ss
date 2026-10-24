;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/encoding/json write-json)
        (only-in :std/misc/ports read-all-as-u8vector)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/modules/services/opentofu/objects agentic-ai-lab-opentofu-provider-from-directory)
        (only-in :yuanxu/modules/json-schema/json-schema-source yuanxu-json-schema-read-file)
        (only-in :yuanxu/modules/json-schema/json-schema-diagnostics yuanxu-json-schema-validation-diagnostic-metadata)
        :yuanxu/object-types/contracts :clan/poo/object)
(export opentofu-provider-artifact-test)

(def opentofu-provider-artifact-test
  (test-suite "opentofu-provider-artifact-test"
    (yuanxu-test-case "package artifact to native Security Group admission"
      (def (assert label value)
        (unless value (error "assertion failed" label))
        (displayln "ASSERT-OK " label) (force-output))
      (def (accepted? evidence) (yuanxu-validation-evidence-accepted? evidence))
      (def directory (getenv "AGENTIC_AI_LAB_OPENTOFU_TEST_ARTIFACT" "t/fixtures/opentofu/aws-5.100.0"))
      (def manifest (yuanxu-json-schema-read-file (string-append directory "/manifest.json")))
      (def AWS (agentic-ai-lab-opentofu-provider-from-directory directory))
      (assert 'artifact-ready (eq? (.get AWS status) 'ready))
      (assert 'package-version-preserved (equal? (.get AWS version) (cdr (assoc 'version manifest))))
      (def SecurityGroup (.call AWS .contract 'aws_security_group))
      (assert 'selected-contract-memoized (eq? SecurityGroup (.call AWS .contract 'aws_security_group)))
      (assert 'contract-source-preserved (equal? (.get SecurityGroup provider) (.get AWS provider)))
      (assert 'contract-version-preserved (equal? (.get SecurityGroup version) (.get AWS version)))
      (def HTTPS (.o from_port: 443 to_port: 443 protocol: "tcp" cidr_blocks: '("10.0.0.0/16")))
      (def Web (.o name: "web" ingress: (list HTTPS)))
      (assert 'valid-security-group (accepted? (.call SecurityGroup .admit Web #f)))
      (def wrong (.call SecurityGroup .admit
                   (.cc Web 'ingress (list (.cc HTTPS 'from_port "wrong"))) #f))
      (assert 'wrong-port-rejected (not (accepted? wrong)))
      (assert 'wrong-port-path
        (find (lambda (d)
                (equal? (cdr (assoc 'path (yuanxu-json-schema-validation-diagnostic-metadata d)))
                        '(ingress 0 from_port)))
              (.get wrong diagnostics)))
      (assert 'spelling-rejected
        (not (accepted? (.call SecurityGroup .admit (.o ingerss: '()) #f))))
      ;; Export does not contain the SDK's CIDR ValidateFunc.
      (assert 'cidr-export-gap-explicit
        (accepted? (.call SecurityGroup .admit
          (.cc Web 'ingress (list (.cc HTTPS 'cidr_blocks '("10.0.0.1/16")))) #f)))
      (assert 'admit-never-proves-collections
        (accepted? (.call (.cc SecurityGroup '.prove (lambda _ (error "unexpected proof")))
                    .admit Web #f)))
      (assert 'unpublished-resource-rejected
        (with-catch (lambda (_) #t)
          (lambda () (.call AWS .contract 'aws_not_a_real_resource) #f)))
      (call-with-temporary-directory "opentofu-artifact"
        (lambda (tmp)
          (assert 'missing-artifact-build-required
            (eq? (.get (agentic-ai-lab-opentofu-provider-from-directory tmp) status) 'build-required))
          (copy-file (string-append directory "/manifest.json") (string-append tmp "/manifest.json"))
          (def Lazy (agentic-ai-lab-opentofu-provider-from-directory tmp))
          (assert 'manifest-does-not-demand-indexes (eq? (.get Lazy status) 'ready))
          (assert 'missing-selected-index-rejected
            (with-catch (lambda (_) #t)
              (lambda () (.call Lazy .contract 'aws_security_group) #f)))))
      ;; Explicitly synthetic unsupported-type control, now using indexed inputs.
      (call-with-temporary-directory "opentofu-demand-probe"
        (lambda (tmp)
          (def (path name) (string-append tmp "/" name))
          (def (write-text name value)
            (call-with-output-file (path name) (cut display value <>)))
          (def (write-object name rows)
            (call-with-output-file (path name) (cut write-json <> (list->hash-table rows))))
          (def selected "{\"block\":{\"attributes\":{\"name\":{\"type\":\"string\",\"required\":true}}}}")
          (def unsupported "{\"block\":{\"attributes\":{\"value\":{\"type\":\"dynamic\",\"required\":true}}}}")
          (def (digest value) (hex-encode (sha256 (string->utf8 value))))
          (create-directory (path "indexes"))
          (create-directory (path "inputs"))
          (create-directory (path "inputs/resource"))
          (write-text "inputs/resource/selected.json" selected)
          (write-text "inputs/resource/unselected.json" unsupported)
          (def index-digests
            (map (lambda (kind)
                   (let (relative (string-append "indexes/" (symbol->string kind) ".json"))
                     (write-object relative
                       (list '(provider . "test/provider") '(version . "1.0.0")
                             (cons 'schema-sha256 (make-string 64 #\0))
                             (cons 'kind (symbol->string kind))
                             (cons 'entries
                               (list->hash-table
                                 (if (eq? kind 'resource)
                                   (list (cons 'selected (digest selected))
                                         (cons 'unselected (digest unsupported))) '())))))
                     (cons kind (hex-encode (sha256
                       (call-with-input-file (path relative) read-all-as-u8vector))))))
                 '(provider resource data)))
          (write-object "manifest.json"
            (list '(format . "yuanxu/provider-schema-v2")
                  '(provider . "test/provider") '(version . "1.0.0")
                  (cons 'schema-sha256 (make-string 64 #\0))
                  (cons 'indexes (list->hash-table index-digests))))
          (def Scope (agentic-ai-lab-opentofu-provider-from-directory tmp))
          (assert 'unselected-resource-not-compiled
            (accepted? (.call (.call Scope .contract 'selected) .admit (.o name: "ok") #f)))
          (assert 'selected-unsupported-resource-rejected
            (with-catch (lambda (_) #t)
              (lambda () (.call Scope .contract 'unselected) #f)))))
      (displayln "OPENTOFU-PACKAGE-ARTIFACT-OK"))))
