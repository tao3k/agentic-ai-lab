;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: small pure helpers shared by workflow graph and ABI projections.

(export yuanxu-cicd-alist-ref
        yuanxu-cicd-symbol-member?)

(def (yuanxu-cicd-alist-ref alist key default)
  (let (entry (assoc key alist))
    (if entry (cdr entry) default)))

(def (yuanxu-cicd-symbol-member? value values)
  (and (member value values) #t))
