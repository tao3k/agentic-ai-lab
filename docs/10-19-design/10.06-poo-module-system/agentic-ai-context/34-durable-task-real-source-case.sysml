// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
package DurableTaskSourceCase {
    private import ScalarValues::*;
    doc /* Existing DOC architecture applied to a real current source change.
           This model does not specify a test/fault-injection workflow. */
    part def RetainedRequest {
        attribute requestedOutcome : String = "Keep unresolved work safe through recovery";
        attribute taskIdentity : String;
        attribute specificationRevision : String;
    }
    part def ExistingDesign {
        attribute source : String = "14-runtime-durable-recovery.org; 18-runtime-durable-source-commands.org";
        doc /* Existing Context, Session and journal retain their responsibilities. */
    }
    part def SourceArtifact {
        attribute path : String = "modules/ai-agentic-context/durable-owner.ss";
        attribute observation : String = "Recovery code has changed";
        attribute acceptance : String = "Not established by file presence";
    }
    part def ContextRelations {
        attribute known : String = "The source change exists";
        attribute openQuestion : String = "Does the change preserve the declared design boundary?";
        doc /* Context retains exact revisions and uncertainty. ASCENT derives
               support, conflict and open obligations; it does not run a next step. */
    }
    part def ModelExploration {
        attribute possibleInquiry : String = "Inspect the diff or reconsider the design boundary";
        doc /* Other hypotheses and questions may be proposed. No mandatory order. */
    }
    part def TaskResponsibility {
        attribute judgment : String = "Task acceptance remains open";
        doc /* A proposed edit, a runtime decision and Task acceptance differ. */
    }
    part def SourceChangeCase {
        part request : RetainedRequest;
        part design : ExistingDesign;
        part patch : SourceArtifact;
        part context : ContextRelations;
        part model : ModelExploration;
        part responsibility : TaskResponsibility;
        connection requestDefinesQuestion connect request to context;
        connection designSuppliesBasis connect design to context;
        connection sourceSuppliesObservation connect patch to context;
        connection unknownInvitesInquiry connect context to model;
        connection contractKeepsResponsibility connect context to responsibility;
    }
    part fixture : SourceChangeCase;
}
