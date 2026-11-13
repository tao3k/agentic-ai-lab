;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object "./objects.ss")
(export Config)
;; The maintained Profile supplies provider demand. A deployment injects
;; the OpenTofu scope carrying its configured Nix source.
(.def Config
  resource: (.o aws_instance: (.o web: WebProfile))
  opentofu: #f)
