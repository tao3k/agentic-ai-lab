;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Read the actual native Make import graph without compiling or scheduling it.
(import :clan/poo/object
        :gerbil/expander
        (only-in :std/encoding/json write-json))
(export write-native-test-build-inspection)

(def (import-context value)
  (cond
    ((module-import? value) (import-context (module-import-source value)))
    ((module-export? value) (import-context (module-export-context value)))
    ((import-set? value) (import-context (import-set-source value)))
    (else value)))

(def (write-native-test-build-inspection build)
  ((.get build admit-current))
  (parameterize ((current-expander-context (make-top-context)))
    (for-each
      (lambda (spec)
        (def context
          (core-import-module
            (path-expand (string-append (cadr spec) ".ss") (.get build source-root))))
        (def dependencies
          (filter-map
            (lambda (value)
              (def dependency (import-context value))
              (and (or (module-context? dependency) (prelude-context? dependency))
                   (expander-context-id dependency)
                   (symbol->string (expander-context-id dependency))))
            (module-context-import context)))
        (def row (make-hash-table))
        (hash-put! row 'kind "native-test-build-target")
        (hash-put! row 'target (cadr spec))
        (hash-put! row 'identity (symbol->string (expander-context-id context)))
        (hash-put! row 'dependencies (list->vector dependencies))
        (write-json (current-output-port) row)
        (newline))
      (.get build spec)))
  ((.get build admit-current)))
