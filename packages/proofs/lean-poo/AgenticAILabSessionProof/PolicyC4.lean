import LeanPoo.C4.VerifiedOrder

namespace AgenticAILabSessionProof.PolicyC4

/-- A Session carries a policy order only after Agentic AI Lab supplies an explicit
finite policy graph, root, and LeanPoo C4 certificate. Project/WorkTree/Task/
Session containment and Org heading depth are separate inputs and do not
construct this value. -/
structure SessionPolicyOrder where
  graph : LeanPoo.C4.Graph
  root : String
  verified : LeanPoo.C4.VerifiedOrder graph root

theorem root_is_first (policy : SessionPolicyOrder) :
    policy.verified.output.head? = some policy.root :=
  policy.verified.head

theorem order_is_finite (policy : SessionPolicyOrder) :
    policy.verified.output.length ≤ policy.graph.nodes.length :=
  policy.verified.length_bound

theorem order_has_no_duplicates (policy : SessionPolicyOrder) :
    policy.verified.output.Nodup :=
  policy.verified.nodup

theorem member_requires_graph_ancestry (policy : SessionPolicyOrder)
    (member : name ∈ policy.verified.output) :
    LeanPoo.C4.Ancestor policy.graph name policy.root :=
  policy.verified.covers.mp member

end AgenticAILabSessionProof.PolicyC4
