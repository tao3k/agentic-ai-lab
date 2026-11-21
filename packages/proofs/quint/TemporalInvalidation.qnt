// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
module TemporalInvalidation {

  const SCOPE_CHANGED: bool
  const BUG: bool
  val subjects = Set("prescription","deployment")
  val conclusions = Set("dose","alert","audit","release")
  val subjectEdges = Set(("prescription","dose"),("deployment","release"))
  val conclusionEdges = Set(("dose","alert"),("dose","audit"),("alert","audit"),("alert","dose"))
  val changed = Set("prescription")
  val direct = if (SCOPE_CHANGED) conclusions else conclusions.filter(c => changed.exists(s => subjectEdges.contains((s,c))))
  def grow(s) = s.union(conclusions.filter(c => s.exists(p => conclusionEdges.contains((p,c)))))
  val closure = 1.to(conclusions.size()).fold(direct, (s,_i) => grow(s))
  var scheduled: Set[str]
  val terminal = grow(scheduled) == scheduled
  action init = scheduled' = direct
  action advance = {
    nondet c = grow(scheduled).exclude(scheduled).oneOf()
    scheduled' = scheduled.union(Set(c))
  }
  action finish = all { terminal, scheduled' = scheduled }
  action corruptReprojection = all { BUG, SCOPE_CHANGED, scheduled' = Set("dose") }
  action step = any { advance, finish, corruptReprojection }
  val InputInvariant = changed.subseteq(subjects) and
    subjectEdges.forall(e => subjects.contains(e._1) and conclusions.contains(e._2)) and
    conclusionEdges.forall(e => conclusions.contains(e._1) and conclusions.contains(e._2))
  val ScheduledWithinClosure = scheduled.subseteq(closure)
  val DirectScheduled = direct.subseteq(scheduled)
  val ReprojectionScheduled = SCOPE_CHANGED implies scheduled == conclusions
  val TerminalComplete = terminal implies scheduled == closure
  val safety = and { InputInvariant, ScheduledWithinClosure, DirectScheduled, ReprojectionScheduled, TerminalComplete }
  temporal eventuallyComplete = advance.weakFair(scheduled) implies (scheduled == closure).eventually()

}
