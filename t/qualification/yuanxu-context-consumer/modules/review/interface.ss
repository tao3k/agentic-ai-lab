;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import "types.ss" "objects.ss")
(.def Review
  identity: 'review
  core:
  (.o scope-contract: ReviewScopeContract
      exports: (.o context: refine-context))
  features: (.o))
