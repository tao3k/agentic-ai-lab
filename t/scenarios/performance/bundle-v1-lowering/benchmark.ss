;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :clan/poo/object
        :yuanxu/feature-system/bundle-v1-lowering
        :yuanxu/utilities/functional)

(def +agent-count+ 1000)

(def (make-components count)
  (yuanxu-map
   (lambda (index)
     (feature-bundle-v1-component
      1 index
      (+ 100000 index)
      (+ 200000 (modulo index 16))
      (+ 300000 (modulo index 32))
      (+ 400000 (modulo index 64))
      (+ 500000 (modulo index 128))
      (+ 600000 (modulo index 32))
      (+ 700000 (modulo index 16))
      (+ 800000 (modulo index 4))
      (+ 900000 (modulo index 8))
      index))
   (iota count)))

(def (make-edges count)
  (yuanxu-map
   (lambda (index)
     (feature-bundle-v1-edge
      1 (- index 1) index 'depends-on (- index 1)))
   (iota (max 0 (- count 1)) 1)))

(def (make-evidence count)
  (yuanxu-map
   (lambda (index)
     (feature-bundle-v1-evidence
      1 index
      (+ 300000 (modulo index 32))
      'signed-receipt 'lean index))
   (iota count)))

(def started-at (time->seconds (current-time)))
(def plan
  (feature-bundle-v1-lowering
   'multi-agent-bundle 1
   (make-components +agent-count+)
   (make-edges +agent-count+)
   (make-evidence +agent-count+)))
(def elapsed-seconds
  (- (time->seconds (current-time)) started-at))

(unless (.ref plan 'accepted?)
  (error "Bundle v1 multi-agent benchmark lowering failed"
         (.alist/sort (car (.ref plan 'diagnostics)))))

(def descriptor (.ref plan 'descriptor))

(display "schema=agentic-ai-lab.bundle-v1.scheme-lowering-benchmark.1\n")
(display "agents=")
(display +agent-count+)
(newline)
(display "bundle-epoch=")
(display (.ref descriptor 'bundle-epoch))
(newline)
(display "components=")
(display (.ref (.ref descriptor 'components) 'count))
(newline)
(display "edges=")
(display (.ref (.ref descriptor 'edges) 'count))
(newline)
(display "evidence-obligations=")
(display (.ref (.ref descriptor 'evidence-obligations) 'count))
(newline)
(display "arena-bytes=")
(display (.ref descriptor 'arena-bytes))
(newline)
(display "digest-bytes=")
(display (u8vector-length (.ref descriptor 'digest)))
(newline)
(display "elapsed-seconds=")
(display elapsed-seconds)
(newline)
(display "input-interface=poo-native\n")
(display "layout=typed-native-regions\n")
(display "json-in-hot-path=false\n")
