;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Source-derived Org Elements live behind the parser-owning Orgize package.
(import (only-in :orgize/languages/org/event-runtime parse-org-native-events)
        :orgize/languages/org/modules/org-elements/source-interface)
(export parse-org-native-events (import: :orgize/languages/org/modules/org-elements/source-interface))
