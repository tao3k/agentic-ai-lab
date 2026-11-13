;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :yuanxu-deployment-consumer/main selected-deployment)
        (only-in :yuanxu-deployment-consumer/init yuanxu-deployment-consumer.init.exports)
        (only-in :clan/poo/object .get .all-slots .ref/cached)
        (only-in :gerbil/runtime/loader list-modules)
        (only-in :tao3k/yuanxu/module-system/source/admission call-with-module-source-operation-measurement))
(export verify-deployment-use verify-deployment-runtime)
(def (publication-reads times)
  (+ (hash-ref times '(calls candidate-read) 0)
     (hash-ref times '(calls publication-read) 0)))
(def (verify-deployment-use)
  (displayln "LAB-DEPLOYMENT-USE enter epoch=" (time->seconds (current-time)) " cpu=" (cpu-time))
  (force-output)
  (defvalues (lab namespace-times)
    (call-with-module-source-operation-measurement
      (lambda () (.get yuanxu-deployment-consumer.init.exports Lab)) accounting?: #f))
  (unless (and (equal? (.all-slots lab) '(services))
               (equal? (.all-slots (.get lab services)) '(opentofu))
               (null? (.all-slots (.get yuanxu-deployment-consumer.init.exports Core)))
               (zero? (publication-reads namespace-times))
               (zero? (hash-ref namespace-times '(calls scope-factory) 0))
               (not (.ref/cached (.get lab services) 'opentofu)))
    (error "Profile must expose only category roots without forcing a scope"))
  (displayln "LAB-DEPLOYMENT-GET enter epoch=" (time->seconds (current-time)) " cpu=" (cpu-time))
  (force-output)
  (defvalues (scope first-times)
    (call-with-module-source-operation-measurement selected-deployment accounting?: #f))
  (displayln "LAB-DEPLOYMENT-GET return epoch=" (time->seconds (current-time)) " cpu=" (cpu-time))
  (force-output)
  (unless (and (= (publication-reads first-times) 4)
               (= (hash-ref first-times '(calls scope-factory) 0) 4)
               (andmap (lambda (id) (= (hash-ref first-times (list 'calls (list 'scope-factory id)) 0) 1))
                       '(tao3k/agentic-ai-lab/modules/nix/interface tao3k/yuanxu/modules/json-schema/interface
                         tao3k/yuanxu/modules/funflow/interface tao3k/agentic-ai-lab/modules/services/opentofu/interface)))
    (error "First business read must admit and construct exactly the selected closure"))
  (defvalues (again repeat-times)
    (call-with-module-source-operation-measurement selected-deployment accounting?: #f))
  (unless (and (eq? scope again)
               (zero? (publication-reads repeat-times))
               (zero? (hash-ref repeat-times '(calls scope-factory) 0)))
    (error "Repeated native .get must retain scope identity without readmission"))
  (def test-order (.get yuanxu-deployment-consumer.init.exports tests selected-graph module-order))
  (unless (equal? test-order
                  '(tao3k/agentic-ai-lab/modules/nix/interface tao3k/yuanxu/modules/json-schema/interface
                         tao3k/yuanxu/modules/funflow/interface tao3k/agentic-ai-lab/modules/services/opentofu/interface))
    (error "Test projection differs from the runtime dependency closure" test-order))
  (unless (equal? ((.get scope schema type) '("map" "string"))
                  '((type . "object") (additionalProperties . ((type . "string")))))
    (error "OpenTofu public schema operation failed"))
  (displayln "LAB-DEPLOYMENT-USE-OK declarations=4 scopes=4 schema=map-string"))
(def (verify-deployment-runtime)
  (verify-deployment-use)
  ;; The independent runtime must actually initialize B's native products,
  ;; even though its build frontend retained the prerequisite tool Contexts.
  (def library (string-append (path-strip-trailing-directory-separator
                               (path-normalize (path-expand "lib" (gerbil-path)))) "/"))
  (for-each
    (lambda (identity)
      (def loaded (assoc identity (list-modules)))
      (unless (and loaded (string? (cdr loaded)) (string-prefix? library (path-normalize (cdr loaded))))
        (error "runtime did not initialize the selected downstream product" identity loaded)))
    '("yuanxu-deployment-consumer/main~0"
      "yuanxu-deployment-consumer/init~0"
      "tao3k/yuanxu/modules/json-schema/json-schema-contract~0"
      "tao3k/yuanxu/modules/funflow/objects~0"))
  (displayln "LAB-DEPLOYMENT-PRODUCT-USE-OK"))

(def (main) (verify-deployment-runtime))
