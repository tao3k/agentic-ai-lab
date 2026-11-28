;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/signatures
                 Fun Any Number Integer String Symbol List Pair Null Unit)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow flow-output-contract)
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-protocol AdapterResult))
;;; Boundary: tutorial result tests mirror Funflow's local/config outputs.
;;; Invariant: each stage proves a user-visible result, not only an API shape.

(import (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        ;; Import the maintained functional owners used by this tutorial, without
        ;; loading the aggregate facade's unrelated Agent/syntax libraries.
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/flow-strand
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/failure
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/strategy
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-adapter
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-protocol
        (only-in :tao3k/agentic-ai-lab/modules/funflow/control-plane/runtime-command-invocation make-procedure-runtime-command)
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/runner
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/config
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/graph
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/roles
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/policy
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/replay
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/receipt
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/task)

(export funflow-tutorial-test)

;; : (-> Unit Runner)
(def (tutorial-runner)
  (make-runner (make-local-eager-strategy)
               (make-request-only-adapter)))

;; : (-> Flow Value Value)
(def (tutorial-run flow input)
  (run-result-value (runner-run (tutorial-runner) flow input)))

;; : (-> String Nat String)
(def (repeat-string text count)
  (if (<= count 0)
    ""
    (string-append text (repeat-string text (- count 1)))))

;; count-symbols
;;   : (-> (List Symbol) WordCounts WordCounts)
;;   | type WordCounts = (List Pair)
;;   | doc m%
;;       `count-symbols` folds tutorial words into count pairs.
;;
;;       # Examples
;;
;;       ```scheme
;;       (count-symbols '(a a b) '())
;;       ;; => ((b . 1) (a . 2))
;;       ```
;;     %
(def (count-symbols words counts)
  (if (null? words)
    counts
    (count-symbols (cdr words)
                   (increment-symbol-count (car words) counts))))

;; : (-> Symbol WordCounts WordCounts)
(def (increment-symbol-count word counts)
  (let (entry (alist-ref-entry counts word))
    (cons (cons word (+ 1 (if entry (count-entry-count entry) 0)))
          (remove-count word counts))))

;; : (-> Symbol WordCounts WordCounts)
(def (remove-count word counts)
  (filter (lambda (entry)
            (not (count-entry-for? word entry)))
          counts))

;; : (-> Symbol Pair Boolean)
(def (count-entry-for? word entry)
  (eq? word (count-entry-word entry)))

;; : (-> Pair Symbol)
(def (count-entry-word entry)
  (car entry))

;; : (-> Pair Nat)
(def (count-entry-count entry)
  (cdr entry))

;; : (-> Alist Symbol Value)
(def (count-ref counts word)
  (let (entry (alist-ref-entry counts word))
    (if entry (cdr entry) 0)))

;; : (-> Alist Symbol Pair)
(def (alist-ref-entry alist key)
  (assoc key alist))

;; : (-> Number Number)
(def (plus-one-value value)
  (+ value 1))

;; : (-> String String)
(def (hello-line input)
  (string-append "Hello " input " !"))

;; : (-> Unit String)
(def (literal-hello _input)
  "Hello")

;; : (-> String String)
(def (append-world input)
  (string-append input " world"))

;; : (-> String String)
(def (custom-repeat-line input)
  (string-append input (repeat-string "woop!" 7)))

;; : (-> [Symbol] Alist)
(def (count-words input)
  (count-symbols input '()))

;; : (-> TryResult String)
(def (handle-local-error-result result)
  (if (try-left? result)
    (string-append
     "handled: "
     (execution-failure-message
      (try-result-value result)))
    "unexpected success"))

;; : (-> String String)
(def (identity-value value)
  value)

;; : (-> Alist AdapterResponse)
(def (runtime-tutorial-command envelope)
  (list (cons 'schema +runtime-response-schema+)
        (cons 'request-id (cdr (alist-ref-entry envelope 'request-id)))
        (cons 'status 'completed)
        (cons 'value "runtime-result")
        (cons 'artifact-handle '(artifact tutorial))
        (cons 'error #f)
        (cons 'metadata '((tutorial . runtime-command)))))

;;; This suite keeps tutorial result contracts executable as examples evolve.
(def funflow-tutorial-test
  (test-suite "funflow tutorial result ladder"
    (yuanxu-test-case "stage 1 tutorial1 minimal pure flow returns 2"
      (let (flow (pure-flow
		  'plus-one
		  (Fun Number <- Number)
		  plus-one-value))
        (check-equal? (tutorial-run flow 1) 2)))
    (yuanxu-test-case "stage 2 quick reference hello and composition results"
      (let* ((hello (pure-flow
		     'hello
		     (Fun String <- String)
		     hello-line))
             (flow1 (pure-flow
		     'literal-hello
		     (Fun String <- Unit)
		     literal-hello))
             (flow2 (pure-flow
		     'append-world
		     (Fun String <- String)
		     append-world))
             (pipeline (flow-then 'hello-world flow1 flow2)))
        (check-equal? (tutorial-run hello "Watson") "Hello Watson !")
        (check-equal? (tutorial-run pipeline #!void) "Hello world")))
    (yuanxu-test-case "stage 3 tutorial2 extension behavior repeats custom text"
      (let* ((custom (scheme-flow
		      'custom-repeat
		      (Fun String <- String)
		      custom-repeat-line))
             (result (tutorial-run custom "Kangaroo goes ")))
        (check-equal? result "Kangaroo goes woop!woop!woop!woop!woop!woop!woop!")))
    (yuanxu-test-case "stage 4 word count exposes deterministic counts"
      (let* ((words '(a and it try words a and it try words a and it try words
                        lets this count give pipeline should lets this count
                        give pipeline should file))
             (count-flow (pure-flow
			  'count-words
			  (Fun (List (Pair Symbol Integer)) <- (List Symbol))
			  count-words))
             (counts (tutorial-run count-flow words)))
        (check-equal? (count-ref counts 'a) 3)
        (check-equal? (count-ref counts 'and) 3)
        (check-equal? (count-ref counts 'lets) 2)
        (check-equal? (count-ref counts 'file) 1)))
    (yuanxu-test-case "stage 5 external config fails before runtime submission"
      (let* ((requirement (make-config-requirement 'env 'SECOND_GREETING #t))
             (config (make-run-config
                      'tutorial-missing-config
                      (make-local-eager-strategy)
                      (make-request-only-adapter)
                      (list (cons 'config-requirements (list requirement)))))
             (flow (external-flow
		    'echo
		    'docker-echo
		    '((image . "alpine:latest"))
		    (Fun AdapterResult <- Unit)))
             (failure (with-catch (lambda (failure) failure)
                                  (lambda ()
                                    (run-flow-with-config config flow #!void)))))
        (check-equal? (execution-failure? failure) #t)
        (check-equal? (execution-failure-code failure) 'missing-config-keys)))
    (yuanxu-test-case "stage 6 error handling try-flow routes thrown failures"
      (let* ((thrower (throw-string-flow
		       'throw-local
		       "handled tutorial failure"
		       (Fun String <- Unit)))
             (attempt (try-flow 'try-local thrower))
             (handled
              (flow-map
	       'handle-local-error
	       attempt
	       (Fun String <- (flow-output-contract attempt))
	       handle-local-error-result))
             (success
              (try-flow 'try-success
                        (pure-flow
			 'success
			 (Fun String <- String)
			 identity-value)))
             (success-result (tutorial-run success "ok")))
        (check-equal? (tutorial-run handled #!void)
                      "handled: handled tutorial failure")
        (check-equal? (try-right? success-result) #t)
        (check-equal? (try-result-value success-result) "ok")))
    (yuanxu-test-case "stage 7 configured runtime command returns normalized result"
      (let* ((config (make-rust-run-config
                      (list (cons 'runtime-command
                              (make-procedure-runtime-command 'tutorial runtime-tutorial-command)))))
             (flow (external-flow
		    'runtime-demo
		    'submit
		    '((payload . tutorial))
		    (Fun AdapterResult <- Unit)))
             (result (run-result-value
                      (run-flow-with-config config flow #!void))))
        (check-equal? (adapter-result-status result) 'completed)
        (check-equal? (adapter-result-value result) "runtime-result")
        (check-equal? (adapter-result-artifact-handle result)
                      '(artifact tutorial))))))
