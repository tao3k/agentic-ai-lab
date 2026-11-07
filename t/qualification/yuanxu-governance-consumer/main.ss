;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in "./init.ss" yuanxu-governance-consumer.init.exports))
(export selected-governance)
(def (selected-governance)
  (.get yuanxu-governance-consumer.init.exports modules governance))
