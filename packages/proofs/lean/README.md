<!--
SPDX-FileCopyrightText: 2026 tao3k team and Contributors
SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
-->

# agentic-ai-lab Lean proof model

This Lean package models normalized user-interface configuration as typed proof
objects. It does not model Scheme evaluation.

```sh
lake build AgenticAILabProof
```

## Core dependency

The shared Module System proof sources moved to `../../../core/dev/proofs/lean`.
`YuanxuProof` is an explicit local Lake dependency, so product imports use
Core module paths while theorem names and proof statements retain their identities. Build the
Module System target in Core; product module and Scenario targets stay here.
Cedar and its native FFI still belong to this product package, not Core.
