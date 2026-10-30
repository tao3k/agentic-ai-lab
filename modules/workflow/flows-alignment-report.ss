;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Funflow tutorial alignment report projections.
;;; Invariant: report rows summarize proof metadata and runtime gaps without execution.

(import (only-in :clan/poo/object .o .ref object<-alist)
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :std/list/list append-map)
        :agentic-ai-lab/modules/workflow/flows-alignment-specs)

(export agentic-ai-lab-funflow-tutorial-alignment-report)

;;; Boundary: alignment status count increment is the policy-visible edge for
;;; workflow behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol Alist Alist)
(def (alignment-status-count-increment status counts)
  (cond
   ((null? counts) (list (cons status 1)))
   ((eq? status (caar counts))
    (cons (cons status (+ 1 (cdar counts))) (cdr counts)))
   (else
    (cons (car counts)
          (alignment-status-count-increment status (cdr counts))))))

;;; Boundary: status counts are report metadata only; they summarize coverage
;;; states without changing runtime ownership or proof semantics.
;; : (-> [PooObject] Alist Alist)
(def (alignment-status-counts/loop specs counts)
  (if (null? specs)
    counts
    (alignment-status-counts/loop
     (cdr specs)
     (alignment-status-count-increment
      (agentic-ai-lab-funflow-tutorial-alignment-spec-status (car specs))
      counts))))

