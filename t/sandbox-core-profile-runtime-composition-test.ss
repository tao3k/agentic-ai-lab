(import (only-in :agentic-ai-lab/modules/agent-sandbox/func agentic-ai-lab-sandbox-profile-network-policy agentic-ai-lab-sandbox-profile-capabilities agentic-ai-lab-sandbox-profile-metadata))
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO prototype admission for backend-owned Sandbox Profiles.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :std/test check-equal? test-suite)
        :agentic-ai-lab/modules/nono-sandbox/objects
        :agentic-ai-lab/modules/agent-sandbox/config
        :agentic-ai-lab/modules/sandbox-core/profile-support/resolve)

(export sandbox-core-profile-runtime-composition-test)

(def sandbox-core-profile-runtime-composition-test
  (test-suite "runtime Sandbox Profile composition"
    (yuanxu-test-case "backend defaults are direct POO prototype slots"
      (let (base
            (agentic-ai-lab-sandbox-profile-object-base-prototype
             agentic-ai-lab-nono-sandbox-profile-object 'nono 'runtime/base))
        (check-equal?
         (agentic-ai-lab-sandbox-profile-object-slot base 'profile-name)
         'runtime/base)
        (check-equal?
         (agentic-ai-lab-sandbox-profile-object-slot base 'backend-kind)
         'nono)))
    (yuanxu-test-case "an empty row set projects the backend prototype"
      (let (profile
            (agentic-ai-lab-sandbox-profile-object-config
             agentic-ai-lab-nono-sandbox-profile-object 'nono 'runtime/empty '()))
        (check-equal?
         (agentic-ai-lab-sandbox-profile-object-profile? profile)
         #t)))
    (yuanxu-test-case "explicit list policy composes on a POO prototype"
      (let (profile
            (agentic-ai-lab-sandbox-profile-object-config
             agentic-ai-lab-nono-sandbox-profile-object
             'nono
             'runtime/composed
             '((capabilities :prepend filesystem-read)
               (capabilities :append filesystem-write)
               (capabilities :remove filesystem-read)
               (network :override deny-by-default)
               (metadata (stage . runtime)))))
        (check-equal?
         (agentic-ai-lab-sandbox-profile-capabilities profile)
         '(process filesystem tmpdir filesystem-write))
        (check-equal?
         (agentic-ai-lab-sandbox-profile-network-policy profile)
         '(deny-by-default))
        (check-equal?
         (cdr (assoc 'stage (agentic-ai-lab-sandbox-profile-metadata profile)))
         'runtime)))))
