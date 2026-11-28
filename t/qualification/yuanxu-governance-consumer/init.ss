;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :tao3k/yuanxu/lang yuanxu!))
(yuanxu!
  :build-roots ("main")
  :test-dir "./t" source: "../../../modules" mode: auto profile: governance)
