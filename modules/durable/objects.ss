;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o))
(export DurableRecoveryPolicy.)
(def DurableRecoveryPolicy.
  (.o revision: #f
      outcome-interpreter: (lambda (input) 'unknown)
      retry-policy: (lambda (input outcome) #f)))
