;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Runtime source controls using the installed std/test harness.
(import :std/test/base
        (only-in "../../integration/lab/funflow/control-plane-role-test.ss" control-plane-role-test)
        (only-in "../../integration/lab/funflow/feature-bundle-v1-composition-writer-test.ss" feature-bundle-v1-composition-writer-test)
        (only-in "../../integration/lab/funflow/funflow-public-module-test.ss" funflow-public-module-test)
        (only-in "../../integration/lab/dependencies/json-schema-contract-bridge-test.ss" json-schema-contract-bridge-test)
        (only-in "../../integration/lab/dependencies/json-schema-poo-contract-test.ss" json-schema-poo-contract-test)
        (only-in "../../integration/lab/funflow/funflow-github-ci-json-schema-contract-test.ss" funflow-github-ci-json-schema-contract-test))

;; Standard Suite exports; importing this facade does not execute tests.
(export control-plane-role-test
        feature-bundle-v1-composition-writer-test
        funflow-public-module-test
        json-schema-contract-bridge-test
        json-schema-poo-contract-test
        funflow-github-ci-json-schema-contract-test)
