// A finite contract for source-bound scope reviews, not native correctness.
// Revisions and two values bound checking, never Agent exploration or CPUs.
module ModelApplicability {
  const Mutation: str
  type State = {
    mutation: int, model: int, proposal: int, assumptions: int,
    expected: int, proposed: int, modeled: bool,
    checked: int, reviewModel: int, reviewProposal: int,
    reviewAssumptions: int, reviewPresent: bool,
    read: bool, scopeCurrent: bool, gap: bool, frameworkChoice: int,
    agentChoice: int
  }
  var q: State
  pure def initial(mutation: int): State = {
    mutation: mutation, model: 0, proposal: 0, assumptions: 0,
    expected: 0, proposed: 0, modeled: true, checked: -1,
    reviewModel: -1, reviewProposal: -1, reviewAssumptions: -1,
    reviewPresent: false, read: false, scopeCurrent: false, gap: true,
    frameworkChoice: -1, agentChoice: -1
  }
  pure def configuredMutation =
    if (Mutation == "pass-shortcut") 1
    else if (Mutation == "ignore-proposal") 2
    else if (Mutation == "ignore-model") 3
    else if (Mutation == "ignore-assumptions") 4
    else if (Mutation == "missing-dimension") 5
    else if (Mutation == "force-next") 6
    else if (Mutation == "ignore-provenance") 7 else 0
  action init = q' = initial(configuredMutation)
  action initPassShortcut = q' = initial(1)
  action initIgnoreProposal = q' = initial(2)
  action initIgnoreModel = q' = initial(3)
  action initIgnoreAssumptions = q' = initial(4)
  action initMissingDimension = q' = initial(5)
  action initForceNext = q' = initial(6)
  action initIgnoreProvenance = q' = initial(7)
  action checkModel = q' = { ...q, checked: q.model, read: false }
  action reviewScope = q' = { ...q,
    reviewModel: q.model, reviewProposal: q.proposal,
    reviewAssumptions: q.assumptions, reviewPresent: true, read: false }
  action changeModel = all {
    q.model == 0, q' = { ...q, model: 1, read: false },
  }
  action changeProposal = {
    nondet value = Set(0, 1).oneOf()
    all { q.proposal == 0,
      q' = { ...q, proposal: 1, proposed: value, read: false } }
  }
  action changeAssumptions = {
    nondet value = Set(0, 1).oneOf()
    all { q.assumptions == 0,
      q' = { ...q, assumptions: 1, expected: value, read: false } }
  }
  action loseReviewSource = all {
    q.reviewPresent, q' = { ...q, reviewPresent: false, read: false },
  }
  action removeDimension = all {
    q.modeled, q' = { ...q, modeled: false, read: false },
  }
  pure def applicable(s: State): bool =
    s.modeled and s.expected == s.proposed and s.checked == s.model and
    s.reviewPresent and s.reviewModel == s.model and
    s.reviewProposal == s.proposal and s.reviewAssumptions == s.assumptions
  action readScope = {
    val declaredFit = q.modeled and q.expected == q.proposed and q.checked == q.model and
      (q.reviewPresent or q.mutation == 7) and
      (q.reviewModel == q.model or q.mutation == 3) and
      (q.reviewProposal == q.proposal or q.mutation == 2) and
      (q.reviewAssumptions == q.assumptions or q.mutation == 4)
    val reported = if (q.mutation == 1) q.checked == q.model
      else if (q.mutation == 5 and not(q.modeled)) true else declaredFit
    q' = { ...q, read: true, scopeCurrent: reported, gap: not(reported),
      frameworkChoice: if (q.mutation == 6) 0 else -1 }
  }
  // A novel choice remains enabled even while every scope review is missing.
  action propose = {
    nondet choice = Set(0, 1, 2).oneOf()
    q' = { ...q, agentChoice: choice }
  }
  action step = any { checkModel, reviewScope, changeModel, changeProposal,
    changeAssumptions, loseReviewSource, removeDimension, readScope, propose }
  val ExactScope = not(q.read) or q.scopeCurrent == applicable(q)
  val MissingVisible = not(q.read) or q.gap == not(applicable(q))
  val OpenExploration = q.frameworkChoice == -1
  val Safety = ExactScope and MissingVisible and OpenExploration
}
