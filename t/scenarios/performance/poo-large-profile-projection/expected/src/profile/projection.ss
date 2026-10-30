;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/object-family/indexed
                 poo-indexed-family
                 poo-indexed-family-object
                 poo-indexed-family-lenses
                 poo-indexed-family-project-objects))

;;; Scenario expected: the downstream profile is repaired into a reusable
;;; indexed POO family.  The public surface is still POO-native, while hot slot
;;; reads use a compiled lens and vector index instead of rebuilding objects or
;;; repeatedly scanning alists.

(def +projection-family+
  (poo-indexed-family
   'projection-profile-family
   'scenario.large-profile-projection
   '(name runtime policy sandbox tool checkpoint)))

(def +projection-specs+
  '((name . identity)
    (runtime . runtime-language)
    (policy . policy-plane)
    (sandbox . sandbox-scope)
    (tool . tool-binding)
    (checkpoint . durable-boundary)))

(def +projection-lenses+
  (poo-indexed-family-lenses
   +projection-family+
   +projection-specs+))

(def +projection-profile+
  (poo-indexed-family-object
   +projection-family+
   '(projection-profile
     python-runtime
     control-plane
     readonly
     search-tool
     durable)))

(def (projection-descriptors)
  (poo-indexed-family-project-objects
   +projection-family+
   +projection-profile+
   +projection-lenses+))
