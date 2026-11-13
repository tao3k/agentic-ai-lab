;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object
        (only-in :std/list/list find)
        (only-in :std/misc/ports read-all-as-string)
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/runtime-service
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/session-host
        :tao3k/agentic-ai-lab/modules/ai-agentic-context/use-host
        :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/monotonic-clock
        :tao3k/agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :tao3k/agentic-ai-lab/modules/temporal-causality/time/objects
        :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy
        :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host)
(export durable-agenda-start)

(def clock-id "durable-agenda")
(def (now) (inexact->exact (floor (time->seconds (current-time)))))
(def (instant coordinate)
  (agentic-ai-lab-temporal-instant (number->string coordinate) clock-id coordinate clock-id 'observed))

(def (owner-agenda journal policies config)
  (let ((source (path-expand (.ref config 'source))) (offset (.ref config 'offset))
        (authorized? (.ref config 'authorized?)) (action (.ref config 'action))
        (query (.ref config 'query)) (armed #f) (ready #f))
    (def (agenda-key item)
      (string-append "agenda:" (journal-hash (journal-pack (list source (.ref item 'identity))))))
    (def (next)
      (let (source-text (call-with-input-file source read-all-as-string))
        (foldl (lambda (item best)
          (if (and (authorized? item) (not (journal-get journal (agenda-key item)))
                   (or (not best) (< (.ref item 'due) (.ref best 'due))
                       (and (= (.ref item 'due) (.ref best 'due))
                            (string<? (.ref item 'identity) (.ref best 'identity)))))
            item best)) #f (query source-text offset))))
    (def (same? a b)
      (and a b (equal? (.ref a 'identity) (.ref b 'identity)) (= (.ref a 'due) (.ref b 'due))))
    (def (refresh!)
      (let (item (next))
        (unless (same? item armed)
          (set! armed item)
          (set! ready #f)
          (when item
            (let* ((prior (find (lambda (row) (equal? (.ref (.ref row 'policy) 'identity) clock-id))
                               (agentic-ai-lab-temporal-support-policy-host-snapshots policies)))
                   (generation (if prior (+ 1 (.ref prior 'generation)) 1))
                   (time (inexact->exact (floor (- (monotonic-seconds)
                             (.ref (journal-get journal "anchor") 'epoch)))))
                   (delay (max 2 (- (.ref item 'due) (now))))
                   (policy (agentic-ai-lab-temporal-support-policy clock-id (number->string generation)
                             (instant time) (instant (+ time delay)))))
              (agentic-ai-lab-temporal-support-policy-host-refresh! policies policy generation (instant time)))))
        (and item (.ref item 'identity))))
    (def (take!)
      (let* ((item (next))
             (release (and (same? item ready) (<= (.ref item 'due) (now)))))
        (if release
          (let ((handoff (.o key: (agenda-key item) identity: (.ref item 'identity) due: (.ref item 'due) (action))))
            (journal-put! journal (agenda-key item) handoff)
            (set! armed #f)
            (set! ready #f)
            handoff)
          (begin (refresh!) #f))))
    ;; Policy-clock delivers on this owner and commits its existing timer
    ;; transaction. Foreign callers must still pass the final use check.
    (agentic-ai-lab-temporal-support-policy-host-watch! policies
      (.o kind: 'temporal.source-observer.v1
        .prepare: (lambda (self event)
          (let* ((snapshot (.ref event 'revised)) (policy (.ref snapshot 'policy))
                 (expired? (and (equal? (.ref policy 'identity) clock-id)
                               (>= (.ref (.ref snapshot 'effective-at) 'coordinate)
                                   (.ref (.ref policy 'end) 'coordinate)))))
            (.o kind: 'temporal.source-propagation-batch.v1
                .publish!: (lambda (self)
                  (when expired?
                    (let (item (next))
                      (if (and (same? item armed) (<= (.ref item 'due) (now)))
                        (set! ready item)
                        (begin (set! armed #f) (set! ready #f)))))
                  #t))))))
    (.o .refresh!: (lambda (self allowed)
                     (when allowed (set! authorized? allowed))
                     (refresh!))
        .take!: (lambda (self) (take!)))))

(def (durable-agenda-start config)
  (context-start-durable-service
   (.o journal-path: (.ref config 'journal-path)
       clock: (.o domain: clock-id origin: 0 tick-seconds: 1.)
       .initialize: (lambda (self journal)
         (let* ((grants (agentic-ai-lab-context-use-host))
                (policies (agentic-ai-lab-temporal-support-policy-host))
                (host (agentic-ai-lab-ai-agentic-context-session-host grants policies #f)))
           (.o (grants) (policies) (host)
               recovery: #f proof-resolver: (lambda (registration) #f) query-provider: #f
               agenda: (owner-agenda journal policies config)))))))
