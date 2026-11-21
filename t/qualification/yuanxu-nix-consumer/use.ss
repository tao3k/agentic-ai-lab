;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :yuanxu-nix-consumer/main :yuanxu-nix-consumer/init
        (only-in :clan/poo/object .def .o .get .all-slots/sort .ref/cached))
(unless (equal? (.all-slots/sort (.get yuanxu-nix-consumer.init.exports modules)) '(nix))
  (error "consumer exposed unselected owners"))
(unless (not (.ref/cached (.get yuanxu-nix-consumer.init.exports modules) 'nix))
  (error "namespace import/enumeration forced a business scope"))
(def scope (.get yuanxu-nix-consumer.init.exports modules nix))
(unless (and (equal? (.get (selected-config) nix) "nix")
             (eq? (selected-config) (.get scope config))
             (eq? scope (.get yuanxu-nix-consumer.init.exports modules nix)))
  (error "selected Lab scope value or identity changed"))
;; The runtime Graph owns runtime currentness. init's build guard belongs to a
;; prepared std-make-spec, which this business process deliberately never asks for.
((.get yuanxu-nix-consumer.init.exports tests selected-graph admit-current))
;; A user derives a business Source from the public prototype. The Module
;; scope itself remains the same admitted object; no Nix effect is performed.
(def Source (.get scope prototypes Source))
(def inherited-config (.get Source config))
(.def (LocalSource @ Source)
  config: =>.+ (.o nix: "/opt/local/bin/nix"))
(unless (and (equal? (.get LocalSource config nix) "/opt/local/bin/nix")
             (equal? (.get LocalSource config instantiate) (.get inherited-config instantiate))
             (equal? (.get LocalSource config source-checker) (.get inherited-config source-checker))
             (eq? inherited-config (.get Source config))
             (equal? (.get scope config nix) "nix"))
  (error "business prototype refinement changed its parent or Module scope"))
(displayln "LAB-SELECTED-USE-OK identity=original currentness=ok")
