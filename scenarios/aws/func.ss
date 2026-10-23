;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object "./types.ss" "./objects.ss")
(export aws-scenario-scope)
(def (aws-scenario-scope tofu config)
    (def baseline Scenario)
    (.o (:: @ [] provider)
        Profiles: (.o Web: (.get config resource aws_instance web))
        Scenario: (.cc baseline 'profile (.get config resource aws_instance web))
        provider: (.get tofu modules aws provider)
        types: (.o Scenario: (aws-scenario-contract
                              (.get provider types resources aws_instance value-type)))))
