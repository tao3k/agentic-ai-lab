;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in "../temporal-model-native/scenario" main-with-cases))
(export main)
(def (main . args)
  (apply main-with-cases (cons '("physical-gql-necessary") args)))
