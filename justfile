# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

# Show the maintained developer entrypoints.
[group('discovery')]
default:
    @just --list

# Recipes share the root environment and working directory.
import 'dev/just/build.just'
import 'dev/just/checks.just'
import 'dev/just/contributions.just'
import 'dev/just/dependencies.just'
import 'dev/just/environment.just'
import 'dev/just/proofs.just'
import 'dev/just/runtime-tests.just'
import 'dev/just/testing.just'
