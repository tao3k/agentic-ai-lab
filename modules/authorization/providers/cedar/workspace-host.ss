;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .ref .call)
        (only-in "funs.ss" agentic-ai-lab-cedar-workspace-retry-request)
        (only-in "runtime-port.ss" agentic-ai-lab-cedar-runtime-port))
(export agentic-ai-lab-cedar-workspace-host agentic-ai-lab-cedar-open-workspace-host)

;; The deployment owns the returned host and closes it when its service stops.
(def (agentic-ai-lab-cedar-open-workspace-host endpoint deployment)
  (let* ((runtime (agentic-ai-lab-cedar-runtime-port
                    (.ref deployment 'issuer-executable)
                    (.ref deployment 'runtime-socket)
                    (.ref deployment 'runtime-artifact)
                    (.ref deployment 'snapshot)))
         (host (agentic-ai-lab-cedar-workspace-host endpoint runtime deployment)))
    (.o (:: @ host) .close!: (lambda (self) (.call runtime .close! runtime)))))

;; The runtime port owns live issuance, verification and consumption.
;; The endpoint owns its workspace scope, repeat evidence and external write.
;; The same projection is used at all three authorization boundaries.
(def (agentic-ai-lab-cedar-workspace-host endpoint runtime deployment)
  (def (project request)
    (let (coordinates (.call deployment .handoff-coordinates deployment request))
      (agentic-ai-lab-cedar-workspace-retry-request request
        (.ref deployment 'subject) (.ref coordinates 'sequence)
        (.ref coordinates 'semantic-root) (.ref coordinates 'execution-root))))
  (.o (:: @ endpoint)
    .issue-retry!: (lambda (self request)
      (.call runtime .issue! runtime (project request) request))
    .retry-authorization: (lambda (self request token)
      (.call runtime .check runtime (project request) token))
    .consume-retry-authorization!: (lambda (self request token)
      (.call runtime .consume! runtime (project request) token))))
