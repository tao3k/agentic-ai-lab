;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(yuanxu!
  :build-roots ("main")
  :load-modules "../../../modules" mount: Lab mode: auto profile: deployment :test-dir "./t"
  :load-modules "../../../core/modules" mount: Core mode: auto profile: deployment :test-dir "./t")
