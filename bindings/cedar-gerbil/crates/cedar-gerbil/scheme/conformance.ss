;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Real POO object construction used only by native conformance qualification.
(import (only-in :std/ffi C-ffi-macrology)
        (only-in :std/encoding/json json->string)
        (only-in :clan/poo/object .o)
        (only-in :std/misc/ports read-all-as-string)
        :agentic-ai-lab/modules/authorization/providers/cedar/objects
        (only-in :gerbil-scheme-rust/scheme/native gerbil-rs-root-string))
(export main)

(C-ffi-macrology)

;; : (-> [String] Void)
(def (main . _) (void))
;; : (-> Char Digest)
(def (digest digit) (string-append "sha256:" (make-string 64 digit)))
;; : CedarSchemaDocument
(def schema-document
  "{\"\":{\"entityTypes\":{\"User\":{},\"Job\":{}},\"actions\":{\"run\":{\"appliesTo\":{\"principalTypes\":[\"User\"],\"resourceTypes\":[\"Job\"],\"context\":{\"type\":\"Record\",\"attributes\":{\"approved\":{\"type\":\"Boolean\"},\"blocked\":{\"type\":\"Boolean\"}}}}}}}}")

;; : (-> Unit CedarAuthoritySnapshot)
(def (snapshot)
  (agentic-ai-lab-cedar-authority-snapshot
   (agentic-ai-lab-cedar-authority-context "native.authority" "native.context" 1 (digest #\2) 7 1 0)
   (agentic-ai-lab-cedar-proof-binding "native.composition" '("native.profile")
     (digest #\1) (digest #\3) (digest #\4) (digest #\5)
     (digest #\a) (digest #\b)
     ["AgenticAILabProof.Runtime.CedarNative" "AgenticAILabProof.Runtime.CedarRuntimeHost"])
   [(agentic-ai-lab-cedar-policy
     "native-atomic-bundle"
     (call-with-input-file
      (getenv "AGENTIC_AI_LAB_CEDAR_POLICY_FILE"
              "../../fixtures/atomic-case/policies.cedar")
      read-all-as-string))]
   (agentic-ai-lab-cedar-schema schema-document)
   (agentic-ai-lab-cedar-entities "[]")
   [(agentic-ai-lab-cedar-runtime-capability "Action::\"run\"" 1)]))

;; : (-> CedarPrincipal Boolean CedarAuthorizationRequest)
(def (request principal blocked?)
  (agentic-ai-lab-cedar-authorization-request principal "Action::\"run\"" "Job::\"demo\""
   (.o (approved #t) (blocked blocked?)) (digest #\6)
   (agentic-ai-lab-cedar-runtime-handoff 1 #u8(10 20 30) (digest #\7) (digest #\0) (digest #\8) (digest #\9))))

;; : (-> Unit NativeRoot)
(def (project-snapshot)
  (with-catch (lambda (_) 0)
    (lambda ()
      (gerbil-rs-root-string
       (json->string (agentic-ai-lab-cedar-authority-snapshot->runtime (snapshot)))))))
;; : (-> CedarPrincipal Boolean NativeRoot)
(def (project-request principal blocked?)
  (with-catch (lambda (_) 0)
    (lambda ()
      (gerbil-rs-root-string (json->string
        (agentic-ai-lab-cedar-authorization-request->runtime (request principal blocked?)))))))

;; begin-foreign bodies are raw Gambit forms, not Gerbil-expanded references.
;; Keep exception handling in the ordinary Gerbil functions and qualify them.
(begin-foreign
  (c-define (snapshot-root) () int64 "agentic_ai_lab_cedar_snapshot_root" "extern"
    (agentic-ai-lab/bindings/cedar-gerbil/crates/cedar-gerbil/scheme/conformance#project-snapshot))
  (c-define (allow-root) () int64 "agentic_ai_lab_cedar_allow_root" "extern"
    (agentic-ai-lab/bindings/cedar-gerbil/crates/cedar-gerbil/scheme/conformance#project-request "User::\"alice\"" #f))
  (c-define (deny-root) () int64 "agentic_ai_lab_cedar_deny_root" "extern"
    (agentic-ai-lab/bindings/cedar-gerbil/crates/cedar-gerbil/scheme/conformance#project-request "User::\"bob\"" #f))
  (c-define (forbid-root) () int64 "agentic_ai_lab_cedar_forbid_root" "extern"
    (agentic-ai-lab/bindings/cedar-gerbil/crates/cedar-gerbil/scheme/conformance#project-request "User::\"alice\"" #t)))
