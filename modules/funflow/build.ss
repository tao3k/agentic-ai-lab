;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Public libraries of the Funflow Module.
(import (only-in :clan/poo/object .def .o))

(.def Build
  defbuild-script: (.o spec: '("func" "control-plane/api" "workload" "bundle-v1" "store" "durable-dag")))
