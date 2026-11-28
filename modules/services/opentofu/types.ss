;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; This required role publishes the same public descriptors used by dependents.
;;; Definitions live once in the OpenTofu contracts library.
(import (only-in :tao3k/agentic-ai-lab/modules/nix/types)
        (only-in "./contracts.ss"
                 ProviderArtifactContract ProviderTypeIndexContract ProviderSelectionContract
                 ConfigurationEnvelopeContract NullContract OpenTofuContract ServicesContract
                 execution-admission CollectionAuthorityType CollectionReceiptType
                 OpenTofuConfigContract OpenTofuScopeContract
                 NixScopeContract JsonSchemaScopeContract FunflowScopeContract))
(export ProviderArtifactContract ProviderTypeIndexContract ProviderSelectionContract
                 ConfigurationEnvelopeContract NullContract OpenTofuContract ServicesContract
                 execution-admission CollectionAuthorityType CollectionReceiptType
                 OpenTofuConfigContract OpenTofuScopeContract
                 NixScopeContract JsonSchemaScopeContract FunflowScopeContract)
