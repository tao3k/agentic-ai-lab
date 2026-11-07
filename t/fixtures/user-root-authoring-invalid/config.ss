;;; Inert negative fixture: root UI may select maintained values, but it must
;;; not reopen the maintainer-owned POO object layer.
(def invalid-root
  (.new Scenario name: 'invalid-root
        config: (compose profiles
    (.def HiddenAdvancedProfile
      (stages (.o production: 'hidden))))))
