;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product-owned selection; Core prepares sources without runtime activation.
(import :core/module-system/selection/init-syntax)
(poo-flow! mode: auto source: "./modules")
