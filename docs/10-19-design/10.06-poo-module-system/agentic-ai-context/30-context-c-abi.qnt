// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// C ownership/control handoff composed with the existing native authority model.
module ContextCAbi {
  const BUG: str
  const TRACK_OP: bool
  import ContextRuntime(BUG=if (BUG=="terminal") "terminal" else "none") as auth from "./26-context-runtime"
  type Boundary = {bound: bool, work: int, buffer: bool, closed: bool, badControl: bool}
  var c: Boundary
  var op: int
  action init = all {auth::init, c'={bound:false, work:0, buffer:false, closed:false, badControl:false}, op'=0}
  action mark(n:int):bool = op'=if (TRACK_OP) n else 0
  action keep = auth::s'=auth::s
  action attach = all {mark(1), c'=if (not(c.closed)) c.with("bound",true) else c, keep}
  action enter = all {mark(2), c'=if (c.bound and not(c.closed) and c.work==0) c.with("work",1) else c, keep}
  action finish = all {mark(3), c.work==1, not(c.closed), auth::publishResult(auth::old), c'=c.with("work",2).with("buffer",true)}
  action retry = all {mark(4), c.work==2, not(c.closed), auth::publishResult(auth::old), c'=c.with("buffer",true)}
  action toolControl = all {mark(5), c'=c.with("badControl",c.badControl or BUG=="control"), keep}
  action close = all {mark(6), c'=if (c.work!=1 or BUG=="close") c.with("closed",true).with("bound",false) else c, keep}
  action release = all {mark(7), c'=c.with("buffer",false), keep}
  action revoke = all {mark(8), auth::revoke, c'=c}
  action cancel = all {mark(9), auth::cancel, c'=c}
  action recover = all {mark(10), auth::recover, c'=c}
  action takeover = all {mark(11), auth::takeover, c'=c}
  action replacePolicy = all {mark(12), auth::replacePolicy, c'=c}
  action expire = all {mark(13), auth::expireOldTicket, c'=c}
  action deliver = all {mark(14), auth::deliver, c'=c}
  action acknowledge = all {mark(15), auth::acknowledge, c'=c}
  action idle = all {mark(16), keep, c'=c}
  action step = any {attach, enter, finish, retry, toolControl, close, release, revoke,
                     cancel, recover, takeover, replacePolicy, expire, deliver, acknowledge, idle}
  val safety = auth::safety and not(c.badControl) and (not(c.closed) or c.work!=1)
}
