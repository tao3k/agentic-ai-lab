"""Generated from proof-case-vector-v1.toml. Do not edit."""

ABI_VERSION = 1
VECTOR_SIZE = 424
VECTOR_ALIGNMENT = 8
SCHEMA_FINGERPRINT_HEX = "1627b834b99c2b23e4ee0019d38c672dfb86d6bfc44d55afaf18ad501160853a"
REQUIRED_OBLIGATION_MASK = 0x00000000000000ff
PROOF_DIGEST_ALGORITHM = "sha256"
VECTOR_DIGEST_DOMAIN = "agentic-ai-lab.proof-case-vector.v1"
THEOREM_SET_DIGEST_DOMAIN = "agentic-ai-lab.authorized-effect-theorem-set.v1"
AUTHORIZED_EFFECT_THEOREM_NAMES = (
    "policy_revision_bound",
    "effect_digest_bound",
    "semantic_root_bound",
    "execution_root_bound",
    "obligation_set_complete",
    "nonce_epoch_fresh",
    "diagnostic_non_executable",
    "l3_chain_complete",
)

FIELD_OFFSETS = {
    "abi_version": 0,
    "case_kind": 4,
    "schema_fingerprint": 8,
    "token_digest": 40,
    "policy_revision": 72,
    "effect_digest": 104,
    "semantic_root": 136,
    "execution_root": 168,
    "batch_root": 200,
    "subject_binding": 232,
    "resource_binding": 264,
    "action_binding": 296,
    "previous_evidence_root": 328,
    "nonce": 360,
    "epoch": 368,
    "sequence": 376,
    "required_obligation_mask": 384,
    "present_obligation_mask": 392,
    "obligation_count": 400,
    "mediation_outcome": 404,
    "durability_profile": 408,
    "reserved": 412,
}

CASE_KINDS = {
    "authorized_effect_token": 1,
}

MEDIATION_OUTCOMES = {
    "allow": 1,
    "deny": 2,
    "invalid_token": 3,
}

DURABILITY_PROFILES = {
    "strict": 1,
    "batched": 2,
    "diagnostic": 3,
}

OBLIGATION_BITS = {
    "policy_revision_bound": 0,
    "effect_digest_bound": 1,
    "semantic_root_bound": 2,
    "execution_root_bound": 3,
    "obligation_set_complete": 4,
    "nonce_epoch_fresh": 5,
    "diagnostic_non_executable": 6,
    "l3_chain_complete": 7,
}
