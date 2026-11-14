;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o) (only-in :std/source this-source-path))

(.def Build
  defbuild-script:
  (.o spec:
    `((gxc: "_nono"
            "-cc-options" ,(string-append "-I" (this-source-path this-source-path "nono-c"))
            "-ld-options" ,(cond-expand (darwin "-Wl,-undefined,dynamic_lookup")
                                       (else "-ldl"))))))
