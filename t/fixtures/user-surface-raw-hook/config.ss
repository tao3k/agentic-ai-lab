;;; Inert negative fixture: raw self/super hooks belong to maintained behavior.
(def raw-hook
  (.new Scenario name: 'raw-hook
        config: (compose profiles
    (lambda (self super) (super self)))))
