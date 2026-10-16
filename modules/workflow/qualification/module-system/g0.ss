;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: evaluates G0 requirements and observations into a qualification decision.
;;; Invariant: resolution records missing evidence and never treats absence as acceptance.
(import (only-in :clan/poo/object .ref object<-alist object?))

(export poo-flow-g0-requirement-prototype
        poo-flow-g0-observation-prototype
        poo-flow-g0-policy-prototype
        poo-flow-g0-decision-prototype
        poo-flow-g0-resolve
        poo-flow-g0-decision?)

(def poo-flow-g0-requirement-prototype
  (object<-alist '((kind . g0-requirement))))

(def poo-flow-g0-observation-prototype
  (object<-alist '((kind . g0-observation))))

(def poo-flow-g0-policy-prototype
  (object<-alist '((kind . g0-policy))))

(def poo-flow-g0-decision-prototype
  (object<-alist '((kind . g0-decision))))

;; : (-> PooFlowRequirementId Boolean Boolean PooFlowG0Decision)
(def (poo-flow-g0-resolve requirement-id observed? authorized?)
  (object<-alist
   `((kind . g0-decision)
     (requirement-id . ,requirement-id)
     (observed? . ,observed?)
     (authorized? . ,authorized?)
     (admitted? . ,(and observed? authorized?))
     (reason . ,(case (cond
                       ((not observed?) 'missing-observation)
                       ((not authorized?) 'policy-denied)
                       (else 'admitted))
                  ((missing-observation) 'missing-observation)
                  ((policy-denied) 'policy-denied)
                  (else 'admitted))))))

;; : (-> Object Boolean)
(def (poo-flow-g0-decision? value)
  (and (object? value)
       (with-catch
        (lambda (_failure) #f)
        (lambda ()
          (case (.ref value 'kind)
            ((g0-decision) #t)
            (else #f))))))
