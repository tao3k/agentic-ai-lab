;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import "objects.ss" "types.ss"
        (only-in :std/source this-source-file)
        (only-in :tao3k/yuanxu/configuration/json config-json-file config-defaults))
(export Document Config GiteaScope)
(def Document
  (config-json-file (path-expand "gitea.json" (path-directory (this-source-file)))))
(def Config
  (config-defaults (.o database: (.o) allowed-ports: '(5432)) (.get Document value)))

(def GiteaScope
  (.o config: Config document: Document application: gitea-application
      policy: (gitea-policy Config Document)
      types: (.o Application: ApplicationContract Config: GiteaConfigContract)))
