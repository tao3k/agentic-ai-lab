;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Public docker module interface; all internal roles close through this file.

(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "funs.ss" "config.ss")
(export Docker
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss"))

(.def Docker
  identity: 'docker
  tags: '(docker container)
  core: (.o scope-contract: DockerScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/docker/interface))
  features: (.o))
