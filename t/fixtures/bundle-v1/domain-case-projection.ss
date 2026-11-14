;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(export make-bundle-v1-domain-case-runtime-handoff-plan)

(import (only-in :std/list/list map)
        :clan/poo/object
        :tao3k/yuanxu/utilities/functional
        :tao3k/yuanxu/module-system/feature/domain-case/interface
        :tao3k/yuanxu/module-system/feature/interface)

(def (fixture-id prefix index)
  (string->symbol
   (string-append prefix "-" (number->string index))))

(def (fixture-role index)
  (object<-alist
   (list (cons (fixture-id "bundle-role" index) #t))))

(def (fixture-value? _value) #t)
(def (fixture-project value) value)

(def (runtime-projection index)
  (yuanxu-case-projection
   (fixture-id "bundle-runtime-projection" index)
   (fixture-id "bundle-component" index)
   (fixture-id "bundle-runtime-schema" index)
   fixture-project))

(def (evidence-projection index)
  (yuanxu-case-projection
   (fixture-id "bundle-evidence-projection" index)
   (fixture-id "bundle-component" index)
   (fixture-id "bundle-evidence-schema" index)
   fixture-project))

(def duplicate-runtime-projection
  (yuanxu-case-projection
   'bundle-runtime-projection-duplicate
   'bundle-component-0
   'bundle-runtime-schema-duplicate
   fixture-project))

(def (component-projections
      index runtime-count evidence-count duplicate-runtime-owner?)
  (append
   (if (< index runtime-count)
       (list (runtime-projection index))
       '())
   (if (and duplicate-runtime-owner? (= index 0))
       (list duplicate-runtime-projection)
       '())
   (if (< index evidence-count)
       (list (evidence-projection index))
       '())))

(def (case-component
      index runtime-count evidence-count duplicate-runtime-owner?)
  (let ((type-id (fixture-id "bundle-type" index))
        (parent-type-ids
         (if (= index 0)
             '()
             (list (fixture-id "bundle-type" (- index 1)))))
        (parent-component-ids
         (if (= index 0)
             '()
             (list (fixture-id "bundle-component" (- index 1))))))
    (yuanxu-case-component
     (fixture-id "bundle-component" index)
     1
     (fixture-role index)
     (yuanxu-case-type-contract
      type-id parent-type-ids fixture-value?)
     '()
     '()
     (component-projections
      index runtime-count evidence-count duplicate-runtime-owner?)
     parent-component-ids)))

(def (runtime-capability index)
  (feature-adapter-capability
   (fixture-id "bundle-runtime-capability" index)
   'tao3k/yuanxu/python-runtime-cffi
   'yuanxu.runtime-c.bundle
   +feature-runtime-c-bundle-version+))

(def (evidence-capability index)
  (feature-adapter-capability
   (fixture-id "bundle-evidence-capability" index)
   'tao3k/yuanxu/lean-evidence-adapter
   'yuanxu.lean-evidence
   1))

(def duplicate-runtime-capability
  (feature-adapter-capability
   'bundle-runtime-capability-duplicate
   'tao3k/yuanxu/rust-runtime
   'yuanxu.runtime-c.bundle-duplicate
   1))

(def (runtime-requirement index)
  (feature-adapter-requirement
   (fixture-id "bundle-runtime-requirement" index)
   (fixture-id "bundle-runtime-capability" index)
   'yuanxu.runtime-c.bundle
   +feature-runtime-c-bundle-version+))

(def (evidence-requirement index)
  (feature-adapter-requirement
   (fixture-id "bundle-evidence-requirement" index)
   (fixture-id "bundle-evidence-capability" index)
   'yuanxu.lean-evidence
   1))

(def duplicate-runtime-requirement
  (feature-adapter-requirement
   'bundle-runtime-requirement-duplicate
   'bundle-runtime-capability-duplicate
   'yuanxu.runtime-c.bundle-duplicate
   1))

(def (runtime-request index)
  (feature-projection-request
   (fixture-id "bundle-runtime-request" index)
   (fixture-id "bundle-runtime-projection" index)
   (fixture-id "bundle-runtime-schema" index)))

(def (evidence-request index)
  (feature-projection-request
   (fixture-id "bundle-evidence-request" index)
   (fixture-id "bundle-evidence-projection" index)
   (fixture-id "bundle-evidence-schema" index)))

(def duplicate-runtime-request
  (feature-projection-request
   'bundle-runtime-request-duplicate
   'bundle-runtime-projection-duplicate
   'bundle-runtime-schema-duplicate))

(def (runtime-handoff index)
  (feature-runtime-bundle-handoff
   (fixture-id "bundle-runtime-handoff" index)
   (fixture-id "bundle-runtime-requirement" index)
   (fixture-id "bundle-runtime-request" index)
   'yuanxu.runtime-c.bundle
   +feature-runtime-c-bundle-version+
   (fixture-id "bundle-runtime-schema" index)))

(def (evidence-handoff index)
  (feature-evidence-obligation
   (fixture-id "bundle-evidence-obligation" index)
   (fixture-id "bundle-evidence-requirement" index)
   (fixture-id "bundle-evidence-request" index)
   'yuanxu.lean-evidence
   1
   (fixture-id "bundle-evidence-schema" index)))

(def duplicate-runtime-handoff
  (feature-runtime-bundle-handoff
   'bundle-runtime-handoff-duplicate
   'bundle-runtime-requirement-duplicate
   'bundle-runtime-request-duplicate
   'yuanxu.runtime-c.bundle-duplicate
   1
   'bundle-runtime-schema-duplicate))

(def (make-bundle-v1-domain-case-runtime-handoff-plan
      component-count runtime-count evidence-count duplicate-runtime-owner?)
  (let* ((component-indexes (iota component-count))
         (runtime-indexes (iota runtime-count))
         (evidence-indexes (iota evidence-count))
         (components
          (map
           (lambda (index)
             (case-component
              index runtime-count evidence-count duplicate-runtime-owner?))
           component-indexes))
         (capabilities
          (append
           (map runtime-capability runtime-indexes)
           (if duplicate-runtime-owner?
               (list duplicate-runtime-capability)
               '())
           (map evidence-capability evidence-indexes)))
         (requirements
          (append
           (map runtime-requirement runtime-indexes)
           (if duplicate-runtime-owner?
               (list duplicate-runtime-requirement)
               '())
           (map evidence-requirement evidence-indexes)))
         (requests
          (append
           (map runtime-request runtime-indexes)
           (if duplicate-runtime-owner?
               (list duplicate-runtime-request)
               '())
           (map evidence-request evidence-indexes)))
         (feature
          (feature-descriptor
           (feature-spec-compose
            (feature-descriptor-base
             'bundle-projection-feature
             'bundle-v1-domain-case-projection-fixture)
            (apply feature-components components)
            (apply feature-adapter-requirements requirements)
            (apply feature-projections requests))))
         (feature-bundle
          (feature-manifest-bundle
           'bundle-domain-case-feature-bundle (list feature)))
         (composition-plan
          (feature-composition-plan feature-bundle))
         (assembly
          (feature-domain-case-assembly
           (yuanxu-domain-case-cache)
           'bundle-domain-case
           1
           composition-plan))
         (policy-binding
          (feature-policy-strategy-binding assembly))
         (capability-catalog
          (feature-adapter-capability-catalog
           'bundle-domain-case-capabilities capabilities))
         (adapter-binding
          (feature-adapter-projection-binding
           capability-catalog policy-binding))
         (handoffs
          (append
           (map runtime-handoff runtime-indexes)
           (if duplicate-runtime-owner?
               (list duplicate-runtime-handoff)
               '())
           (map evidence-handoff evidence-indexes)))
         (handoff-manifest
          (feature-runtime-handoff-manifest
           'bundle-domain-case-handoffs handoffs)))
    (feature-runtime-handoff-plan adapter-binding handoff-manifest)))
