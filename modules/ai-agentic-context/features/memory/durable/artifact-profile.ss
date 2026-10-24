;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable artifact profile objects and database profile objects.
;;; Invariant: this module returns POO-native objects and performs no runtime
;;; storage, database, artifact lifecycle, or Marlin handoff work.

(import (only-in :clan/poo/object .ref .slot? object? object<-alist))

(export +agentic-ai-lab-durable-artifact-profile-kind+
        +agentic-ai-lab-durable-artifact-profile-schema+
        +agentic-ai-lab-durable-artifact-database-profile-kind+
        +agentic-ai-lab-durable-artifact-database-profile-schema+
        agentic-ai-lab-artifact-profile
        agentic-ai-lab-artifact-database-profile
        agentic-ai-lab-artifact-profile-extend
        agentic-ai-lab-artifact-profile-override
        agentic-ai-lab-artifact-profile-apply-hooks
        agentic-ai-lab-artifact-profile->alist
        agentic-ai-lab-artifact-database-profile->alist
        agentic-ai-lab-artifact-profile?
        agentic-ai-lab-artifact-database-profile?
        agentic-ai-lab-artifact-scope-contained?
        agentic-ai-lab-artifact-publish-gated?
        agentic-ai-lab-artifact-alist-ref)

(def +agentic-ai-lab-durable-artifact-profile-kind+
  'agentic-ai-lab.durable.artifact.profile)

(def +agentic-ai-lab-durable-artifact-profile-schema+
  'agentic-ai-lab.durable.artifact.profile.v1)

(def +agentic-ai-lab-durable-artifact-database-profile-kind+
  'agentic-ai-lab.durable.artifact.database.profile)

(def +agentic-ai-lab-durable-artifact-database-profile-schema+
  'agentic-ai-lab.durable.artifact.database.profile.v1)

(def +agentic-ai-lab-artifact-profile-fields+
  '(artifact-profile-kind
    artifact-profile-schema
    name
    extends
    kind
    scope
    storage
    analysis
    publish
    retention
    lifecycle
    database
    hooks
    runtime-executed
    source))

(def +agentic-ai-lab-artifact-database-profile-fields+
  '(artifact-database-profile-kind
    artifact-database-profile-schema
    name
    extends
    classes
    capabilities
    storage
    source))

(def +agentic-ai-lab-artifact-section-slot-aliases+
  '((:extends . extends)
    (extends . extends)
    (:kind . kind)
    (kind . kind)
    (:scope . scope)
    (scope . scope)
    (:storage . storage)
    (storage . storage)
    (:analysis . analysis)
    (analysis . analysis)
    (:publish . publish)
    (publish . publish)
    (:retention . retention)
    (retention . retention)
    (:lifecycle . lifecycle)
    (lifecycle . lifecycle)
    (:database . database)
    (database . database)
    (:with . hooks)
    (with . hooks)
    (:classes . classes)
    (classes . classes)
    (:capabilities . capabilities)
    (capabilities . capabilities)))

;; agentic-ai-lab-artifact-section-slot
;; : (-> ArtifactSectionKey Symbol)
;; | doc m%
;;   Normalize artifact profile section keywords into stable object slots.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-artifact-section-slot ':publish)
;;   ;; => publish
;;   ```
(def (agentic-ai-lab-artifact-section-slot key)
  (let (entry (assq key +agentic-ai-lab-artifact-section-slot-aliases+))
    (if entry (cdr entry) key)))

;; : (-> [ArtifactSectionDatum] Alist)
(def (agentic-ai-lab-artifact-sections->alist sections)
  (match sections
    ([] '())
    ([key]
     (error "artifact profile section requires a value" key))
    ([key value . rest]
     (cons (cons (agentic-ai-lab-artifact-section-slot key) value)
           (agentic-ai-lab-artifact-sections->alist rest)))))

;; agentic-ai-lab-artifact-alist-ref
;; : (-> ArtifactFieldAlist Symbol Datum Datum)
;; | doc m%
;;   Read an artifact field from normalized section rows.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-artifact-alist-ref fields 'scope '())
;;   ;; => field value or default
;;   ```
(def (agentic-ai-lab-artifact-alist-ref alist key default-value)
  (let (entry (assoc key alist))
    (if entry (cdr entry) default-value)))

;; agentic-ai-lab-artifact-profile/direct
;; : (-> Symbol ArtifactExtends Symbol [Symbol] [Symbol] [Symbol] [Symbol] [Symbol] [Symbol] [Symbol] [(-> PooArtifactProfile PooArtifactProfile)] PooArtifactProfile)
;; | doc m%
;;   Build the POO-native artifact profile object from normalized slots.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-artifact-profile/direct 'report #f 'report '() '() '() '() '() '() '() '())
;;   ;; => artifact profile object
;;   ```
(def (agentic-ai-lab-artifact-profile/direct profile-name
                                       extends-value
                                       kind-value
                                       scope-value
                                       storage-value
                                       analysis-value
                                       publish-value
                                       retention-value
                                       lifecycle-value
                                       database-value
                                       hooks-value)
  (object<-alist
   (list
    (cons 'artifact-profile-kind +agentic-ai-lab-durable-artifact-profile-kind+)
    (cons 'artifact-profile-schema +agentic-ai-lab-durable-artifact-profile-schema+)
    (cons 'name profile-name)
    (cons 'extends extends-value)
    (cons 'kind kind-value)
    (cons 'scope scope-value)
    (cons 'storage storage-value)
    (cons 'analysis analysis-value)
    (cons 'publish publish-value)
    (cons 'retention retention-value)
    (cons 'lifecycle lifecycle-value)
    (cons 'database database-value)
    (cons 'hooks hooks-value)
    (cons 'runtime-executed #f)
    (cons 'source 'agentic-ai-lab.durable.artifact.policy))))

;; agentic-ai-lab-artifact-database-profile/direct
;; : (-> Symbol ArtifactExtends [Symbol] [Symbol] [Symbol] PooArtifactDatabaseProfile)
;; | doc m%
;;   Build the POO-native artifact database profile object from normalized slots.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-artifact-database-profile/direct 'turso #f '(sqlite) '(kv) '(file))
;;   ;; => artifact database profile object
;;   ```
(def (agentic-ai-lab-artifact-database-profile/direct profile-name
                                                extends-value
                                                classes-value
                                                capabilities-value
                                                storage-value)
  (object<-alist
   (list
    (cons 'artifact-database-profile-kind
          +agentic-ai-lab-durable-artifact-database-profile-kind+)
    (cons 'artifact-database-profile-schema
          +agentic-ai-lab-durable-artifact-database-profile-schema+)
    (cons 'name profile-name)
    (cons 'extends extends-value)
    (cons 'classes classes-value)
    (cons 'capabilities capabilities-value)
    (cons 'storage storage-value)
    (cons 'source 'agentic-ai-lab.durable.artifact.database))))

;; agentic-ai-lab-artifact-profile-from-alist
;; : (-> Symbol ArtifactFieldAlist PooArtifactProfile)
;; | doc m%
;;   Fill artifact profile defaults from normalized section rows.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-artifact-profile-from-alist 'report fields)
;;   ;; => artifact profile object
;;   ```
(def (agentic-ai-lab-artifact-profile-from-alist profile-name fields)
  (agentic-ai-lab-artifact-profile/direct
   profile-name
   (agentic-ai-lab-artifact-alist-ref fields 'extends #f)
   (agentic-ai-lab-artifact-alist-ref fields 'kind profile-name)
   (agentic-ai-lab-artifact-alist-ref fields 'scope '())
   (agentic-ai-lab-artifact-alist-ref fields 'storage '())
   (agentic-ai-lab-artifact-alist-ref fields 'analysis '())
   (agentic-ai-lab-artifact-alist-ref fields 'publish '())
   (agentic-ai-lab-artifact-alist-ref fields 'retention '())
   (agentic-ai-lab-artifact-alist-ref fields 'lifecycle '(created stored retained))
   (agentic-ai-lab-artifact-alist-ref fields 'database '())
   (agentic-ai-lab-artifact-alist-ref fields 'hooks '())))

;; agentic-ai-lab-artifact-database-profile-from-alist
;; : (-> Symbol ArtifactFieldAlist PooArtifactDatabaseProfile)
;; | doc m%
;;   Fill database profile defaults from normalized section rows.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-artifact-database-profile-from-alist 'turso fields)
;;   ;; => artifact database profile object
;;   ```
(def (agentic-ai-lab-artifact-database-profile-from-alist profile-name fields)
  (agentic-ai-lab-artifact-database-profile/direct
   profile-name
   (agentic-ai-lab-artifact-alist-ref fields 'extends #f)
   (agentic-ai-lab-artifact-alist-ref fields 'classes '())
   (agentic-ai-lab-artifact-alist-ref fields 'capabilities '())
   (agentic-ai-lab-artifact-alist-ref fields 'storage '())))

;; agentic-ai-lab-artifact-profile
;; : (-> Symbol [ArtifactSectionDatum] PooArtifactProfile)
;; | doc m%
;;   Parse section syntax data and return a reusable POO artifact profile.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-artifact-profile 'report '(:scope (session)))
;;   ;; => artifact profile object
;;   ```
(def (agentic-ai-lab-artifact-profile name sections)
  (agentic-ai-lab-artifact-profile-from-alist
   name
   (agentic-ai-lab-artifact-sections->alist sections)))

;; agentic-ai-lab-artifact-database-profile
;; : (-> Symbol [ArtifactSectionDatum] PooArtifactDatabaseProfile)
;; | doc m%
;;   Parse section syntax data and return a reusable POO database profile.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-artifact-database-profile 'turso '(:storage (file)))
;;   ;; => artifact database profile object
;;   ```
(def (agentic-ai-lab-artifact-database-profile name sections)
  (agentic-ai-lab-artifact-database-profile-from-alist
   name
   (agentic-ai-lab-artifact-sections->alist sections)))

;; : (forall (v) (-> v [(Pair Symbol Object)]))
;; : (-> PooArtifactProfile Alist)
(def (agentic-ai-lab-artifact-profile->alist profile)
  (map (lambda (field) (cons field (.ref profile field)))
       +agentic-ai-lab-artifact-profile-fields+))

;; : (forall (v) (-> v [(Pair Symbol Object)]))
;; : (-> PooArtifactDatabaseProfile Alist)
(def (agentic-ai-lab-artifact-database-profile->alist profile)
  (map (lambda (field) (cons field (.ref profile field)))
       +agentic-ai-lab-artifact-database-profile-fields+))

;; : (-> PooArtifactProfile Symbol Datum Datum)
(def (agentic-ai-lab-artifact-object-ref/default object field default)
  (if (.slot? object field)
    (.ref object field)
    default))

;; : (-> Symbol PooArtifactProfile PooArtifactProfile PooArtifactProfile)
(def (agentic-ai-lab-artifact-profile-override profile-name base override)
  (agentic-ai-lab-artifact-profile/direct
   profile-name
   (agentic-ai-lab-artifact-object-ref/default override 'extends (.ref base 'extends))
   (agentic-ai-lab-artifact-object-ref/default override 'kind (.ref base 'kind))
   (agentic-ai-lab-artifact-object-ref/default override 'scope (.ref base 'scope))
   (agentic-ai-lab-artifact-object-ref/default override 'storage (.ref base 'storage))
   (agentic-ai-lab-artifact-object-ref/default override 'analysis (.ref base 'analysis))
   (agentic-ai-lab-artifact-object-ref/default override 'publish (.ref base 'publish))
   (agentic-ai-lab-artifact-object-ref/default override 'retention (.ref base 'retention))
   (agentic-ai-lab-artifact-object-ref/default override 'lifecycle (.ref base 'lifecycle))
   (agentic-ai-lab-artifact-object-ref/default override 'database (.ref base 'database))
   (agentic-ai-lab-artifact-object-ref/default override 'hooks (.ref base 'hooks))))

