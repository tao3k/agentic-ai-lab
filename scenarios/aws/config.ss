;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object "./objects.ss")
(export Config)
;; One maintained Profile is also the build demand; no duplicated provider list
;; or package directory. OpenTofu's existing configuration-build reads its keys.
(.def Config resource: (.o aws_instance: (.o web: WebProfile)))
