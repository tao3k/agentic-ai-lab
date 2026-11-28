;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Inert presentation policy; it does not alter ASCENT relationship semantics.
(import (only-in :clan/poo/object .o))
(export D2Config)
(def D2Config (.o direction: 'right minimum-reader-text: 18))