;; : (-> [PooObject] Alist)
(def (alignment-status-counts specs)
  (alignment-status-counts/loop specs '()))

;;; Boundary: alignment status count ref is the policy-visible edge for
;;; workflow behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Symbol Alist Integer)
(def (alignment-status-count-ref status counts)
  (let (entry (assoc status counts))
    (if entry (cdr entry) 0)))

;;; Boundary: map preserves source row order so report output stays diff-stable.
;; : (-> [PooObject] [Symbol] [Symbol])
(def (alignment-spec-ids/rev specs ids-rev)
  (if (null? specs)
    ids-rev
    (alignment-spec-ids/rev
     (cdr specs)
     (cons (agentic-ai-lab-funflow-tutorial-alignment-spec-id (car specs))
           ids-rev))))

;; : (-> [PooObject] [Symbol])
(def (alignment-spec-ids specs)
  (reverse (alignment-spec-ids/rev specs '())))

;;; Boundary: deferred ids keep runtime-owned gaps visible in diagnostics.
;;; Empty deferred slots stay out of the public report projection.
;; : (-> [PooObject] [Symbol] [Symbol])
(def (alignment-deferred-ids/rev specs ids-rev)
  (cond
   ((null? specs) ids-rev)
   ((null? (.ref (car specs) 'deferred))
    (alignment-deferred-ids/rev (cdr specs) ids-rev))
   (else
    (alignment-deferred-ids/rev
     (cdr specs)
     (cons (agentic-ai-lab-funflow-tutorial-alignment-spec-id (car specs))
           ids-rev)))))

;; : (-> [PooObject] [Symbol])
(def (alignment-deferred-ids specs)
  (reverse (alignment-deferred-ids/rev specs '())))

;;; Boundary: proof counts are observability summaries, not success predicates.
;;; The helper counts attached proof strings without interpreting their content.
;; : (-> [PooObject] Integer Integer)
(def (alignment-proof-count/loop specs count)
  (if (null? specs)
    count
    (alignment-proof-count/loop
     (cdr specs)
     (+ count (length (.ref (car specs) 'proofs))))))

;; : (-> [PooObject] Integer)
(def (alignment-proof-count specs)
  (alignment-proof-count/loop specs 0))

;;; Boundary: gate proof count summarizes local verification coverage only.
;;; It does not replace executing the tests listed in the proof catalog.
;; : (-> [AgenticAILabAlignmentGateProof] Integer Integer)
(def (alignment-gate-proof-count/loop gate-proofs count)
  (if (null? gate-proofs)
    count
    (alignment-gate-proof-count/loop
     (cdr gate-proofs)
     (+ count
        (length (alignment-gate-proof-commands (car gate-proofs)))))))

;; : (-> [AgenticAILabAlignmentGateProof] Integer)
(def (alignment-gate-proof-count gate-proofs)
  (alignment-gate-proof-count/loop gate-proofs 0))

;; : (-> PooObject Alist)
(def (alignment-spec-snapshot spec)
  (list (cons 'id (.ref spec 'id))
        (cons 'source (.ref spec 'source))
        (cons 'observable (.ref spec 'observable))
        (cons 'status (.ref spec 'status))
        (cons 'coverage (.ref spec 'coverage))
        (cons 'proofs (.ref spec 'proofs))
        (cons 'runtime-owned (.ref spec 'runtime-owned))
        (cons 'deferred (.ref spec 'deferred))))

;;; Boundary: source entries are optimized for upstream-to-local lookup.
;;; They deliberately omit proof strings so the index stays compact.
;; : (-> PooObject Alist)
(def (alignment-source-index-entry spec)
  (list (cons 'source (.ref spec 'source))
        (cons 'id (.ref spec 'id))
        (cons 'status (.ref spec 'status))
        (cons 'coverage (.ref spec 'coverage))))

;;; Boundary: source index preserves tutorial source order from the spec table.
;;; This is the fast path for checking which upstream file a report row covers.
;; : (-> [PooObject] [Alist] [Alist])
(def (alignment-source-index/rev specs rows-rev)
  (if (null? specs)
    rows-rev
    (alignment-source-index/rev
     (cdr specs)
     (cons (alignment-source-index-entry (car specs)) rows-rev))))

;; : (-> [PooObject] [Alist])
(def (alignment-source-index specs)
  (reverse (alignment-source-index/rev specs '())))

;;; Boundary: proof entries are detailed audit rows keyed by upstream source.
;;; They keep command receipts inert while linking proof coverage to runtime gaps.
;; : (-> PooObject Alist)
(def (alignment-source-proof-entry spec)
  (let (proofs (.ref spec 'proofs))
    (list (cons 'source (.ref spec 'source))
          (cons 'id (.ref spec 'id))
          (cons 'status (.ref spec 'status))
          (cons 'proof-count (length proofs))
          (cons 'proofs proofs)
          (cons 'runtime-owned (.ref spec 'runtime-owned))
          (cons 'deferred (.ref spec 'deferred)))))

;;; Boundary: source proof index preserves tutorial source order from specs.
;;; Use it for diagnostics that need proof strings; keep source-index compact.
;; : (-> [PooObject] [Alist] [Alist])
(def (alignment-source-proof-index/rev specs rows-rev)
  (if (null? specs)
    rows-rev
    (alignment-source-proof-index/rev
     (cdr specs)
     (cons (alignment-source-proof-entry (car specs)) rows-rev))))

;; : (-> [PooObject] [Alist])
(def (alignment-source-proof-index specs)
  (reverse (alignment-source-proof-index/rev specs '())))

;;; Boundary: owner symbol collection is stable and spec-order preserving.
;;; Duplicate runtime owners collapse into the first observed matrix row.
;; : (-> [PooObject] [Symbol])
(def (alignment-runtime-owner-symbols specs)
  (delete-duplicates/hash
   (append-map (lambda (spec) (.ref spec 'runtime-owned)) specs)
   table: (make-hash-table-eq)
   from-end?: #t))

;;; Boundary: deferred output aggregation keeps spec order without repeated
;;; append growth while preserving each spec's local deferred order.
;; : (-> [PooObject] [Symbol])
(def (alignment-deferred-values specs)
  (foldr
   (lambda (spec deferred-values)
     (foldr cons deferred-values (.ref spec 'deferred)))
   '()
   specs))

;;; Boundary: status filtering stays over normalized spec rows.
;;; It supports coverage matrix projections without changing the source table.
;; : (-> Symbol [PooObject] [PooObject] [PooObject])
(def (alignment-specs-with-status/rev status specs specs-rev)
  (cond
   ((null? specs) specs-rev)
   ((eq? status
         (agentic-ai-lab-funflow-tutorial-alignment-spec-status (car specs)))
    (alignment-specs-with-status/rev
     status
     (cdr specs)
     (cons (car specs) specs-rev)))
   (else
    (alignment-specs-with-status/rev status (cdr specs) specs-rev))))

;; : (-> Symbol [PooObject] [PooObject])
(def (alignment-specs-with-status status specs)
  (reverse (alignment-specs-with-status/rev status specs '())))

;; : (-> [PooObject] [Symbol] [Symbol])
(def (alignment-spec-statuses/rev specs statuses-rev)
  (if (null? specs)
    statuses-rev
    (alignment-spec-statuses/rev
     (cdr specs)
     (cons (agentic-ai-lab-funflow-tutorial-alignment-spec-status (car specs))
           statuses-rev))))

;; : (-> [PooObject] [Symbol])
(def (alignment-spec-statuses specs)
  (reverse (alignment-spec-statuses/rev specs '())))

;; : (-> [PooObject] [String] [String])
(def (alignment-spec-sources/rev specs sources-rev)
  (if (null? specs)
    sources-rev
    (alignment-spec-sources/rev
     (cdr specs)
     (cons (.ref (car specs) 'source) sources-rev))))

;; : (-> [PooObject] [String])
(def (alignment-spec-sources specs)
  (reverse (alignment-spec-sources/rev specs '())))

;;; Boundary: status matrix rows expose source ids and paths for one status.
;;; The row is a report index, not another coverage authority.
;; : (-> Symbol [PooObject] Alist)
(def (alignment-status-source-entry status specs)
  (let (matching-specs (alignment-specs-with-status status specs))
    (list (cons 'status status)
          (cons 'count (length matching-specs))
          (cons 'ids (alignment-spec-ids matching-specs))
          (cons 'sources (alignment-spec-sources matching-specs)))))

;;; Boundary: matrix order follows status-counts so summary and detail align.
;;; Consumers can compare counts without re-scanning the spec snapshots.
;; : (-> Alist [PooObject] [Alist] [Alist])
(def (alignment-status-source-matrix/rev status-counts specs rows-rev)
  (if (null? status-counts)
    rows-rev
    (alignment-status-source-matrix/rev
     (cdr status-counts)
     specs
     (cons (alignment-status-source-entry (caar status-counts) specs)
           rows-rev))))

;; : (-> [PooObject] [Alist])
(def (alignment-status-source-matrix specs)
  (reverse
   (alignment-status-source-matrix/rev
    (alignment-status-counts specs)
    specs
    '())))

;;; Boundary: runtime owner matching is structural and data-only.
;;; It never executes the runtime operation named by the owner symbol.
;; : (-> Symbol PooObject Boolean)
(def (alignment-spec-has-runtime-owner? owner spec)
  (not (not (member owner (.ref spec 'runtime-owned)))))

;;; Boundary: runtime owner rows show handoff blast radius by backend concern.
;;; Statuses and deferred outputs stay attached so runtime readiness is visible.
;; : (-> Symbol [PooObject] [PooObject] [PooObject])
(def (alignment-specs-with-runtime-owner/rev owner specs specs-rev)
  (cond
   ((null? specs) specs-rev)
   ((alignment-spec-has-runtime-owner? owner (car specs))
    (alignment-specs-with-runtime-owner/rev
     owner
     (cdr specs)
     (cons (car specs) specs-rev)))
   (else
    (alignment-specs-with-runtime-owner/rev owner (cdr specs) specs-rev))))

;; : (-> Symbol [PooObject] [PooObject])
(def (alignment-specs-with-runtime-owner owner specs)
  (reverse (alignment-specs-with-runtime-owner/rev owner specs '())))

;; : (-> Symbol [PooObject] Alist)
(def (alignment-runtime-owner-entry owner specs)
  (let (matching-specs (alignment-specs-with-runtime-owner owner specs))
    (list (cons 'runtime-owner owner)
          (cons 'count (length matching-specs))
          (cons 'ids (alignment-spec-ids matching-specs))
          (cons 'statuses (alignment-spec-statuses matching-specs))
          (cons 'sources (alignment-spec-sources matching-specs))
          (cons 'deferred (alignment-deferred-values matching-specs)))))

;;; Boundary: owner matrix groups runtime gaps by backend concern.
;;; It is diagnostic metadata for Marlin handoff, not an execution scheduler.
;; : (-> [Symbol] [PooObject] [Alist] [Alist])
(def (alignment-runtime-owner-matrix/rev owners specs rows-rev)
  (if (null? owners)
    rows-rev
    (alignment-runtime-owner-matrix/rev
     (cdr owners)
     specs
     (cons (alignment-runtime-owner-entry (car owners) specs) rows-rev))))

;; : (-> [PooObject] [Alist])
(def (alignment-runtime-owner-matrix specs)
  (reverse
   (alignment-runtime-owner-matrix/rev
    (alignment-runtime-owner-symbols specs)
    specs
    '())))

;;; Boundary: readiness summary is a CI/user-interface snapshot.
;;; It summarizes existing report indexes without becoming a runtime scheduler.
;; : (-> Integer Alist [Alist] [Alist] Integer Integer Alist)
(def (alignment-handoff-readiness-summary source-count
                                          status-counts
                                          runtime-owner-matrix
                                          runtime-gap-index
                                          proof-count
                                          gate-proof-count)
  (let ((runtime-gap-count (length runtime-gap-index)))
    (list (cons 'runtime-owner "marlin-agent-core")
          (cons 'runtime-executed #f)
          (cons 'source-count source-count)
          (cons 'result-covered
                (alignment-status-count-ref 'result-covered status-counts))
          (cons 'runtime-manifest-covered
                (alignment-status-count-ref 'runtime-manifest-covered
                                            status-counts))
          (cons 'descriptor-covered
                (alignment-status-count-ref 'descriptor-covered status-counts))
          (cons 'runtime-gap-count runtime-gap-count)
          (cons 'runtime-owner-count (length runtime-owner-matrix))
          (cons 'proof-count proof-count)
          (cons 'gate-proof-count gate-proof-count)
          (cons 'handoff-required (> runtime-gap-count 0)))))

;;; Boundary: CI receipt manifest is inert user-interface data.
;;; It names local proof commands without becoming a command runner.
;; : (-> Alist Alist)
(def (alignment-ci-receipt-manifest handoff-readiness-summary)
  (list (cons 'schema
              'agentic-ai-lab.modules.funflow.tutorial-alignment.ci-receipts.v1)
        (cons 'expected-status 'pass)
        (cons 'runtime-executed #f)
        (cons 'handoff-readiness-summary handoff-readiness-summary)
        (cons 'result-gates
              '(alignment-report
                runtime-manifest
                functional-flow-kernel
                tutorial-feature-batch
                tutorial-makefile-runtime
                user-interface-marlin-handoff
                package-compile
                org-lint))
        (cons 'commands
              '("gxtest t/funflow-tutorial-alignment-report-test.ss"
                "gxtest t/runtime-manifest-test.ss"
                "gxtest t/functional-flow-kernel-test.ss"
                "gxtest t/tutorial-feature-batch-test.ss"
                "gxtest t/tutorial-makefile-runtime-test.ss"
                "gxtest t/user-interface-cicd-test.ss"
                "gxi build.ss compile"
                "asp org lint docs/10-19-design/10.04-funflow-tutorial-result-ladder.org"))))

;;; Boundary: this gate describes the user-interface handoff proof introduced
;;; after the workflow-owned Marlin ABI. It is metadata only; the actual user
;;; config projection is asserted by tests, not executed by this report.
;; : (-> Unit Alist)
(def (alignment-user-interface-handoff-result-gate)
  (list
   (cons 'schema
         'agentic-ai-lab.modules.funflow.tutorial-alignment.user-interface-handoff-gate.v1)
   (cons 'gate-id 'stage-23-user-interface-marlin-handoff-projection)
   (cons 'presentation-field 'workflow-cicd-marlin-runtime-handoff-abis)
   (cons 'summary-field 'workflow-cicd-marlin-runtime-handoff-summaries)
   (cons 'bundle-field 'workflow-cicd-marlin-handoff-receipt-bundle)
   (cons 'expected-abi-kind
         'agentic-ai-lab.workflow.cicd.marlin-runtime-handoff-abi)
   (cons 'expected-bundle-kind
         'workflow-cicd-marlin-handoff-receipt-bundle)
   (cons 'runtime-owner "marlin-agent-core")
   (cons 'handoff-required #t)
   (cons 'runtime-executed #f)
   (cons 'runtime-parses-scheme-source #f)
   (cons 'scheme-manufactures-runtime-handlers #f)
   (cons 'proof-command
         "gxtest t/user-interface-cicd-test.ss: projects user config into Marlin runtime handoff ABI")))

;;; Boundary: runtime-gap detection stays structural and data-only.
;;; A gap means the source still delegates real work to Rust/Marlin runtime.
;; : (-> PooObject Boolean)
(def (alignment-runtime-gap-spec? spec)
  (or (not (null? (.ref spec 'runtime-owned)))
      (not (null? (.ref spec 'deferred)))))

;;; Boundary: gap entries keep source, owner, and deferred output in one row.
;;; This makes Docker/CAS/process/image gaps inspectable without running them.
;; : (-> PooObject Alist)
(def (alignment-runtime-gap-entry spec)
  (list (cons 'source (.ref spec 'source))
        (cons 'id (.ref spec 'id))
        (cons 'status (.ref spec 'status))
        (cons 'runtime-owned (.ref spec 'runtime-owned))
        (cons 'deferred (.ref spec 'deferred))))

;;; Boundary: runtime gap index is a report-only diagnostic projection.
;;; It does not imply the Scheme side can execute the listed runtime work.
;; : (-> [PooObject] [Alist] [Alist])
(def (alignment-runtime-gap-index/rev specs rows-rev)
  (cond
   ((null? specs) rows-rev)
   ((alignment-runtime-gap-spec? (car specs))
    (alignment-runtime-gap-index/rev
     (cdr specs)
     (cons (alignment-runtime-gap-entry (car specs)) rows-rev)))
   (else
    (alignment-runtime-gap-index/rev (cdr specs) rows-rev))))

;; : (-> [PooObject] [Alist])
(def (alignment-runtime-gap-index specs)
  (reverse (alignment-runtime-gap-index/rev specs '())))

;; : (-> [AgenticAILabAlignmentGateProof] [Symbol] [Symbol])
(def (alignment-gate-proof-ids/rev gate-proofs ids-rev)
  (if (null? gate-proofs)
    ids-rev
    (alignment-gate-proof-ids/rev
     (cdr gate-proofs)
     (cons (alignment-gate-proof-id (car gate-proofs)) ids-rev))))

;; : (-> [AgenticAILabAlignmentGateProof] [Symbol])
(def (alignment-gate-proof-ids gate-proofs)
  (reverse (alignment-gate-proof-ids/rev gate-proofs '())))

;; : (-> [PooObject] [Alist] [Alist])
(def (alignment-spec-snapshots/rev specs snapshots-rev)
  (if (null? specs)
    snapshots-rev
    (alignment-spec-snapshots/rev
     (cdr specs)
     (cons (alignment-spec-snapshot (car specs)) snapshots-rev))))

;; : (-> [PooObject] [Alist])
(def (alignment-spec-snapshots specs)
  (reverse (alignment-spec-snapshots/rev specs '())))

;;; Boundary: aggregate observability is derived only from normalized spec rows.
;;; The map keeps row snapshots separate from report-level summary metadata.
;; : (-> [PooObject] PooObject)
(def (agentic-ai-lab-funflow-tutorial-alignment-report . maybe-specs)
  (let* ((specs (if (null? maybe-specs)
                  (agentic-ai-lab-funflow-tutorial-alignment-specs)
                  (car maybe-specs)))
         (ids-value (alignment-spec-ids specs))
         (source-count-value (length specs))
         (status-counts-value (alignment-status-counts specs))
         (deferred-ids-value (alignment-deferred-ids specs))
         (proof-count-value (alignment-proof-count specs))
         (gate-proofs-value
          (agentic-ai-lab-funflow-tutorial-alignment-gate-proofs))
         (gate-ids-value (alignment-gate-proof-ids gate-proofs-value))
         (gate-proof-count-value
          (alignment-gate-proof-count gate-proofs-value))
         (spec-snapshots-value (alignment-spec-snapshots specs))
         (source-index-value (alignment-source-index specs))
         (source-proof-index-value (alignment-source-proof-index specs))
         (status-source-matrix-value
          (alignment-status-source-matrix specs))
         (runtime-owner-matrix-value (alignment-runtime-owner-matrix specs))
         (runtime-gap-index-value (alignment-runtime-gap-index specs))
         (handoff-readiness-summary-value
          (alignment-handoff-readiness-summary source-count-value
                                                status-counts-value
                                                runtime-owner-matrix-value
                                                runtime-gap-index-value
                                                proof-count-value
                                                gate-proof-count-value))
         (ci-receipt-manifest-value
          (alignment-ci-receipt-manifest handoff-readiness-summary-value))
         (user-interface-handoff-result-gate-value
          (alignment-user-interface-handoff-result-gate)))
   (object<-alist
    (list
     (cons 'kind (agentic-ai-lab-funflow-tutorial-alignment-report-kind))
     (cons 'schema (agentic-ai-lab-funflow-tutorial-alignment-schema))
     (cons 'upstream "tweag/funflow")
     (cons 'upstream-revision "356bc675")
     (cons 'audited-surface
           "funflow-tutorial/notebooks plus funflow-examples/makefile-tool")
     (cons 'source-count source-count-value)
     (cons 'spec-ids ids-value)
     (cons 'specs spec-snapshots-value)
     (cons 'source-index source-index-value)
     (cons 'source-proof-index source-proof-index-value)
     (cons 'status-source-matrix status-source-matrix-value)
     (cons 'status-counts status-counts-value)
     (cons 'deferred-ids deferred-ids-value)
     (cons 'runtime-owner-matrix runtime-owner-matrix-value)
     (cons 'handoff-readiness-summary handoff-readiness-summary-value)
     (cons 'ci-receipt-manifest ci-receipt-manifest-value)
     (cons 'user-interface-handoff-result-gate
           user-interface-handoff-result-gate-value)
     (cons 'runtime-gap-index runtime-gap-index-value)
     (cons 'runtime-gap-count (length runtime-gap-index-value))
     (cons 'proof-count proof-count-value)
     (cons 'gate-count (length gate-ids-value))
     (cons 'gate-ids gate-ids-value)
     (cons 'gate-proofs gate-proofs-value)
     (cons 'gate-proof-count gate-proof-count-value)
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f)))))
