;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Native POO prototype admission for backend-owned Sandbox Profiles.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :std/test check-equal? test-suite)
        :poo-flow/modules/nono-sandbox/objects
        :poo-flow/modules/agent-sandbox/config
        :poo-flow/modules/sandbox-core/profile-support/resolve)

(export sandbox-core-profile-native-composition-test)

(def sandbox-core-profile-native-composition-test
  (test-suite "native Sandbox Profile composition"
    (yuanxu-test-case "backend defaults are direct POO prototype slots"
      (let (base
            (poo-flow-sandbox-profile-object-base-prototype
             poo-flow-nono-sandbox-profile-object 'nono 'native/base))
        (check-equal?
         (poo-flow-sandbox-profile-object-slot base 'profile-name)
         'native/base)
        (check-equal?
         (poo-flow-sandbox-profile-object-slot base 'backend-kind)
         'nono)))
    (yuanxu-test-case "an empty row set projects the backend prototype"
      (let (profile
            (poo-flow-sandbox-profile-object-config
             poo-flow-nono-sandbox-profile-object 'nono 'native/empty '()))
        (check-equal?
         (poo-flow-sandbox-profile-object-profile? profile)
         #t)))
    (yuanxu-test-case "explicit list policy composes on a POO prototype"
      (let (profile
            (poo-flow-sandbox-profile-object-config
             poo-flow-nono-sandbox-profile-object
             'nono
             'native/composed
             '((capabilities :prepend filesystem-read)
               (capabilities :append filesystem-write)
               (capabilities :remove filesystem-read)
               (network :override deny-by-default)
               (metadata (stage . native)))))
        (check-equal?
         (poo-flow-sandbox-profile-capabilities profile)
         '(process filesystem tmpdir filesystem-write))
        (check-equal?
         (poo-flow-sandbox-profile-network-policy profile)
         '(deny-by-default))
        (check-equal?
         (cdr (assoc 'stage (poo-flow-sandbox-profile-metadata profile)))
         'native)))))
