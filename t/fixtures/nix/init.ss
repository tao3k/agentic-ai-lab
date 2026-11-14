;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(yuanxu!
  :load-modules "../../../modules" rename: Lab mode: explicit :test-dir "./t"
  (nix)
  :services (opentofu)
  :load-modules "../../../core/modules" rename: Core mode: explicit :test-dir "./t"
  (funflow)
  (json-schema))
