;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in "postgresql/config.ss" PostgreSQLScope)
        (only-in "gitea/config.ss" GiteaScope)
        (only-in :clan/poo/object .get .o .cc)
        (only-in :tao3k/yuanxu/configuration/json config-defaults))
(export application-scope configured-application-scope)
(def (configured-application-scope defaults)
  (application-scope PostgreSQLScope GiteaScope defaults))
(def (application-scope database client defaults)
  (.o Scenario: ((.get client application)
                 (config-defaults (.get defaults postgresql) (.get database config))
                 (config-defaults (.get defaults gitea) (.get client config)))
      requirements: (.o postgresql: (.get database policy requirements database-port)
                       gitea: (.get client policy requirements database-port))
      types:
      (.o Application:
          (.cc (.get client types Application)
            database-contract: (.get database types Config)
            port-type: (.get database types port)
            documents: (.o postgresql: (.get database document) gitea: (.get client document))))))
