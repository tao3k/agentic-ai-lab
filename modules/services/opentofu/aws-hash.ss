;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure correspondence to AWS 5.100.0 and SDK 2.36.1, on darwin_arm64.
(import (only-in :std/list/list delete-duplicates/hash)
        :std/text/pregexp
        (only-in :yuanxu/modules/json-schema/functional yuanxu-contract-object-ref)
        (only-in :yuanxu/modules/json-schema/json-schema-validation-core
                 yuanxu-json-schema-candidate-rows))
(export agentic-ai-lab-opentofu-aws-string-hash agentic-ai-lab-opentofu-aws-string-set
        agentic-ai-lab-opentofu-aws-rule-hash agentic-ai-lab-opentofu-aws-rule-key
        agentic-ai-lab-opentofu-aws-string-collision?)

;; No CRC32 primitive is exported by the installed Gerbil standard library.
;; Reflected IEEE polynomial; the result is unsigned on the pinned 64-bit target.
(def crc32-table
  (list->vector
    (map (lambda (byte)
           (foldl (lambda (_ value)
                    (bitwise-xor (arithmetic-shift value -1)
                                 (if (odd? value) #xedb88320 0)))
                  byte (iota 8)))
         (iota 256))))

(def (agentic-ai-lab-opentofu-aws-string-hash text)
  (bitwise-xor #xffffffff
    (foldl (lambda (byte crc)
             (bitwise-xor (arithmetic-shift crc -8)
               (vector-ref crc32-table (bitwise-and (bitwise-xor crc byte) #xff))))
           #xffffffff (u8vector->list (string->utf8 text)))))

;; SDK Set.add keeps the first value for a hash key, even on CRC collisions.
;; Set.List sorts the DECIMAL STRING keys, not numerically or by element text.
(def (agentic-ai-lab-opentofu-aws-string-set values)
  (list-sort
    (lambda (left right)
      (string<? (number->string (agentic-ai-lab-opentofu-aws-string-hash left))
                (number->string (agentic-ai-lab-opentofu-aws-string-hash right))))
    (delete-duplicates/hash values key: agentic-ai-lab-opentofu-aws-string-hash from-end?: #t)))

(def (agentic-ai-lab-opentofu-aws-string-collision? values)
  (not (= (length (delete-duplicates/hash values from-end?: #t))
          (length (agentic-ai-lab-opentofu-aws-string-set values)))))

(def protocols '(("icmpv6" . 58) ("udp" . 17) ("tcp" . 6) ("icmp" . 1) ("all" . -1)))
(def (protocol-name text)
  (let* ((name (string-downcase text)) (number (and (pregexp-match "^[+-]?[0-9]+$" name) (string->number name))))
    (cond ((member name '("all" "-1")) "-1")
          ((assoc name protocols) name)
          ((and (and (integer? number) (exact? number))
                (find (lambda (row) (= number (cdr row))) protocols)) => car)
          (else name))))

;; Hash correspondence only, not complete resource admission. Unknown values,
;; SDK defaults, validators and AWS execution remain separate responsibilities.
(def (agentic-ai-lab-opentofu-aws-rule-key rule)
  (let* ((rows (yuanxu-json-schema-candidate-rows rule))
         (ref (lambda (key fallback) (yuanxu-contract-object-ref rows key fallback)))
         (parts
           (append
             (list (number->string (ref 'from_port 0))
                   (number->string (ref 'to_port 0))
                   (protocol-name (ref 'protocol ""))
                   (if (ref 'self #f) "true" "false"))
             (apply append
               (map (lambda (key) (list-sort string<? (ref key '())))
                    '(cidr_blocks ipv6_cidr_blocks prefix_list_ids)))
             (list-sort string<?
               (agentic-ai-lab-opentofu-aws-string-set (ref 'security_groups '())))
             (let (description (ref 'description ""))
               (if (string=? description "") '() (list description))))))
    (apply string-append (map (lambda (part) (string-append part "-")) parts))))

(def (agentic-ai-lab-opentofu-aws-rule-hash rule)
  (agentic-ai-lab-opentofu-aws-string-hash (agentic-ai-lab-opentofu-aws-rule-key rule)))
