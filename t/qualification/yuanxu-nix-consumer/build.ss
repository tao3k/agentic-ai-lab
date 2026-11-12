#!/usr/bin/env gxi
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .get)
        (only-in :std/source this-source-file)
        (only-in :yuanxu/module-system/building/source-closure package-library-spec)
        (only-in :yuanxu/module-system/building/interface call-with-init-build-spec)
        (only-in :yuanxu/module-system/building/products current-build-source-directory)
        (only-in :std/build-script defbuild-script)
        (only-in "./init.ss" yuanxu-nix-consumer.init.exports))
(def application-spec
  (package-library-spec (path-directory (this-source-file)) 'yuanxu-nix-consumer '("main.ss")))
(def (main . args)
  (def entry-source (this-source-file))
  (call-with-init-build-spec
    (lambda () ((.get yuanxu-nix-consumer.init.exports std-make-spec) application-spec))
    (lambda (spec arguments (package-prefix #f))
      (def (this-source-file)
        (let (directory (current-build-source-directory))
          (if directory (path-expand (path-strip-directory entry-source) directory)
            entry-source)))
      (if package-prefix
        (let ()
          (defbuild-script spec prefix: package-prefix)
          (apply main arguments))
        (let ()
          (defbuild-script spec)
          (apply main arguments))))
    args #f entry-source))
