;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Complete native dependency imports before the original guarded cases.
;;; Output reports actual import boundaries, never a timer heartbeat.
(for-each
 (lambda (module)
   (displayln "IMPORT " module) (force-output)
   (eval `(import ,module))
   (displayln "IMPORT-OK " module) (force-output))
 '(:clan/poo/object
   :clan/poo/mop
   :clan/poo/trie
   :yuanxu/object-types/contracts
   :yuanxu/module-system/schema/slot-contracts
   :yuanxu/observability/testing-case
   :gerbil-ascent/table/expression
   :gerbil-ascent/core/binary-relation
   :gerbil-ascent/core/binary-program
   :gerbil/tools/gxtest))
(eval '(exit (gerbil/tools/gxtest#main "-v" "5"
                                    "t/qualification/ascent-integration/guarded-test.ss")))
