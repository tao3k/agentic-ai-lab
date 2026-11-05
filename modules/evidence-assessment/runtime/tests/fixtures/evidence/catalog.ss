;;; Python/C ABI loads these declarations; all expansion and inference belong to ASCENT.
(define-program (make-catalog)
  (sources dependency local_control_pass local_failure_model local_native_failure
    observed_failure observed_process observed_field observed_signal
    observed_control_reference observed_log_attachment observed_model_reference
    model model_context_pr model_contract model_paper model_progress_checked
    model_progress_obligation model_receipt native_adapter pr pr_model
    protocol_checked protocol_composes protocol_model protocol_obligation protocol_report
    report_kind report_snapshot reported_failure source_unit_observation window_disposition)
  (outputs needs_snapshot
    context_needs_report
    needs_model
    needs_native
    dependency_path
    shared_obligation
    triage_open
    reported_failure
    local_needs_model
    local_environment
    local_budget
    local_control_pass
    local_budget_uncontrolled
    local_signal
    model_paper
    contract_path
    paper_needs_native
    contract_needs_native
    model_receipt
    contract_needs_receipt
    source_unit_observation
    model_progress_obligation
    model_progress_checked
    progress_needs_check
    protocol_model
    protocol_checked
    protocol_needs_check
    protocol_obligation
    contract_open_obligation
    protocol_report
    protocol_report_needs_check
    local_failure_record
    observed_field
    observed_gap
    observed_unmatched
    observed_control_reference
    observed_model_reference
    observed_model_unregistered
    observed_log_attachment)
  (relation context_needs_report ((c0 symbol?) (c1 exact-integer?)))
  (relation contract_needs_native ((c0 symbol?) (c1 symbol?)))
  (relation contract_needs_receipt ((c0 symbol?) (c1 symbol?)))
  (relation contract_open_obligation ((c0 symbol?) (c1 symbol?) (c2 symbol?)))
  (relation contract_path ((c0 symbol?) (c1 symbol?)))
  (relation dependency ((c0 exact-integer?) (c1 exact-integer?)))
  (relation dependency_path ((c0 exact-integer?) (c1 exact-integer?)))
  (relation has_model ((c0 exact-integer?)))
  (relation has_model_receipt ((c0 symbol?)))
  (relation has_native ((c0 symbol?)))
  (relation has_snapshot ((c0 exact-integer?)))
  (relation known_pr ((c0 exact-integer?)))
  (relation local_budget ((c0 symbol?)))
  (relation local_budget_uncontrolled ((c0 symbol?)))
  (relation local_control_pass ((c0 symbol?) (c1 symbol?) (c2 symbol?) (c3 symbol?)))
  (relation local_environment ((c0 symbol?)))
  (relation local_failure_model ((c0 symbol?) (c1 symbol?)))
  (relation local_has_control ((c0 symbol?)))
  (relation local_has_model ((c0 symbol?)))
  (relation local_native_failure ((c0 symbol?) (c1 symbol?) (c2 symbol?) (c3 symbol?)))
  (relation local_failure_record ((c0 symbol?) (c1 symbol?) (c2 symbol?) (c3 symbol?)))
  (relation observed_failure ((c0 symbol?) (c1 symbol?) (c2 symbol?) (c3 symbol?) (c4 symbol?)))
  (relation observed_process ((c0 symbol?) (c1 exact-integer?) (c2 boolean?) (c3 boolean?)))
  (relation observed_field ((c0 symbol?) (c1 symbol?) (c2 symbol?) (c3 symbol?) (c4 symbol?)))
  (relation observed_signal ((c0 symbol?) (c1 exact-integer?)))
  (relation observed_control_reference ((c0 symbol?) (c1 symbol?) (c2 symbol?) (c3 symbol?)))
  (relation observed_log_attachment ((c0 symbol?) (c1 symbol?) (c2 symbol?) (c3 symbol?)))
  (relation observed_model_reference ((c0 symbol?) (c1 symbol?) (c2 symbol?)))
  (relation observed_model_registered ((c0 symbol?)))
  (relation observed_model_unregistered ((c0 symbol?) (c1 symbol?)))
  (relation observed_present ((c0 symbol?) (c1 symbol?)))
  (relation observed_required ((c0 symbol?) (c1 symbol?)))
  (relation observed_gap ((c0 symbol?) (c1 symbol?)))
  (relation observed_matched ((c0 symbol?)))
  (relation observed_unmatched ((c0 symbol?)))
  (relation local_needs_model ((c0 symbol?)))
  (relation local_signal ((c0 symbol?)))
  (relation model ((c0 symbol?) (c1 symbol?) (c2 symbol?)))
  (relation model_context_pr ((c0 symbol?) (c1 exact-integer?)))
  (relation model_contract ((c0 symbol?) (c1 symbol?) (c2 symbol?)))
  (relation model_paper ((c0 symbol?) (c1 symbol?) (c2 symbol?)))
  (relation model_progress_checked ((c0 symbol?) (c1 symbol?)))
  (relation model_progress_obligation ((c0 symbol?) (c1 symbol?) (c2 symbol?)))
  (relation model_receipt ((c0 symbol?) (c1 symbol?) (c2 symbol?)))
  (relation native_adapter ((c0 symbol?) (c1 symbol?)))
  (relation needs_model ((c0 exact-integer?)))
  (relation needs_native ((c0 symbol?)))
  (relation needs_snapshot ((c0 exact-integer?)))
  (relation paper_needs_native ((c0 symbol?)))
  (relation pr ((c0 exact-integer?) (c1 symbol?) (c2 symbol?)))
  (relation pr_model ((c0 exact-integer?) (c1 symbol?)))
  (relation progress_has_check ((c0 symbol?)))
  (relation progress_needs_check ((c0 symbol?)))
  (relation protocol_checked ((c0 symbol?) (c1 symbol?)))
  (relation protocol_composes ((c0 symbol?) (c1 symbol?)))
  (relation protocol_has_check ((c0 symbol?)))
  (relation protocol_model ((c0 symbol?) (c1 symbol?)))
  (relation protocol_needs_check ((c0 symbol?)))
  (relation protocol_obligation ((c0 symbol?) (c1 symbol?)))
  (relation protocol_report ((c0 symbol?) (c1 exact-integer?) (c2 symbol?) (c3 symbol?)))
  (relation protocol_report_needs_check ((c0 exact-integer?) (c1 symbol?)))
  (relation report_kind ((c0 exact-integer?) (c1 symbol?)))
  (relation report_snapshot ((c0 exact-integer?) (c1 symbol?) (c2 symbol?) (c3 exact-integer?)))
  (relation reported_failure ((c0 exact-integer?) (c1 symbol?) (c2 symbol?)))
  (relation shared_obligation ((c0 exact-integer?) (c1 exact-integer?) (c2 symbol?)))
  (relation source_unit_observation ((c0 symbol?) (c1 symbol?) (c2 symbol?) (c3 symbol?)))
  (relation triage_open ((c0 exact-integer?)))
  (relation window_disposition ((c0 exact-integer?) (c1 symbol?)))
  (include catalog-report-rules)
  (include catalog-observation-rules)
  (include catalog-protocol-rules))
