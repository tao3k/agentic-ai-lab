;;; Scenario definitions loaded through Python/C ABI; no downstream imports or compile.
(def review-receipt-rules
  (ascent-fragment
    ((PassedId R) <-- (Passed R P))
    ((Bound R) <-- (ReceiptInput R K V))
    ((ReceiptPath R D) <-- (ReceiptDepends R D))
    ((ReceiptPath R D) <-- (ReceiptPath R X) (ReceiptDepends X D))
    ((Unusable R (lit 'unbound-inputs)) <-- (PassedId R) (not (Bound R)))
    ((Unusable R (lit 'stale-or-missing-input)) <-- (ReceiptInput R K V) (not (CurrentInput K V)))
    ((Unusable R (lit 'missing-dependency)) <-- (ReceiptPath R D) (not (PassedId D)))
    ((Unusable R (lit 'circular-justification)) <-- (ReceiptPath R R))
    ((Unusable R (lit 'invalid-dependency)) <-- (ReceiptPath R D) (Unusable D Reason))
    ((Bad R) <-- (Unusable R Reason))
    ((Reusable R P) <-- (Passed R P) (not (Bad R)))
    ((Established P R) <-- (Reusable R P))
    ((Claim P) <-- (Established P R))
  ))
