;;; Inert negative fixture: direct CLOS declarations are not root configuration.
(def UserGeneric
  (poo-clos-generic-function 'user-generic 1))
(def direct-clos
  (.new Scenario name: 'direct-clos
        config: (compose profiles MaintainedHealthcareProfile)))
