;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in "./init.ss" yuanxu-deployment-consumer.init.exports))
(export selected-deployment)
(def (selected-deployment)
  (.get yuanxu-deployment-consumer.init.exports Lab services opentofu))
