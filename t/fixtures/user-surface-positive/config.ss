;;; Inert positive fixture: the default surface only selects maintained values.
(def surface-positive
  (.new Scenario name: 'surface-positive
        config: (compose profiles MaintainedHealthcareProfile)))
