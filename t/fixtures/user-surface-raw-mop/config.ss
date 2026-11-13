;;; Inert negative fixture: meta imports belong to an owned extension module.
(import (only-in :tao3k/yuanxu/modules/funflow/scenario Scenario)
        (only-in :clan/poo/mop .new)
        (only-in :clan/poo/mop validate))
(def raw-mop
  (.new Scenario name: 'raw-mop
        config: (compose profiles MaintainedHealthcareProfile)))
