;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Appended to the unmodified SDK test executor before native compilation.
;;; Tests still import their real source in an isolated process.
(import :clan/poo/object
        :clan/poo/mop
        :yuanxu/object-types/contracts
        :yuanxu/module-system/interface
        :yuanxu/observability/testing-case
        :yuanxu/observability/testing-fixture)
