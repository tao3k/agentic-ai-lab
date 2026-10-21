// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
// Finite two-support premise plus one residual. Scheme proof validity is separate.
module SharedPremiseReuse {
  pure def bit(id: int, place: int): bool = (id / place) % 2 == 1
  pure def premise(id: int): bool =
    (bit(id,1) and bit(id,2)) or (bit(id,4) and bit(id,8))
  pure def downstream(id: int): bool = premise(id) and bit(id,16)
  pure def conformanceCase(id: int): List[int] =
    List(id, if (premise(id)) 1 else 0, if (downstream(id)) 1 else 0)
  pure val conformance = range(0,32).foldl(List(), (rows,id) => rows.append(conformanceCase(id)))
  type State = {id: int, generation: int, cachedId: int, cachedGeneration: int,
    admitted: bool, answer: bool}
  var q: State
  action init = {nondet id = 0.to(31).oneOf();
    q' = {id:id, generation:0, cachedId:-1, cachedGeneration:-1,
          admitted:false, answer:false}}
  action resolve = q' = {...q, cachedId:q.id, cachedGeneration:q.generation,
    admitted:true, answer:downstream(q.id)}
  action reuse = q' = {...q,
    admitted:q.cachedId == q.id and q.cachedGeneration == q.generation,
    answer:if (q.cachedId == q.id and q.cachedGeneration == q.generation)
      downstream(q.id) else false}
  action revise = {nondet id = 0.to(31).oneOf();
    q' = {...q, id:id, generation:q.generation+1, admitted:false, answer:false}}
  action step = any {resolve,reuse,revise}
  val Bound = q.admitted implies
    (q.cachedId == q.id and q.cachedGeneration == q.generation)
  val Correct = q.admitted implies q.answer == downstream(q.id)
}
