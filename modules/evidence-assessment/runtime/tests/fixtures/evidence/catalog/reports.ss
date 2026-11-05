;;; Scenario definitions loaded through Python/C ABI; no downstream imports or compile.
(def catalog-report-rules
  (ascent-fragment
    ((has_model P) <-- (pr_model P M))
    ((has_model P) <-- (protocol_report M P H S))
    ((known_pr P) <-- (pr P H S))
    ((context_needs_report M P) <-- (model_context_pr M P) (not (known_pr P)))
    ((needs_model P) <-- (pr P H S) (report_kind P (lit 'runtime-repair)) (not (has_model P)))
    ((has_snapshot P) <-- (report_snapshot P H D N))
    ((needs_snapshot P) <-- (pr P H S) (not (has_snapshot P)))
    ((has_native M) <-- (native_adapter M F))
    ((needs_native M) <-- (model M H K) (not (has_native M)))
    ((dependency_path P D) <-- (dependency P D))
    ((dependency_path P D) <-- (dependency P X) (dependency_path X D))
    ((shared_obligation P D M) <-- (pr_model P M) (pr_model D M) (if (P D) (< P D)))
    ((triage_open P) <-- (window_disposition P (lit 'adjacent-source-overlap-review-open)))
  ))
