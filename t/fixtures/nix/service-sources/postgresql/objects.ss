;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .get .o .def)
        (only-in :tao3k/yuanxu/configuration/json config-field-origin))
(export PostgreSQL.)
(.def (PostgreSQL. @ [] config document)
  policy: (.o requirements: (.o database-port: (.o allowed-ports: (.get config allowed-ports)
              origin: (config-field-origin document '(allowed-ports) (.get config allowed-ports))))))
