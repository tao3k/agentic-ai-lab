;;; -*- Gerbil -*-
;;; Boundary: user-authored Scheme FunFlow module loaded from Python.

(def python-runtime-ci
  (.new Scenario name: 'python-runtime-ci
        config: (compose profiles
    (use-module FunflowProfileModule as ff github-ci python-anyio)
    PythonRuntimeCIScenarioProfile)))

python-runtime-ci
