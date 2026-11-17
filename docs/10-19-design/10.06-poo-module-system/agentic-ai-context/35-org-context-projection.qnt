// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module OrgContextProjection {
  // One Task and one active evaluation, plus earlier issued receipts. The multi-file case selects a
  // derived finding and its pinned design anchor. Both have the same local ID.
  type Selection = {
    worktree: str, source: int, route: int, contract: int, grant: int,
    origin: int, originPin: int, moduleRevision: int, orgDeclaration: int,
    work: int, worktrunk: int
  }
  type Evaluation = { request: int, selection: Selection, members: Set[str], originSource: str, queryReady: bool }
  type State = {
    selected: Selection, resolved: bool, readable: bool, declarations: int,
    issued: int, pending: Evaluation, superseded: Set[Evaluation], publication: Evaluation,
    lastReceipt: Evaluation, publicationWasValid: bool, lateReceiptsIsolated: bool, control: str,
    moduleHead: int, offeredModule: int, declarationHead: int, declaredPin: int,
    aliasMatches: bool, root: str, workHead: int, worktrunkHead: int
  }

  pure val initialSelection = {
    worktree: "A", source: 1, route: 1, contract: 1, grant: 1, origin: 0, originPin: 0,
    moduleRevision: 0, orgDeclaration: 0, work: 0, worktrunk: 0
  }
  pure val empty = { request: 0, selection: initialSelection, members: Set(), originSource: "", queryReady: false }
  var state: State

  pure def initialState(control: str, origin: int, moduleHead: int, root: str): State =
    {
      selected: initialSelection.with("origin", origin).with("originPin", origin)
        .with("moduleRevision", moduleHead).with("orgDeclaration", moduleHead),
      resolved: moduleHead == 0, readable: true, declarations: 0,
      issued: 0, pending: empty, superseded: Set(), publication: empty,
      lastReceipt: empty, publicationWasValid: true, lateReceiptsIsolated: true, control: control,
      moduleHead: moduleHead, offeredModule: moduleHead, declarationHead: moduleHead, declaredPin: origin,
      aliasMatches: true, root: root, workHead: 0, worktrunkHead: 0
    }
  action initWith(control: str, origin: int, moduleHead: int, root: str): bool =
    state' = initialState(control, origin, moduleHead, root)
  action init = initWith("guarded", 0, 0, "findings")
  action initMulti = initWith("guarded", 1, 0, "findings")
  action initWorktree = initWith("guarded", 1, 1, "findings")
  action initWorktreeDesignOnly = initWith("guarded", 0, 1, "design")
  action initAny = any { init, initMulti, initWorktree, initWorktreeDesignOnly }
  action initIgnoreContract = initWith("ignore-contract", 0, 0, "findings")
  action initIgnoreWorktree = initWith("ignore-worktree", 0, 0, "findings")
  action initIgnoreGrantEpoch = initWith("ignore-grant-epoch", 0, 0, "findings")
  action initIgnoreOriginVersion = initWith("ignore-origin-version", 1, 0, "findings")
  action initIgnoreOriginSource = initWith("ignore-origin-source", 1, 0, "findings")
  action initAcceptPartial = initWith("accept-partial", 1, 0, "findings")
  action initIgnoreModuleRevision = initWith("ignore-module-revision", 1, 1, "findings")
  action initIgnoreOrgDeclaration = initWith("ignore-org-declaration", 1, 1, "findings")
  action initIgnoreAlias = initWith("ignore-alias", 1, 1, "findings")
  action initDependencies(control: str, trunk: int): bool = {
    val initial = initialState(control, 0, 1, "design")
    state' = initial.with("workHead", 1).with("worktrunkHead", 1)
      .with("selected", initial.selected.with("work", 1).with("worktrunk", trunk))
  }
  action initGitOpsDependencies = initDependencies("guarded", 1)
  action initUnselectedWorkTrunk = initDependencies("guarded", 0)
  action initIgnoreWorkVersion = initDependencies("ignore-work-version", 1)
  action initIgnoreWorkTrunkVersion = initDependencies("ignore-worktrunk-version", 1)
  action initPublishLate = initDependencies("publish-late", 1)
  action initClearNewOnLate = initDependencies("clear-new-on-late", 1)

  pure def moduleCurrent(s: State): bool =
    s.selected.moduleRevision == s.moduleHead and s.offeredModule == s.moduleHead
  pure def workCurrent(s: State): bool = s.selected.work == 0 or s.selected.work == s.workHead
  pure def worktrunkCurrent(s: State): bool =
    s.selected.worktrunk == 0 or s.selected.worktrunk == s.worktrunkHead
  pure def resolutionCurrentIn(s: State): bool =
    moduleCurrent(s) and s.selected.orgDeclaration == s.declarationHead and s.aliasMatches
      and workCurrent(s) and worktrunkCurrent(s)
  pure def resolutionGuardIn(s: State): bool =
    (moduleCurrent(s) or s.control == "ignore-module-revision")
      and (s.selected.orgDeclaration == s.declarationHead or s.control == "ignore-org-declaration")
      and (s.aliasMatches or s.control == "ignore-alias")
      and (workCurrent(s) or s.control == "ignore-work-version")
      and (worktrunkCurrent(s) or s.control == "ignore-worktrunk-version")
  val resolutionCurrent = resolutionCurrentIn(state)
  val resolutionGuard = resolutionGuardIn(state)

  def matchesLive(captured: Selection): bool = {
    val live = state.selected
    state.resolved and state.readable and resolutionGuard and
      captured.worktree == live.worktree and captured.source == live.source and
      captured.work == live.work and captured.worktrunk == live.worktrunk and
      captured.route == live.route and
      captured.originPin == live.originPin and
      ((captured.origin == live.origin and live.origin == live.originPin) or
        state.control == "ignore-origin-version") and
      (captured.contract == live.contract or state.control == "ignore-contract") and
      (captured.grant == live.grant or state.control == "ignore-grant-epoch")
  }
  def matchesReceipt(receipt: Evaluation): bool = {
    val pending = state.pending
    val selection = if (state.control == "ignore-worktree")
      receipt.selection.with("worktree", pending.selection.worktree) else receipt.selection
    pending.queryReady and receipt.queryReady and receipt.request == pending.request and selection == pending.selection and
      (receipt.members == pending.members or state.control == "accept-partial") and
      (receipt.originSource == pending.originSource or state.control == "ignore-origin-source")
  }

  val current = state.publication.request != 0 and matchesLive(state.publication.selection)
  val currentIsApplicable = not(current) or (
    state.readable and state.resolved and resolutionCurrent and state.selected.origin == state.selected.originPin and
    state.publication.selection == state.selected)
  val publicationWasBound = state.publicationWasValid
  val supersededReceiptsStayHistorical = state.lateReceiptsIsolated

  pure def canIssue(s: State): bool =
    s.resolved and s.readable and resolutionGuardIn(s) and
      (s.pending.request == 0 or s.pending.selection != s.selected) and
      s.selected.origin == s.selected.originPin
  val canStart = canIssue(state)
  action issue(queryReady: bool): bool =
    {
      val effective = if (canStart or state.moduleHead == 0) state
        else resolvedWorktree(state, state.aliasMatches)
      all {
        canIssue(effective),
        val request = effective.issued + 1
        val multi = effective.selected.origin != 0
        val hasFindings = effective.selected.work > 1 or effective.selected.worktrunk > 1
        val earlier = if (effective.pending.queryReady)
          effective.superseded.union(Set(effective.pending)) else effective.superseded
        state' = effective.with("issued", request).with("superseded", earlier).with("pending", {
          request: request, selection: effective.selected,
          members: if (hasFindings) Set("design", "findings")
            else if (multi) Set(effective.root, "design") else Set(effective.root),
          originSource: if (multi or hasFindings) "design" else "", queryReady: queryReady
        })
      }
    }
  action start = issue(true)
  action startWithoutQuery = issue(false)
  action receive(receipt: Evaluation): bool = all {
    receipt.request != 0,
    val active = matchesReceipt(receipt)
    val late = state.superseded.contains(receipt)
    val admit = (active and matchesLive(state.pending.selection)) or (late and state.control == "publish-late")
    val valid = active and receipt == state.pending and state.resolved and state.readable and resolutionCurrent and
      state.selected.origin == state.selected.originPin and
      state.pending.selection == state.selected
    val pending = if (active or (late and state.control == "clear-new-on-late")) empty else state.pending
    val publication = if (admit) receipt else state.publication
    state' = state.with("pending", pending).with("lastReceipt", receipt)
      .with("superseded", state.superseded.exclude(Set(receipt)))
      .with("publication", publication)
      .with("publicationWasValid", if (admit) valid else state.publicationWasValid)
      .with("lateReceiptsIsolated", state.lateReceiptsIsolated and
        (not(late) or (pending == state.pending and publication == state.publication)))
  }
  action completeSuperseded(request: int): bool =
    receive(state.superseded.fold(empty, (found, r) => if (r.request == request) r else found))
  action completeAnySuperseded = {
    nondet receipt = state.superseded.oneOf()
    receive(receipt)
  }
  action completeWrongSuperseded = {
    val receipt = state.superseded.fold(empty, (latest, r) => if (r.request > latest.request) r else latest)
    receive(receipt.with("members", Set("unrelated")))
  }
  action cancelSuperseded(request: int): bool = all {
    state.superseded.exists(r => r.request == request),
    state' = state.with("superseded", state.superseded.filter(r => r.request != request))
  }
  action complete = receive(state.pending)
  action completeFromSibling = receive(state.pending.with(
    "selection", state.pending.selection.with("worktree", "B")))
  action completePartial = all {
    state.pending.selection.origin != 0,
    receive(state.pending.with("members", Set("findings")))
  }
  action completeFromOtherOrigin = all {
    state.pending.selection.origin != 0,
    receive(state.pending.with("originSource", "other-design"))
  }
  // GQL returned no row for one of the required Org anchors.
  action abortMissingAnchor = all {
    state.pending.selection.origin != 0,
    state' = state.with("pending", empty)
  }
  action redeliver = all {
    state.lastReceipt.request != 0,
    // Replay after an evaluation has finished. A new request may be pending.
    state.lastReceipt.request != state.pending.request,
    receive(state.lastReceipt)
  }
  action addUnrelatedOrg = state' = state.with("declarations", state.declarations + 1)
  action changeSource = state' = state.with(
    "selected", state.selected.with("source", state.selected.source + 1))
  action changeOrigin = all {
    state.selected.origin != 0,
    state' = state.with("selected", state.selected.with("origin", state.selected.origin + 1))
  }
  action rebindOrigin = all {
    state.moduleHead == 0,
    state.selected.origin != state.selected.originPin,
    state' = state.with("selected", state.selected.with("originPin", state.selected.origin))
  }
  action advanceModule = all {
    state.moduleHead != 0,
    state' = state.with("moduleHead", state.moduleHead + 1)
  }
  action changeWork = all {
    state.workHead != 0,
    state' = state.with("workHead", state.workHead + 1)
  }
  action changeWorkTrunk = all {
    state.worktrunkHead != 0,
    state' = state.with("worktrunkHead", state.worktrunkHead + 1)
  }
  action offerModule = all {
    state.offeredModule != state.moduleHead,
    state' = state.with("offeredModule", state.moduleHead)
  }
  action offerDesignOnly = all {
    state.offeredModule != state.moduleHead,
    state' = state.with("offeredModule", state.moduleHead).with("root", "design").with("declaredPin", 0)
  }
  action editOrgDeclaration(pin: int): bool = all {
    state.moduleHead != 0,
    state' = state.with("declarationHead", state.declarationHead + 1).with("declaredPin", pin)
  }
  pure def resolvedWorktree(s: State, aliasMatches: bool): State = {
    val pin = s.declaredPin
    val available = s.offeredModule == s.moduleHead and
      (pin == 0 or pin == s.selected.origin) and (aliasMatches or s.control == "ignore-alias")
    val changed = not(resolutionCurrentIn(s)) or not(s.resolved) or not(available)
    val selected = s.selected.with("moduleRevision", s.moduleHead)
      .with("orgDeclaration", s.declarationHead).with("originPin", pin)
      .with("origin", if (pin == 0) 0 else s.selected.origin)
      .with("work", if (s.selected.work == 0) 0 else s.workHead)
      .with("worktrunk", if (s.selected.worktrunk == 0) 0 else s.worktrunkHead)
      .with("route", if (changed) s.selected.route + 1 else s.selected.route)
    s.with("aliasMatches", aliasMatches).with("resolved", available)
      .with("selected", if (available) selected else s.selected)
  }
  action resolveWorktree(aliasMatches: bool): bool = all {
    state.moduleHead != 0,
    state' = resolvedWorktree(state, aliasMatches)
  }
  action changeRouter(resolved: bool): bool = state' = state.with("resolved", resolved)
    .with("selected", state.selected.with("route", state.selected.route + 1))
  action changeContract = state' = state.with(
    "selected", state.selected.with("contract", state.selected.contract + 1))
  action changeGrant = state' = state.with("readable", not(state.readable))
    .with("selected", state.selected.with("grant", state.selected.grant + 1))
  action step = any {
    start, complete, completeFromSibling, completePartial, completeFromOtherOrigin, abortMissingAnchor,
    redeliver, addUnrelatedOrg, changeSource, changeOrigin, rebindOrigin,
    advanceModule, offerModule, offerDesignOnly, editOrgDeclaration(state.selected.origin), editOrgDeclaration(0),
    resolveWorktree(true), resolveWorktree(false),
    changeRouter(true), changeRouter(false), changeContract, changeGrant, state' = state
  }
  action stepGitOpsDependencies = any {
    start, complete, completeFromSibling, redeliver, addUnrelatedOrg, changeWork, changeWorkTrunk,
    changeGrant, resolveWorktree(true), state' = state
  }
  action stepSupersession = any {
    start, startWithoutQuery, complete, completeAnySuperseded,
    { nondet receipt = state.superseded.oneOf(); receive(receipt.with("members", Set("unrelated"))) },
    completeFromSibling, redeliver, changeWork, changeWorkTrunk, state' = state
  }

  run independentOrgTest = init.then(start).then(addUnrelatedOrg).then(complete)
    .expect(current and state.publication.request == 1)
    .then(addUnrelatedOrg).expect(current and state.publication.request == 1)
  run sourceEditTest = init.then(start).then(complete).then(start).then(changeSource)
    .expect(not(current) and state.publication.request == 1)
    .then(complete).expect(not(current) and state.lastReceipt.request == 2)
    .then(start).then(complete).expect(current and state.publication.request == 3)
  run routerConflictTest = init.then(start).then(changeRouter(false)).then(complete)
    .expect(not(current) and state.publication.request == 0 and state.lastReceipt.request == 1)
    .then(changeRouter(true)).then(start).then(complete)
    .expect(current and state.publication.selection.route == 3)
  run replacedContractTest = init.then(start).then(changeContract).then(complete)
    .expect(not(current) and state.publication.request == 0 and state.lastReceipt.request == 1)
  run siblingReceiptTest = init.then(start).then(complete).then(start).then(completeFromSibling)
    .expect(current and state.publication.request == 1 and state.lastReceipt.selection.worktree == "B"
      and state.pending.request == 2)
    .then(complete).expect(current and state.publication.request == 2)
  run revokedThenRestoredTest = init.then(start).then(complete).then(start)
    .then(changeGrant).expect(not(current)).then(changeGrant).expect(not(current))
    .then(complete).expect(not(current) and state.publication.request == 1)
    .then(start).then(redeliver).expect(state.pending.request == 3)
    .then(complete).expect(current and state.publication.request == 3)

  run ignoreContractCounterexampleTest = initIgnoreContract.then(start).then(changeContract)
    .then(complete).expect(not(currentIsApplicable) and not(publicationWasBound))
  run ignoreWorktreeCounterexampleTest = initIgnoreWorktree.then(start).then(completeFromSibling)
    .expect(not(publicationWasBound))
  run ignoreGrantEpochCounterexampleTest = initIgnoreGrantEpoch.then(start)
    .then(changeGrant).then(changeGrant).then(complete)
    .expect(not(currentIsApplicable) and not(publicationWasBound))

  run multiOrgCompletesTest = initMulti.then(start).then(complete).then(addUnrelatedOrg)
    .expect(current and state.publication.members == Set("findings", "design")
      and state.publication.originSource == "design")
  run multiOrgPartialReceiptTest = initMulti.then(start).then(completePartial)
    .expect(not(current) and state.pending.request == 1).then(complete).expect(current)
  run multiOrgOriginIdentityTest = initMulti.then(start).then(completeFromOtherOrigin)
    .expect(not(current) and state.pending.request == 1).then(complete).expect(current)
  run multiOrgOriginEditTest = initMulti.then(start).then(complete).then(start).then(changeOrigin)
    .expect(not(current)).then(complete).expect(not(current) and not(canStart))
    .then(rebindOrigin).then(start).then(complete)
    .expect(current and state.publication.request == 3 and state.publication.selection.originPin == 2)
  run multiOrgDerivedEditTest = initMulti.then(start).then(complete).then(start).then(changeSource)
    .expect(not(current)).then(complete).expect(not(current)).then(start).then(complete)
    .expect(current and state.publication.request == 3 and state.publication.selection.source == 2)
  run multiOrgGrantRevokedTest = initMulti.then(start).then(complete).then(start).then(changeGrant)
    .expect(not(current)).then(complete).expect(not(current) and not(canStart))
    .then(changeGrant).then(start).then(complete).expect(current and state.publication.request == 3)
  run multiOrgMissingAnchorTest = initMulti.then(start).then(abortMissingAnchor)
    .expect(not(current) and state.pending.request == 0 and state.lastReceipt.request == 0)

  run ignoreOriginVersionCounterexampleTest = initIgnoreOriginVersion.then(start)
    .then(changeOrigin).then(complete).expect(not(publicationWasBound) and not(currentIsApplicable))
  run ignoreOriginSourceCounterexampleTest = initIgnoreOriginSource.then(start)
    .then(completeFromOtherOrigin).expect(not(publicationWasBound))
  run acceptPartialOrgCounterexampleTest = initAcceptPartial.then(start)
    .then(completePartial).expect(not(publicationWasBound))

  run worktreeOrgResolutionTest = initWorktree.then(resolveWorktree(true)).then(start)
    .then(completePartial).expect(not(current)).then(complete).then(addUnrelatedOrg)
    .expect(current and state.publication.members == Set("findings", "design"))
  run worktreeTaskRootSelectionTest = initWorktreeDesignOnly.then(resolveWorktree(true))
    .then(start).then(complete).expect(current and state.publication.members == Set("design"))
  run worktreeOriginalRepinTest = initWorktree.then(resolveWorktree(true)).then(start).then(complete).then(start)
    .then(changeOrigin).expect(not(current)).then(complete).then(resolveWorktree(true))
    .expect(not(current) and not(canStart)).then(editOrgDeclaration(2))
    .then(start).then(complete).expect(current and state.publication.selection.originPin == 2)
  run worktreeModuleVersionTest = initWorktree.then(resolveWorktree(true)).then(start).then(complete).then(start)
    .then(advanceModule).expect(not(current)).then(complete).expect(not(canStart))
    .then(offerModule).expect(not(current)).then(start).then(redeliver).then(complete)
    .expect(current and state.publication.selection.moduleRevision == 2)
  run worktreeOriginDeclarationEditTest = initWorktree.then(resolveWorktree(true)).then(start).then(complete).then(start)
    .then(editOrgDeclaration(0)).expect(not(current)).then(complete).expect(not(canStart))
    .then(start).then(complete)
    .expect(current and state.publication.members == Set("findings"))
  run worktreeFeatureTaskRootRefreshTest = initWorktree.then(resolveWorktree(true)).then(start).then(complete)
    .then(advanceModule).then(offerDesignOnly).expect(not(current)).then(start).then(complete)
    .expect(current and state.publication.members == Set("design"))
  run worktreeOriginAliasSubstitutionTest = initWorktree.then(resolveWorktree(false))
    .expect(not(canStart) and not(current))
  run ignoreModuleRevisionCounterexampleTest = initIgnoreModuleRevision.then(resolveWorktree(true)).then(start)
    .then(advanceModule).then(complete).expect(not(publicationWasBound) and not(currentIsApplicable))
  run ignoreOrgDeclarationCounterexampleTest = initIgnoreOrgDeclaration.then(resolveWorktree(true)).then(start)
    .then(editOrgDeclaration(0)).then(complete).expect(not(publicationWasBound) and not(currentIsApplicable))
  run ignoreOriginAliasCounterexampleTest = initIgnoreAlias.then(resolveWorktree(false))
    .then(start).then(complete).expect(not(publicationWasBound) and not(currentIsApplicable))

  run workDependencyRefreshTest = initGitOpsDependencies.then(resolveWorktree(true))
    .then(start).then(complete).then(start).then(changeWork).expect(not(current))
    .then(complete).expect(not(current) and state.publication.selection.work == 1)
    .then(start).then(redeliver).then(complete)
    .expect(current and state.publication.selection.work == 2 and state.publication.selection.worktrunk == 1
      and state.publication.members == Set("design", "findings"))
  run worktrunkDependencyRefreshTest = initGitOpsDependencies.then(resolveWorktree(true))
    .then(start).then(complete).then(start).then(changeWorkTrunk).expect(not(current))
    .then(complete).expect(not(current) and state.publication.selection.worktrunk == 1)
    .then(start).then(redeliver).then(complete)
    .expect(current and state.publication.selection.work == 1 and state.publication.selection.worktrunk == 2
      and state.publication.members == Set("design", "findings"))
  run unselectedGitOpsDependencyTest = initUnselectedWorkTrunk.then(start).then(complete).then(changeWorkTrunk)
    .expect(current and state.publication.selection.worktrunk == 0
      and state.publication.members == Set("design"))
  run ignoreWorkVersionCounterexampleTest = initIgnoreWorkVersion.then(start)
    .then(changeWork).then(complete).expect(not(publicationWasBound) and not(currentIsApplicable))
  run ignoreWorkTrunkVersionCounterexampleTest = initIgnoreWorkTrunkVersion.then(start)
    .then(changeWorkTrunk).then(complete).expect(not(publicationWasBound) and not(currentIsApplicable))

  run workLateReceiptDuringReplacementTest = initGitOpsDependencies.then(start).then(complete)
    .then(start).then(changeWork).then(start).then(completeWrongSuperseded)
    .expect(state.pending.request == 3 and state.superseded.size() == 1)
    .then(completeSuperseded(2)).expect(not(current) and state.pending.request == 3 and state.superseded.size() == 0)
    .then(redeliver).then(complete).expect(current and state.publication.selection.work == 2)
  run worktrunkLateReceiptAfterReplacementTest = initGitOpsDependencies.then(start).then(complete)
    .then(start).then(changeWorkTrunk).then(start).then(complete)
    .then(completeSuperseded(2)).then(redeliver)
    .expect(current and state.publication.request == 3 and state.publication.selection.worktrunk == 2)
  run multipleSupersededReceiptsTest = init.then(start).then(changeContract).then(start)
    .then(changeContract).then(start).then(completeSuperseded(2)).then(complete)
    .then(completeSuperseded(1)).expect(current and state.publication.request == 3 and state.superseded.size() == 0)
  run supersededCancellationTest = init.then(start).then(changeContract).then(start)
    .then(cancelSuperseded(1)).then(complete)
    .expect(current and state.publication.request == 2 and state.superseded.size() == 0)
  run supersededUnevaluatedTest = init.then(startWithoutQuery).then(changeContract).then(start)
    .then(complete).expect(current and state.publication.request == 2 and state.superseded.size() == 0)
  run publishLateCounterexampleTest = initPublishLate.then(start).then(changeWork).then(start)
    .then(completeSuperseded(1)).expect(not(supersededReceiptsStayHistorical) and not(publicationWasBound))
  run clearNewOnLateCounterexampleTest = initClearNewOnLate.then(start).then(changeWorkTrunk).then(start)
    .then(completeSuperseded(1)).expect(not(supersededReceiptsStayHistorical) and state.pending.request == 0)
}
