;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Construct typed Store requests without selecting a runner or adapter.
(import (only-in "control-plane/signatures.ss" Fun String)
        (only-in "control-plane/runtime-protocol.ss" AdapterResult)
        (only-in "control-plane/task.ss" make-task)
        (only-in "control-plane/flow.ss" task-flow))
(export make-store-task store-flow put-dir-flow get-dir-flow)

;; : (-> Symbol Symbol Payload Function Task)
(def (make-store-task name operation payload signature)
  (make-task name 'store (list 'store operation payload) signature #f))

;; : (-> Symbol Symbol Payload Function Flow)
(def (store-flow name operation payload signature)
  (task-flow name (make-store-task name operation payload signature)))

;; : (-> Symbol Symbol Payload)
(def (store-directory-payload task-name operation)
  (list (cons 'store-task task-name)
        (cons 'content-kind 'directory)
        (cons 'operation operation)))

;;; Funflow exposes putDirFlow as the user-facing directory-to-CAS-item arrow.
;;; The Scheme side keeps this as request data for the runtime adapter.
;; : (-> Symbol Flow)
(def (put-dir-flow name)
  (store-flow
   name
   'put
   (store-directory-payload 'put-dir 'put)
   (Fun AdapterResult <- String)))

;;; Funflow exposes getDirFlow as the user-facing CAS-item-to-directory arrow.
;;; The Scheme side only declares the adapter request and flow contracts.
;; : (-> Symbol Flow)
(def (get-dir-flow name)
  (store-flow
   name
   'get
   (store-directory-payload 'get-dir 'get)
   (Fun AdapterResult <- String)))
