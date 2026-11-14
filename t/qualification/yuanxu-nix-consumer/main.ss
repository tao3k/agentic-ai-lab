;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in "./init.ss" yuanxu-nix-consumer.init.exports))
(export selected-config)
;; The init declaration already determines the visible module namespace.
(def (selected-config) (.get yuanxu-nix-consumer.init.exports modules nix config))
