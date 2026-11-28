;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Context profile data for source projection and checkpoint replay.
(import (only-in :clan/poo/object .o .ref .slot? object?))
(export ContextCoreProfile context-profile-from-feature-ids context-profile-feature-ids)

(def (canonical-feature-ids ids)
  (cond
    ((equal? ids '(ai-agentic-context/core))
     (list 'ai-agentic-context/core))
    ((or (equal? ids '(ai-agentic-context/core ai-agentic-context/memory))
         (equal? ids '(ai-agentic-context/memory ai-agentic-context/core)))
     (list 'ai-agentic-context/core 'ai-agentic-context/memory))
    (else (error "foreign or incomplete Context Feature profile"))))

(def (context-profile-from-feature-ids ids)
  (def canonical (canonical-feature-ids ids))
  (.o accepted?: #t feature-ids: canonical))

(def ContextCoreProfile (context-profile-from-feature-ids '(ai-agentic-context/core)))

(def (context-profile-feature-ids profile)
  (unless (and (object? profile) (.slot? profile 'accepted?) (.ref profile 'accepted?)
               (.slot? profile 'feature-ids))
    (error "unqualified Context Feature profile"))
  (canonical-feature-ids (.ref profile 'feature-ids)))
