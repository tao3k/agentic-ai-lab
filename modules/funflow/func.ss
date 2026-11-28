;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Public functional API for Jobs and command projection.
(import (only-in "job.ss" job-graph job-flow run-job)
        (only-in "control-plane/runtime-command-descriptor.ss"
                 runtime-command-fields->manifest make-stdout-runtime-command-descriptor))
(export job-graph job-flow run-job
        runtime-command-fields->manifest make-stdout-runtime-command-descriptor)
