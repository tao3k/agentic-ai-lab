;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o))

;; Gerbil follows the Context contracts' imports to the Lab temporal types.
;; The Worktree consumer also imports the query and authority libraries as
;; ordinary compiled modules.
(.def Build
  defbuild-script: (.o spec: '("types" "query-provider" "governance-host" "use-host")))
