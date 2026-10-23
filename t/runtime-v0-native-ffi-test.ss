#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .ref)
        (only-in :std/encoding/json
                 JSONReadOptions
                 current-json-read-options
                 string->json)
        (only-in :agentic-ai-lab/modules/workflow/runtime/runtime-v0-native
                 native-abi-version
                 native-descriptor-payload
                 native-query-execution-candidate->json
                 native-query-execution-candidate<-json
                 native-validate-payload
                 native-c-round-trip)
        (only-in :agentic-ai-lab/modules/query/objects
                 agentic-ai-lab-query-execution-candidate)
        (only-in :agentic-ai-lab/modules/query/types
                 agentic-ai-lab-query-execution-candidate?))

(export runtime-v0-native-ffi-test)

(def (runtime-test-json-object text)
  (parameterize ((current-json-read-options
                  (JSONReadOptions object-as-hash: #t)))
    (string->json text)))

(def valid-source-query
  #<<JSON
{"source-language":"scheme","source-content-id":"sha256:source","source-version":"1","parser-id":"gerbil-parser","parser-version":"1","query-id":"q1","query-version":"1","selected-node-identities":["node-1"],"representation":"ast-data","provenance-root":"sha256:provenance","result-digest":"sha256:result"}
JSON
  )

(def valid-query-execution-candidate
  (agentic-ai-lab-query-execution-candidate
   'mrr 'healthcare-impact "1" "healthcare-1" "sha256:source"
   'gerbil-parser "sha256:provenance" "sha256:result" 0 #f))

(def runtime-v0-native-ffi-test
  (test-suite "Runtime v0 Scheme-native C ABI"
    (yuanxu-test-case "descriptor is versioned and bounded"
      (check (native-abi-version) => 1)
      (let (descriptor (runtime-test-json-object (native-descriptor-payload)))
        (check (hash-get descriptor "schema")
               => "agentic-ai-lab.scheme-native-descriptor.v1")
        (check (hash-get descriptor "runtimeAbiMajor") => 0)
        (check (hash-get descriptor "runtimeAbiMinor") => 1)
        (check (hash-get descriptor "maximumInputBytes") => (* 16 1024 1024))
        (check (length (hash-get descriptor "contracts")) => 4)))
    (yuanxu-test-case "valid POO contract crosses as a validation receipt"
      (let (receipt
            (runtime-test-json-object
             (native-validate-payload "source-query-receipt"
                                      valid-source-query)))
        (check (hash-get receipt "valid") => #t)
        (check (length (hash-get receipt "failures")) => 0)))
    (yuanxu-test-case "MRR execution candidate becomes the canonical Query object"
      (let* ((wire
              (native-query-execution-candidate->json
               valid-query-execution-candidate))
             (object (runtime-test-json-object wire))
             (candidate (native-query-execution-candidate<-json object))
             (receipt
              (runtime-test-json-object
               (native-validate-payload "query-execution-candidate"
                                        wire))))
        (check (agentic-ai-lab-query-execution-candidate? candidate) => #t)
        (check (.ref candidate 'query-identity) => 'healthcare-impact)
        (check (.ref candidate 'complete?) => #f)
        (check (hash-get receipt "valid") => #t)
        (check (length (hash-get receipt "failures")) => 0)))
    (yuanxu-test-case "execution candidate rejects invalid runtime evidence"
      (check-exception
       (native-validate-payload
        "query-execution-candidate"
        "{\"provider-identity\":\"mrr\",\"query-identity\":\"q1\",\"query-version\":\"1\",\"semantic-revision\":\"r1\",\"source-content-identity\":\"sha256:source\",\"parser-identity\":\"gerbil-parser\",\"provenance-root\":\"sha256:provenance\",\"result-digest\":\"sha256:result\",\"result-count\":-1,\"complete\":false}")
       true))
    (yuanxu-test-case "qualification receipt cannot substitute for execution evidence"
      (check-exception
       (native-validate-payload "query-execution-candidate"
                                valid-source-query)
       true))
    (yuanxu-test-case "semantic failure remains typed rather than exceptional"
      (let* ((invalid
              (string-append
               "{\"source-language\":\"scheme\",\"source-content-id\":\"sha256:source\","
               "\"source-version\":\"1\",\"parser-id\":\"gerbil-parser\","
               "\"parser-version\":\"1\",\"query-id\":\"q1\",\"query-version\":\"1\","
               "\"selected-node-identities\":[\"node-1\"],\"representation\":\"unknown\","
               "\"provenance-root\":\"sha256:provenance\",\"result-digest\":\"sha256:result\"}"))
             (receipt
              (runtime-test-json-object
               (native-validate-payload "source-query-receipt" invalid))))
        (check (hash-get receipt "valid") => #f)
        (check (car (hash-get receipt "failures"))
               => "unsupported-source-representation")))
    (yuanxu-test-case "unknown contract fails closed"
      (check-exception
       (native-validate-payload "unknown" "{}") true))
    (yuanxu-test-case "C consumer observes the exported ABI and releases its result"
      (check (native-c-round-trip) => 0))))
