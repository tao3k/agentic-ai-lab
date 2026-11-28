;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (only-in :tao3k/yuanxu/ops/process-script ProcessScript.)
        (only-in "control-plane/signatures.ss" Fun String validate)
        (only-in "types.ss" JobResultContract)
        (only-in "job.ss" job-graph run-job))
(export Task. Job.)

(.def (Task. @ ProcessScript.) needs: '() after-start: #f)
(.def (Job. job [])
  name: 'job
  tasks: (.o)
  selected: '()
  finalizers: '()
  graph: (job-graph job)
  .run: (validate (Fun JobResultContract <- String)
          (lambda (workspace) (run-job job workspace))))
