;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Negative process fixture: native child diagnostics belong to its Ops receipt.
(import (only-in :clan/poo/object .cc)
        (only-in :asp-gerbil-scheme/testing-api
                 +asp-testing-interface+ testing-interface-run-test-batch!)
        (only-in :poo-flow/dev/testing-api
                 poo-flow-testing-observability-extension
                 make-poo-flow-testing-observability-profile))
(def (main missing-file)
  (testing-interface-run-test-batch!
    (poo-flow-testing-observability-extension
      +asp-testing-interface+
      (.cc (make-poo-flow-testing-observability-profile 'testing/missing-batch 1)
           'trace-enabled? #t))
    (list missing-file)))
