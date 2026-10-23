;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO accessors for Scenario Case objects.
;;; Invariant: accessors do not interpret graph, loop, or proof payloads.

(import (only-in :clan/poo/object .ref))

(export agentic-ai-lab-scenario-case-name
        agentic-ai-lab-scenario-case-modules
        agentic-ai-lab-scenario-case-profiles
        agentic-ai-lab-scenario-case-stages)

;;; Returns the symbolic composition name.
;;   | doc m%
;;       # Examples
;;       (agentic-ai-lab-scenario-case-name composition)
;;   | result: composition name symbol
;; : (-> AgenticAILabScenarioCase Symbol)
(def (agentic-ai-lab-scenario-case-name composition)
  (.ref composition 'name))

;;; Returns module alias binding objects captured by the composer.
;;   | doc m%
;;       # Examples
;;       (agentic-ai-lab-scenario-case-modules composition)
;;   | result: ordered module binding objects
;; : (-> AgenticAILabScenarioCase List)
(def (agentic-ai-lab-scenario-case-modules composition)
  (.ref composition 'modules))

;;; Returns top-level profiles selected by the composition.
;; : (-> AgenticAILabScenarioCase List)
(def (agentic-ai-lab-scenario-case-profiles composition)
  (.ref composition 'profiles))

;;; Returns the native named Stage slot space.
;;   | doc m%
;;       # Examples
;;       (agentic-ai-lab-scenario-case-stages composition)
;;   | result: POO Stage slot space
;; : (-> AgenticAILabScenarioCase PooObject)
(def (agentic-ai-lab-scenario-case-stages composition)
  (.ref composition 'stages))
