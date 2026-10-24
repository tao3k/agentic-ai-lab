;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(family-proof-archive-just-qualification
  (source-base "81ddae1af74683918b83b5d4968bf46e53a7c948")
  (native-recipe test-temporal-family-native)
  (rust-recipe test-temporal-family-archive)
  (native-cases 13) (rust-parent-tests 1) (rust-child-tests 1)
  (native-exit-status 0) (rust-exit-status 0)
  (idle-seconds 5) (wall-seconds 45)
  (native-heap pre-import-project-option)
  (native-wall-seconds 14.96) (rust-wall-seconds 9.79)
  (archive-and-replay-bytes unchanged-from-build-freeze)
  (benchmark-claim? #f)
  (initial-recipe-exit-status 1) (initial-recipe-failure missing-rg-in-isolated-path)
  (inputs
    ("justfile" "9093e398483ea7567b496c9e09cd98d0dbd2d3920d2121b6d09c8950fb5be56a")
    ("REUSE.toml" "e73c74656bcb570a05043380ea604718a50db00122ff34d2a9c8bb6a16f4521d")
    ("t/qualification/temporal-family-proof-archive/README.org" "669de5c4a3e5b765fad6d05bf6296bad2956a39e435ba3e0eb46b34701c73be1")
    ("/private/tmp/poo-archive-just-native.log" "6ebd8e25cff34c225477af10543e8e2d95d11580e8d4e70537ed3564ee5bd08c")
    ("/private/tmp/poo-archive-just-rust.log" "8b571edb9cbe71815b6dc10781cccfaad1a399db567960e9e65a13fd2c53f118")
    ("/private/tmp/poo-archive-just-native-path-failed.log" "c60695813e772783eb5a04041d49dfd84ac3b171bd4c408d6825272b898b39e7")
  ))
