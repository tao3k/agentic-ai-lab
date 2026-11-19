;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o)
        (only-in "./types.ss" CAbiScopeContract)
        (only-in "./objects.ss" CAbiScope))
(export CAbi)

(.def CAbi
  identity: 'clock
  core: (.o scope-contract: CAbiScopeContract exports: CAbiScope))
