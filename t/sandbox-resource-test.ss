;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared sandbox resources are backend-neutral POO data objects.
;;; Invariant: tests assert composition and projection only, never runtime setup.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        :agentic-ai-lab/modules/agent-sandbox/resource)

(export sandbox-resource-test)

;;; This suite anchors sandbox resource descriptors before backend-specific
;;; modules extend them.
;; : TestSuite
(def sandbox-resource-test
  (test-suite "shared sandbox resources"
    (yuanxu-test-case "projects volume, port, and env bindings as runtime request data"
      (let* ((volume (make-sandbox-volume-binding 'source-item "/work" 'read))
             (port (make-sandbox-port-binding 'http 8080 18080 'tcp))
             (env (make-sandbox-env-binding 'TOKEN "secret-key" 'secret))
             (resource-set (make-sandbox-resource-set
                            (list volume)
                            (list port)
                            (list env)))
             (request (sandbox-resource-set->request resource-set)))
        (check-equal? (cdr (assoc 'volumes request))
                      '(((store-item . source-item)
                         (mount-path . "/work")
                         (mode . read)
                         (read-only? . #t))))
        (check-equal? (cdr (assoc 'ports request))
                      '(((name . http)
                         (container-port . 8080)
                         (host-port . 18080)
                         (protocol . tcp))))
        (check-equal? (cdr (assoc 'env request))
                      '(((name . TOKEN)
                         (value . "secret-key")
                         (source . secret))))))
    (yuanxu-test-case "merges resource sets with left-biased sandbox keys"
      (let* ((left (make-sandbox-resource-set
                    (list (make-sandbox-volume-binding 'source-item "/work" 'read)
                          (make-sandbox-volume-binding 'config-item "/config" 'read))
                    (list (make-sandbox-port-binding 'http 8080 18080 'tcp))
                    (list (make-sandbox-env-binding 'TOKEN "left" 'literal))))
             (right (make-sandbox-resource-set
                     (list (make-sandbox-volume-binding 'other-source "/work" 'read-write)
                           (make-sandbox-volume-binding 'cache-item "/cache" 'read-write))
                     (list (make-sandbox-port-binding 'http-alt 8080 28080 'tcp)
                           (make-sandbox-port-binding 'metrics 9090 #f 'tcp))
                     (list (make-sandbox-env-binding 'TOKEN "right" 'literal)
                           (make-sandbox-env-binding 'MODE "debug" 'literal))))
             (merged (sandbox-resource-set-merge left right))
             (request (sandbox-resource-set->request merged)))
        (check-equal? (cdr (assoc 'volumes request))
                      '(((store-item . source-item)
                         (mount-path . "/work")
                         (mode . read)
                         (read-only? . #t))
                        ((store-item . config-item)
                         (mount-path . "/config")
                         (mode . read)
                         (read-only? . #t))
                        ((store-item . cache-item)
                         (mount-path . "/cache")
                         (mode . read-write)
                         (read-only? . #f))))
        (check-equal? (cdr (assoc 'ports request))
                      '(((name . http)
                         (container-port . 8080)
                         (host-port . 18080)
                         (protocol . tcp))
                        ((name . metrics)
                         (container-port . 9090)
                         (host-port . #f)
                         (protocol . tcp))))
        (check-equal? (cdr (assoc 'env request))
                      '(((name . TOKEN)
                         (value . "left")
                         (source . literal))
                        ((name . MODE)
                         (value . "debug")
                         (source . literal))))))))
