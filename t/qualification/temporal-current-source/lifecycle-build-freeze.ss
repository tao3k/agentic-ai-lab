;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(family-lifecycle-native-qualification
  (idle-seconds 5) (wall-seconds 45) (cases 11) (exit-status 0)
  (compiler-route official-gxc-then-compile-exe)
  (sdk-overlay temporary-unchanged-upstream-outputs)
  (runner upstream-gxtest) (test-policy yuanxu-test-case)
  (source-authenticated? #f) (runtime-executed? #f) (action-authorized? #f)
  (frontier-completeness caller-premise) (retraction-scope same-family-query)
  (prior-discovery-failures 4) (prior-exit-status 124)
  (inputs
    ("executable" "eda167c2435d9769f73480fc9c72c92e3e8245e697fa28c3879b1a901bc8d6a7")
    ("entry-static" "b001a50e3b2d279b4c86a29665ac8ad7e27bb3e9ab0d9abf86c453d25b5c5780")
    ("modules/temporal-causality/lifecycle/types.ss" "2a5260ebf0963a53e0e2c23226733ab33ae2b7e9fbc2da0e2dbfe9c27768bb20")
    ("modules/temporal-causality/lifecycle/objects.ss" "1f6806fdb03707e7d26a2e6fc7ff66143ca44814cf65db22e67a2f1096eb6a64")
    ("modules/temporal-causality/lifecycle/funs.ss" "dd68e8bd5e5c05a0adc26f0983c4b9bb8b5c842a4b752e0ef26050577ae33cc3")
    ("modules/temporal-causality/lifecycle/interface.ss" "5b612bd3ab51f19108adfe1afeb9d4a8917067341ba23d04a662126d20098afe")
    ("modules/temporal-causality/interface.ss" "6cb578ce032ff5aea452154c8d62bd9922afbbcf7f39c09a694a57217e59e8dd")
    ("t/temporal-lifecycle-test.ss" "6d42294478e9bb521dc29be7da4c3baaab4f620ee1bcba952a80ff2cb111fd91")
    ("t/temporal-applicability-test.ss" "6b0068754bbfaee77fc3100ffbc7b9146813d8b77da4b0a77221eac827572db9")
    ("t/qualification/temporal-current-source/native-test.ss" "da0704f79f761ea2b1f59150177279dbc3332c27a546b07eef982730820f6b2f")
    ("bindings/rust-runtime/tools/watch.py" "bef8e506ed4834d48420e3e908da5f389d3462a50f7f8a4f20aa13360e2e4098")
    ("t/qualification/temporal-current-source/lifecycle-native-passed.log" "ce3001614e15e0ddde4a66ed592c73f54e320c43082a08e84986597bd165d002")
  ))
