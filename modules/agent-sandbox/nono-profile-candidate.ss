;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: nono dynamic profile candidate projection lives here.
;;; Boundary: this module emits candidate data only; it never promotes profiles.
;;; Runtime contract: JSON decoding and nono execution belong to CLI/Marlin.

(import :agentic-ai-lab/modules/agent-sandbox/alist
        :agentic-ai-lab/modules/agent-sandbox/profile-candidate)

(export make-nono-agent-sandbox-profile-candidate-descriptor
        make-nono-agent-sandbox-profile-candidate
        nono-why-json->agent-sandbox-profile-candidate-choice
        nono-why-json->agent-sandbox-profile-candidate)

;;; nono dynamic profile candidates keep learning/save observations as Scheme
;;; data. The Marlin runtime or nono CLI bridge owns actual promote/apply.
;; : (-> Symbol [Alist] AgentSandboxProfileCandidateDescriptor)
(def (make-nono-agent-sandbox-profile-candidate-descriptor source
                                                           . maybe-options)
  (make-agent-sandbox-profile-candidate-descriptor
   'nono-profile-candidate
   'nono
   source
   (if (null? maybe-options) '() (car maybe-options))))

;;; Boundary: make nono agent sandbox profile candidate is the policy-visible
;;; edge for sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol [ProfileCandidateChoice] [Alist] ProfileCandidate)
(def (make-nono-agent-sandbox-profile-candidate source
                                                choices
                                                . maybe-options)
  (agent-sandbox-profile-candidate-descriptor->candidate
   (make-nono-agent-sandbox-profile-candidate-descriptor source)
   choices
   (if (null? maybe-options) '() (car maybe-options))))

;;; Parsed `nono why --json` receipts become profile candidates, not runtime
;;; actions. JSON decoding belongs to CLI/Marlin; this module only projects the
;;; resulting alist into the common candidate contract.
;; : (-> Alist Symbol Value Value)
(def (nono-why-json-ref why key default)
  (let (entry (nono-why-json-entry why key))
    (if entry
      (nono-why-json-entry-value entry)
      default)))

;; : (-> Alist Symbol Pair)
(def (nono-why-json-entry why key)
  (or (and why (assoc key why))
      (and why (assoc (symbol->string key) why))))

;; : (-> Pair Value)
(def (nono-why-json-entry-value entry)
  (cdr entry))

;; : (-> Value Symbol Boolean)
(def (nono-why-json-symbol=? value symbol)
  (or (eq? value symbol)
      (and (string? value)
           (string=? value (symbol->string symbol)))))

;;; Boundary: nono why json choice action is the policy-visible edge for
;;; sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Value Symbol)
(def (nono-why-json-choice-action status)
  (if (nono-why-json-symbol=? status 'denied)
    'grant
    'skip))

;;; Boundary: nono why json choice section is the policy-visible edge for
;;; sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Value Symbol)
(def (nono-why-json-choice-section reason)
  (if (or (nono-why-json-symbol=? reason 'path_not_granted)
          (nono-why-json-symbol=? reason 'granted_path))
    'filesystem
    'nono-why))

;; : (-> Alist Alist Alist)
(def (nono-why-json-choice-value why options)
  (let* ((path (agent-sandbox-option
                options
                'path
                (nono-why-json-ref why 'path #f)))
         (op (agent-sandbox-option
              options
              'op
              (nono-why-json-ref why 'op #f))))
    (list (cons 'status (nono-why-json-ref why 'status #f))
          (cons 'reason (nono-why-json-ref why 'reason #f))
          (cons 'path path)
          (cons 'op op)
          (cons 'details (nono-why-json-ref why 'details #f))
          (cons 'suggested-flag
                (nono-why-json-ref why 'suggested_flag #f))
          (cons 'granted-path
                (nono-why-json-ref why 'granted_path #f))
          (cons 'access (nono-why-json-ref why 'access #f))
          (cons 'source (nono-why-json-ref why 'source #f))
          (cons 'raw why))))

;;; Boundary: nono why json to agent sandbox profile candidate is the policy-
;;; visible edge for sandbox behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;;; Boundary: nono why json to agent sandbox profile candidate choice is the
;;; policy-visible edge for sandbox behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> NonoWhyJsonAlist [Alist] ProfileCandidateChoice)
(def (nono-why-json->agent-sandbox-profile-candidate-choice why
                                                            . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (status (nono-why-json-ref why 'status #f))
         (reason (nono-why-json-ref why 'reason #f)))
    (make-agent-sandbox-profile-candidate-choice
     (nono-why-json-choice-action status)
     (list (cons 'section (nono-why-json-choice-section reason))
           (cons 'value (nono-why-json-choice-value why options))))))

;;; Boundary: nono why json to agent sandbox profile candidate is the policy-
;;; visible edge for sandbox behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> NonoWhyJsonAlist [Alist] ProfileCandidate)
(def (nono-why-json->agent-sandbox-profile-candidate why . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (source (agent-sandbox-option options 'source 'nono-why-json))
         (choice
          (nono-why-json->agent-sandbox-profile-candidate-choice
           why
           options))
         (observations
          (agent-sandbox-option
           options
           'observations
           (list (list (cons 'kind 'nono-why-json)
                       (cons 'receipt why))))))
    (make-nono-agent-sandbox-profile-candidate
     source
     (list choice)
     (list (cons 'profile-ref
                 (agent-sandbox-option options 'profile-ref #f))
           (cons 'command
                 (agent-sandbox-option options 'command #f))
           (cons 'observations observations)
           (cons 'metadata
                 (agent-sandbox-option options 'metadata '()))))))