;; : (-> Symbol PooArtifactProfile PooArtifactProfile PooArtifactProfile)
(def (agentic-ai-lab-artifact-profile-extend name base override)
  (agentic-ai-lab-artifact-profile-override name base override))

;; : (-> PooArtifactProfile [(-> PooArtifactProfile PooArtifactProfile)] PooArtifactProfile)
(def (agentic-ai-lab-artifact-profile-apply-hooks profile hooks)
  (foldl (lambda (hook current) (hook current))
         profile
         hooks))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-artifact-profile? profile)
  (and (object? profile)
       (.slot? profile 'artifact-profile-kind)
       (eq? (.ref profile 'artifact-profile-kind)
            +agentic-ai-lab-durable-artifact-profile-kind+)))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-artifact-database-profile? profile)
  (and (object? profile)
       (.slot? profile 'artifact-database-profile-kind)
       (eq? (.ref profile 'artifact-database-profile-kind)
            +agentic-ai-lab-durable-artifact-database-profile-kind+)))

;; : (-> PooArtifactProfile [Symbol] Boolean)
(def (agentic-ai-lab-artifact-scope-contained? profile required-scope)
  (let (scope (.ref profile 'scope))
    (andmap (lambda (scope-id) (memq scope-id scope)) required-scope)))

;; : (-> PooArtifactProfile Boolean)
(def (agentic-ai-lab-artifact-publish-gated? profile)
  (let (publish (.ref profile 'publish))
    (or (null? publish)
        (and (memq 'human-approved publish)
             (memq 'proof-gated publish)
             #t))))
