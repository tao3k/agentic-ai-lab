// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

package ContextGovernanceFigures {
    private import Views::*;
    private import StandardViewDefinitions::*;

    view verificationDispatch : InterconnectionView {
        expose ContextGovernanceBoundary::GovernedContextSystem;
    }

    view declassification : InterconnectionView {
        expose MultiRepoAgentDeclassification::MultiRepoCollaborativeSystem;
    }

    view securityBranches : InterconnectionView {
        expose AscentSecurityBranchOmissionRefinement::GovernedSecurityInvestigation;
    }

    view causalSurvival : InterconnectionView {
        expose TemporalCausalSurvivalMemoryQuotient::CausalSurvivalMemorySystem;
    }

    view hybridSearch : InterconnectionView {
        expose OrgSexprGqlCandidateExchange::HybridSearchAndExchangeSystem;
    }

    view sandboxAxes : InterconnectionView {
        expose DurableAgendaSessionSandboxGovernance::GovernedRuntimeControlAxes;
    }

    view endToEndPipeline : InterconnectionView {
        expose EndToEndContextGovernanceClosure::EndToEndGovernedAgenticPipeline;
    }

    view progressiveDisclosure : InterconnectionView {
        expose ProgressiveDisclosureAndOrgRepair::ProgressiveDisclosureGovernanceSystem;
    }
}
