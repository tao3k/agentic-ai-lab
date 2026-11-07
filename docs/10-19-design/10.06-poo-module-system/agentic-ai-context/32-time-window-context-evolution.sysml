// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

package AgenticAITimeWindowContext {
    private import ScalarValues::*;
    doc /* Semantic companion to 32-time-window-context-evolution.org.
           Relations describe an evolving information space, not execution order.
           The default model environment interprets the design, chooses visual
           expressions and inspects rendered views. No separate model service
           or fixed generate/review/rewrite workflow is specified here. */

    part def BeginnerPerspective {
        doc /* Questions proposed by the surrounding model for this design cut.
               Add, replace or challenge them as the context changes. These are
               example content, not an engine-wide question/prompt catalog. */
        attribute changedView : String =
            "What new evidence would change this view without erasing its history?";
        attribute retainedLimits : String =
            "What limits must travel with a method when we keep or reuse it?";
    }

    part def ExperienceWindows {
        doc /* Event interval and known-as-of cut are distinct. Windows can
               overlap, reopen or wait. Age does not establish truth. */
    }
    part def POOObjects {
        doc /* Stable identity, scope, source and immutable revision lineage.
               Object composition is not a rule that every picture is a box. */
    }
    part def ObjectRelationGraph {
        doc /* Observations, evidence, tasks and competing hypotheses coexist.
               New support never erases contrary evidence or earlier views. */
        doc /* The strings below are a teaching example, not a real build result
               or an admitted diagnosis. They let the picture show an actual
               contrast instead of asking the reader to imagine two versions. */
        attribute earlierObservation : String = "Rebuild passed";
        attribute laterObservation : String = "Control failed";
        attribute sharedHypothesis : String = "Old inputs?";
        attribute retainedEarlier : String = "Earlier support remains.";
    }
    part def ASCENTReasoning {
        doc /* Relate support, opposition, premises and affected conclusions.
               Also reason about the learner, explanation needs, questions,
               missing distinctions and actual view-bound critique. */
    }
    part def ModelExploration {
        doc /* The surrounding model environment can invent questions,
               hypotheses, tasks, visual metaphors and explanation candidates.
               Read the actual image; do not manufacture approval records. */
    }
    part def ScopedKnowledge {
        doc /* A new abstraction retains its method, scope, source, outcomes,
               counterexamples and defeat conditions. Retention and current
               applicability remain separate; no age-triggered promotion. */
        attribute proposedMethod : String = "Compare clean rebuild with a control.";
        attribute applicability : String = "Same source and tool versions.";
        attribute counterexample : String = "Control still fails after rebuild.";
        attribute recheckWhen : String = "Source or tool versions change.";
    }
    part def ActualOutcomes {
        doc /* Outcomes and source-qualified observations can contradict a
               model's explanation. Model confidence is not outcome evidence. */
    }

    part def ContextEvolution {
        doc /* One Context owns the information space. The diagram is a view
               of these relations, not another hand-maintained semantic graph. */
        part windows : ExperienceWindows;
        part objects : POOObjects;
        part graph : ObjectRelationGraph;
        part ascent : ASCENTReasoning;
        part model : ModelExploration;
        part knowledge : ScopedKnowledge;
        part outcomes : ActualOutcomes;

        connection selects connect windows to graph;
        connection composes connect objects to graph;
        connection facts connect graph to ascent;
        connection explains connect ascent to graph;
        connection situatedView connect graph to model;
        connection proposals connect model to graph;
        connection scopedAdmission connect graph to knowledge;
        connection reuseAndRecheck connect knowledge to graph;
        connection actualUse connect graph to outcomes;
        connection newEvidence connect outcomes to graph;
    }
}
