;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :tao3k/yuanxu/lang yuanxu!))
(yuanxu!
  :load-modules "../../../modules" mount: Lab mode: explicit :test-dir "./t"
  (nix)
  (funflow)
  :services (opentofu)
  :load-modules "../../../core/modules" mount: Core mode: explicit :test-dir "./t"
  (json-schema))
