#!/usr/bin/env gxi
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :std/make make make-clean)
        (only-in :clan/poo/object .o .get .call)
        (only-in "./init.ss" yuanxu-deployment-consumer.init.exports)
        (only-in :tao3k/yuanxu/module-system/building/products
                 build-output-directory current-build-source-directory)
        (only-in :tao3k/yuanxu/module-system/building/source-package call-with-build-input-path))
(export main)

(def consumer
  (.o projection: (.call yuanxu-deployment-consumer.init.exports .project-build '("main"))))

(def (main (operation "compile") (observe-make (lambda (action) (action))))
  (def output (build-output-directory))
  (call-with-build-input-path output
    (lambda ()
      (def projection (.get consumer projection))
      (def spec (.get projection spec))
      (case (string->symbol operation)
        ((spec)
         (.call projection .admit-spec spec)
         (write spec) (newline))
        ((compile)
         (.call projection .with-compiler-inputs
           (lambda ()
             (observe-make
               (lambda () (make spec srcdir: (current-build-source-directory) libdir: output verbose: 1))))))
        ((clean)
         (.call projection .with-clean-outputs
           (lambda ()
             (observe-make
               (lambda () (make-clean spec srcdir: (current-build-source-directory) libdir: output))))))
        (else (error "unknown fixture build operation" operation))))))
