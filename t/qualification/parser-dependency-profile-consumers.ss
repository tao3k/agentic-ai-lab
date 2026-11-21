;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Run against an isolated Parser library plus the admitted reference consumers.
;;; This fixture is not evidence of a fresh full compilation or CI wall time.
(import (only-in :gerbil/expander/module core-resolve-library-module-path)
        (rename-in (only-in :orgize/languages/org/event-runtime parse-org-native-events) (parse-org-native-events parse-org-events))
        :tao3k/agentic-ai-lab/modules/query/gql
        :tao3k/agentic-ai-lab/modules/query/rust-ir)
(export main)
(def (main selected-root selected-spec)
  (for-each
   (lambda (source)
     (unless (string? source) (error "expected a runtime library source" source))
     (let* ((module (string->symbol
                     (string-append ":gerbil-parser/" (path-strip-extension source))))
            (path (core-resolve-library-module-path module)))
       (unless (string-prefix? selected-root path)
         (error "Parser source escaped the selected library" module path))))
   (call-with-input-file selected-spec read))
  (let (events (parse-org-events "* TODO smoke\n"))
    (unless (pair? events) (error "Orgize did not parse the smoke headline" events)))
  (displayln "SELECTED-PARSER-CONSUMERS-PASS"))
