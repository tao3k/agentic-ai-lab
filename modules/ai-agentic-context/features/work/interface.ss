;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import "objects.ss" (only-in :clan/poo/object .def))
(export Feature)

(.def Feature
  requires: '(gitops/work ai-agentic-context/worktree)
  refine: EnableContextWork)
