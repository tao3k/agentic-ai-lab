;;; Scenario definitions loaded through Python/C ABI; no downstream imports or compile.
(def catalog-protocol-rules
  (ascent-fragment
    ((contract_path M D) <-- (model_contract M D O))
    ((contract_path M D) <-- (protocol_composes M D))
    ((contract_path M D) <-- (model_contract M X O) (contract_path X D))
    ((contract_path M D) <-- (protocol_composes M X) (contract_path X D))
    ((paper_needs_native M) <-- (model_paper M P S) (not (has_native M)))
    ((contract_needs_native M D) <-- (contract_path M D) (not (has_native D)))
    ((has_model_receipt M) <-- (model_receipt M H E))
    ((has_model_receipt M) <-- (protocol_checked M R))
    ((contract_needs_receipt M D) <-- (contract_path M D) (not (has_model_receipt D)))
    ((contract_open_obligation M D O) <-- (contract_path M D) (protocol_obligation D O))
    ((progress_has_check M) <-- (model_progress_checked M R))
    ((progress_needs_check M) <-- (model_progress_obligation M H S) (not (progress_has_check M)))
    ((protocol_has_check M) <-- (protocol_checked M R))
    ((protocol_needs_check M) <-- (protocol_model M H) (not (protocol_has_check M)))
    ((protocol_report_needs_check P M) <-- (protocol_report M P H S) (not (protocol_has_check M)))
  ))
