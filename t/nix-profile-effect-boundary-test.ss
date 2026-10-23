;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Real local Nix profile effects; no default/user profile is touched.
(import :std/test :clan/poo/object
        (only-in :std/error Error?)
        (only-in :std/encoding/json write-json read-json)
        (only-in :std/list/walist waref)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :yuanxu/ops/objects ProcessScript.)
        (only-in :yuanxu/ops/func run-script)
        (only-in :agentic-ai-lab/modules/nix/objects NixSource.)
        (only-in :yuanxu/module-system/source/admission module-source-admit-current! module-source-read)
        (only-in :yuanxu/observability/testing-fixture yuanxu-test-fixture)
        (only-in :yuanxu/t/qualification/service-publication/fixtures ServicesFixture write-source))
(export nix-profile-effect-boundary-test)

;; Only the admitted, selected domain plan is packaged. Not all module fields.
(def (plan-release root label plan)
  (def directory (path-expand label root))
  (create-directory* (path-expand "payload" directory))
  (call-with-output-file (path-expand "payload/plan.json" directory)
    (lambda (port)
      (write-json port (hash ("postgresql" (.get plan postgresql port))
                            ("gitea" (.get plan gitea database-port))))))
  (def expression (path-expand "release.nix" directory))
  (write-source expression
    (string-append
      "let pkgs = import <nixpkgs> {}; in pkgs.runCommand \"yuanxu-head-" label "\"\n"
      "{ src = ./payload; } \"mkdir $out; cp $src/plan.json $out/plan.json\"\n"))
  (def source (.cc NixSource. 'expression expression))
  (def observations (.get source source-inputs))
  (values (.call source .build (cut module-source-admit-current! observations)) expression))
(def (profile-command profile . arguments)
  (.cc ProcessScript. 'command (append (list "nix-env" "--profile" profile) arguments)
       'timeout 30))
(def (profile-plan profile)
  (call-with-input-file (path-expand "plan.json" profile) read-json))

(def nix-profile-effect-boundary-test
  (test-suite "Real Nix profile persistence is not conditional deployment"
    (yuanxu-test-fixture "fresh process recovery and stale saved effects use immutable releases"
      (fixture ServicesFixture)
      (with-slots (root selection publication) fixture
        (def parent (.get publication value))
        (def cached (.get parent plan))
        (.def (Release @ parent)
          config: =>.+ (.o postgresql: =>.+ (.o settings: =>.+ (.o port: 5433))))
        (defvalues (receipt next failure) (.call publication .publish parent Release))
        (check-equal? failure #f)
        (check-equal? (.get receipt accepted?) #t)
        (check-equal? (length (.get publication context contributions)) 2)
        (check-equal? (memq 'services/unused (.get selection selected-graph module-order)) #f)
        (defvalues (old-publication old-expression) (plan-release root "parent" cached))
        (defvalues (new-publication new-expression) (plan-release root "child" (.get next plan)))
        (def old-artifact (.get old-publication artifact))
        (def new-artifact (.get new-publication artifact))
        (def profile (path-expand "deployment" root))
        ;; Each .run starts and waits for a real, independent nix-env process.
        (check-equal? (.get (.call (profile-command profile "--set" old-artifact) .run) status) 0)
        (def saved (profile-command profile "--set" old-artifact))
        (check-equal? (.get (.call (profile-command profile "--set" new-artifact) .run) status) 0)
        (check-equal? (waref (profile-plan profile) "postgresql" #f) 5433)
        ;; Another Nix process recovers durable generations after writers exited.
        (def generations (.call (profile-command profile "--list-generations") .run))
        (check-equal? (.get generations status) 0)
        (check-equal? (and (pregexp-match "(^|\n)[ \t]*2[ \t]+" (.get generations output)) #t) #t)
        ;; Fresh Scheme process reads through the persisted profile, not a POO cache.
        (def restarted (run-script (.cc ProcessScript. 'command
          (list "just" "-f" "t/qualification/nix/Justfile" "head-reader" profile) 'timeout 30)
          stderr-redirection: #f))
        (check-equal? (.get restarted status) 0)
        (check-equal? (.get restarted output) "(5433 5433)\n")
        ;; Retained actual effect has no expected-revision/fence operand.
        (check-equal? (.get (.call saved .run) status) 0)
        (check-equal? (waref (profile-plan profile) "postgresql" #f) 5432)
        ;; Source guard refuses changed source; an already saved native effect
        ;; can nevertheless switch to the captured immutable snapshot.
        (write-source new-expression (string-append (module-source-read new-expression) "\n# changed\n"))
        (check-exception ((.get new-publication admit-current)) Error?)
        (check-equal? (.get (.call (profile-command profile "--set" new-artifact) .run) status) 0)
        (check-equal? (waref (profile-plan profile) "gitea" #f) 5433)
        (check-equal? (.get cached postgresql port) 5432)
        (check-equal? (.get next plan postgresql port) 5433)))
    (yuanxu-test-fixture "real conflicting domain requirements still prevent admission"
      (fixture (.cc ServicesFixture postgres-ports: '(5433) gitea-ports: '(5440)))
      (with-slots (publication) fixture
        (def parent (.get publication value))
        (.def (Release @ parent)
          config: =>.+ (.o postgresql: =>.+ (.o settings: =>.+ (.o port: 5433))))
        (def evidence (.call (.get publication contract) .admit Release (.get publication context)))
        (check-equal? (.get evidence accepted?) #f)
        (check-equal? (length (.get publication context contributions)) 2)))))
