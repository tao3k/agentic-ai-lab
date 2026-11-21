#!/usr/bin/env gxi
;;; Proof fixture owner: emit the canonical proof vector and its integrity
;;; digest for the cross-language differential gate.

(import (only-in :std/encoding/hex hex-encode)
        "../../../../modules/proof/projections/generated/proof-case-vector-v1.ss"
        "../../../../modules/proof/projections/proof-case-vector.ss"
        "../../../../t/scenarios/proof-case-vector-test.ss")

(export main)

;;; Emission boundary: the canonical test case is projected once into a fresh
;;; byte vector, then both bytes and digest are written to standard output.
;; : (-> Unit Void)
(def (main)
  (let (vector (make-u8vector agentic-ai-lab-proof-case-vector-size 0))
    (agentic-ai-lab-proof-case-vector-write! canonical-proof-case vector)
    (display "vector=")
    (display (hex-encode vector))
    (newline)
    (display "digest=")
    (display (agentic-ai-lab-proof-case-vector-digest vector))
    (newline)))
