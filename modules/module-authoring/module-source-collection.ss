;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO Flow source collections for maintained, contributor,
;;; and user module trees. Selection declarations remain separate POO values.

(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list any filter)
        (only-in :core/utilities/algorithms
                 poo-flow-directory-files-recursive)
        :core/module-system/loader/load-path
        (only-in :poo-flow/modules/module-authoring/import-policy
                 poo-flow-module-owner-import-file-observations)
        (only-in :poo-flow/modules/module-authoring/module-interface
                 poo-flow-module-interface)
        (only-in :poo-flow/modules/module-authoring/module-source-admission
                 poo-flow-module-authoring-admit-port
                 poo-flow-module-authoring-admission-accepted?
                 poo-flow-module-authoring-admission-diagnostics)
        (only-in :poo-flow/modules/module-authoring/semantic-module
                 poo-flow-default-module-authoring-profile)
        :poo-flow/modules/module-authoring/module-imports
        :core/module-system/source/objects)

(export poo-flow-module-source-collection-prototype
        make-poo-flow-module-source-collection
        poo-flow-module-source-collection?
        poo-flow-module-source-collection-identity
        poo-flow-module-source-collection-owner
        poo-flow-module-source-collection-source-root
        poo-flow-module-source-collection-modules-directory
        poo-flow-module-source-collection-modules-root
        poo-flow-module-source-collection-locate
        poo-flow-module-style-policy-prototype
        poo-flow-default-module-style-policy
        poo-flow-module-required-role-files
        poo-flow-module-allowed-entrypoint-roles
        poo-flow-module-source-collection-validate!
        poo-flow-module-source-collection-role-entrypoints
        poo-flow-load-modules
        poo-flow-module-load-path-prototype
        make-poo-flow-module-load-path
        extend-poo-flow-module-load-path
        poo-flow-module-load-path?
        poo-flow-module-load-path-identity
        poo-flow-module-load-path-collections
        poo-flow-module-load-path-locate
        make-poo-flow-contribution-module-source
        make-poo-flow-contribution-root-module-source
        make-poo-flow-contribution-module-load-path
        make-poo-flow-user-interface-module-source
        make-poo-flow-user-interface-module-load-path
        poo-flow-maintained-module-source
        poo-flow-default-module-load-path)

(def (nonempty-string? value)
  (and (string? value) (> (string-length value) 0)))

(def (poo-flow-product-module-source-collection? value)
  (and (poo-flow-module-source-collection? value)
       (every (lambda (slot) (.slot? value slot))
              '(owner source-root modules-directory style-policy))
       (symbol? (.ref value 'owner))
       (nonempty-string? (.ref value 'source-root))
       (nonempty-string? (.ref value 'modules-directory))
       (object? (.ref value 'style-policy))
       (.slot? (.ref value 'style-policy) 'validate)
       (procedure? (.ref (.ref value 'style-policy) 'validate))
       (procedure? (.ref value 'locate))))

(def (poo-flow-module-source-collection-owner collection)
  (.ref collection 'owner))

(def (poo-flow-module-source-collection-source-root collection)
  (.ref collection 'source-root))

(def (poo-flow-module-source-collection-modules-directory collection)
  (.ref collection 'modules-directory))

(def (poo-flow-module-source-collection-modules-root collection)
  (let ((source-root
         (poo-flow-module-source-collection-source-root collection))
        (modules-directory
         (poo-flow-module-source-collection-modules-directory collection)))
    (if (string=? source-root ".")
      modules-directory
      (path-expand modules-directory source-root))))

(def (poo-flow-module-source-entrypoint collection module-key module-root
                                         entrypoint-role)
  (let (entrypoint
        (path-expand (string-append (symbol->string entrypoint-role) ".ss")
                     module-root))
    (make-poo-flow-module-source-ref
     'local entrypoint
     (list (cons 'kind 'module-tree)
           (cons 'module-key module-key)
           (cons 'source-collection
                 (poo-flow-module-source-collection-identity collection))
           (cons 'source-owner
                 (poo-flow-module-source-collection-owner collection))
           (cons 'module-layout 'poo-flow-module-v1)
           (cons 'required-roles poo-flow-module-required-role-files)
           (cons 'module-tree-root module-root)
           (cons 'entrypoint entrypoint)
           (cons 'entrypoint-role entrypoint-role)))))

;;; Categories stay in module identity. Current POO Flow collections use the
;;; flat <modules-root>/<module-name> repository convention.
(def (poo-flow-module-source-collection-default-locate collection module-key
                                                       entrypoint-roles)
  (let (module-name (cdr module-key))
    (if (eq? module-name
             (poo-flow-module-source-collection-identity collection))
      (poo-flow-module-source-collection-role-entrypoints
       collection 'interface)
      (let* ((module-root
              (path-expand
               (symbol->string module-name)
               (poo-flow-module-source-collection-modules-root collection)))
             (interface-path (path-expand "interface.ss" module-root)))
        (if (file-exists? interface-path)
          (map (lambda (entrypoint-role)
                 (poo-flow-module-source-entrypoint
                  collection module-key module-root entrypoint-role))
               entrypoint-roles)
          '())))))

;;; poo-flow-load-modules discovery is independent from User Interface enablement.
;;; Each direct modules/<module-name>/ directory contributes one conventional
;;; entrypoint; no contributor-owned init list or registry is involved.
(def poo-flow-module-required-role-files
  '("interface.ss"))

;;; The loader constrains stable module roles while leaving domain authors free
;;; to add focused implementation files. syntax.ss is optional and may expose
;;; thin hygienic projections; it is never required for data-only modules.
(def poo-flow-module-allowed-entrypoint-roles
  '(types objects funs config interface syntax))

;;; Style policy constrains the stable module shell and dependency direction.
;;; Domain code remains free to choose gerbil-poo Type/MOP, POO CLOS, native
;;; Gerbil methods, functional combinators, and thin hygienic syntax according
;;; to the semantics it actually needs.
(def (poo-flow-module-read-datums path)
  (call-with-input-file path read-all))

(def (poo-flow-module-role-reference? datum module-name role)
  (let ((leaf (string-append role ".ss"))
        (relative (string-append "./" role))
        (suffix (string-append "/" module-name "/" role)))
    (cond
     ((symbol? datum)
      (let (reference (symbol->string datum))
        (or (string=? reference relative)
            (string-suffix? suffix reference))))
     ((string? datum)
      (or (string=? datum leaf) (string-suffix? suffix datum)))
     ((pair? datum)
      (or (poo-flow-module-role-reference? (car datum) module-name role)
          (poo-flow-module-role-reference? (cdr datum) module-name role)))
     ((vector? datum)
      (poo-flow-module-role-reference? (vector->list datum) module-name role))
     (else #f))))

(def (poo-flow-module-top-form-references-role? datums head module-name role)
  (and (any (lambda (form)
              (and (pair? form)
                   (eq? (car form) head)
                   (poo-flow-module-role-reference?
                    (cdr form) module-name role)))
            datums)
       #t))

(def (poo-flow-module-interface-validate! module-name module-root)
  (let* ((interface-path (path-expand "interface.ss" module-root))
         (datums (poo-flow-module-read-datums interface-path))
         (public-roles
          (filter
           (lambda (role)
             (file-exists?
              (path-expand
               (string-append (symbol->string role) ".ss") module-root)))
           '(types objects funs config syntax))))
    (for-each
     (lambda (role)
       (unless (and (poo-flow-module-top-form-references-role?
                     datums 'import module-name (symbol->string role))
                    (poo-flow-module-top-form-references-role?
                     datums 'export module-name (symbol->string role)))
         (error "POO-FLOW-MODULE-E006 interface must import and re-export role"
                module-name role)))
     public-roles)))

(def (poo-flow-module-dependency-direction-validate! module-name module-root)
  (let ((layers '((types objects funs syntax config interface)
                  (objects funs syntax config interface)
                  (funs config interface)
                  (syntax config interface)
                  (config interface))))
    (for-each
     (lambda (layer)
       (let* ((source-role (car layer))
              (path (path-expand
                     (string-append (symbol->string source-role) ".ss")
                     module-root)))
         (when (file-exists? path)
           (let (datums (poo-flow-module-read-datums path))
             (for-each
              (lambda (forbidden-role)
                (when (poo-flow-module-top-form-references-role?
                       datums 'import module-name
                       (symbol->string forbidden-role))
                  (error "POO-FLOW-MODULE-E007 reversed module role dependency"
                         module-name source-role forbidden-role)))
              (cdr layer))))))
     layers)))

(def (poo-flow-module-owner-imports-validate! module-name module-root)
  (for-each
   (lambda (path)
     (let (observations
           (poo-flow-module-owner-import-file-observations
            (string->symbol path) path))
       (when (pair? observations)
         (error "POO-FLOW-MODULE-E008 module owner imports aggregate facade"
                module-name path (car observations)))))
   (filter (lambda (path) (string-suffix? ".ss" path))
           (poo-flow-directory-files-recursive module-root))))

;;; The loader applies the Interface-owned authoring Profile to each stable
;;; role before exposing any entrypoint.  Admission reads inert datums only;
;;; it neither expands nor evaluates module source.
(def (poo-flow-module-role-authoring-validate! collection module-name
                                                 module-root)
  (let* ((style-policy (.ref collection 'style-policy))
         (authoring (.ref style-policy 'authoring))
         (interface
          (poo-flow-module-interface
           module-name (.o)
           (list (cons 'source-owner
                       (poo-flow-module-source-collection-owner collection)))
           authoring: authoring)))
    (for-each
     (lambda (role)
       (let* ((path
               (path-expand
                (string-append (symbol->string role) ".ss") module-root))
              (admission
               (call-with-input-file
                path
                (lambda (port)
                  (poo-flow-module-authoring-admit-port
                   interface role port)))))
         (unless (poo-flow-module-authoring-admission-accepted? admission)
           (error "POO-FLOW-MODULE-E009 role violates Interface authoring Contract"
                  module-name role path
                  (car (poo-flow-module-authoring-admission-diagnostics
                        admission))))))
     (filter
      (lambda (role)
        (file-exists?
         (path-expand
          (string-append (symbol->string role) ".ss") module-root)))
      '(types objects funs config interface)))))

(def (poo-flow-module-default-style-validate! collection module-name module-root)
  (when (file-exists? (path-expand "init.ss" module-root))
    (error "POO-FLOW-MODULE-E005 init.ss belongs to the User Interface root"
           module-name))
  (poo-flow-module-interface-validate! module-name module-root)
  (poo-flow-module-dependency-direction-validate! module-name module-root)
  (poo-flow-module-owner-imports-validate! module-name module-root)
  (poo-flow-module-role-authoring-validate! collection module-name module-root)
  module-root)

(def poo-flow-module-style-policy-prototype
  (.o (module-style-policy? #t)
      (authoring (poo-flow-default-module-authoring-profile))
      (validate poo-flow-module-default-style-validate!)))

(def poo-flow-default-module-style-policy
  (.o (:: @ poo-flow-module-style-policy-prototype)))

(def (poo-flow-module-source-collection-directory-names collection)
  (let (modules-root
        (poo-flow-module-source-collection-modules-root collection))
    (if (file-exists? modules-root)
      (let (module-names
          (filter
           (lambda (name)
             (eq? (file-info-type
                   (file-info (path-expand name modules-root)))
                  'directory))
           (list-sort string<? (directory-files modules-root))))
        module-names)
      '())))

(def (poo-flow-module-source-collection-validate-directory-names!
      collection module-names)
  (let (modules-root
        (poo-flow-module-source-collection-modules-root collection))
    (for-each
     (lambda (module-name)
       (let* ((module-root (path-expand module-name modules-root))
              (missing
               (filter
                (lambda (role)
                  (not (file-exists? (path-expand role module-root))))
                poo-flow-module-required-role-files)))
         (unless (null? missing)
           (error "POO-FLOW-MODULE-E001 module is missing required roles"
                  module-name missing))
         ((.ref (.ref collection 'style-policy) 'validate)
          collection module-name module-root)))
     module-names))
  collection)

(def (poo-flow-module-entrypoint-role-valid! entrypoint-role)
  (unless (memq entrypoint-role poo-flow-module-allowed-entrypoint-roles)
    (error "POO-FLOW-MODULE-E002 unsupported module entrypoint role"
           entrypoint-role poo-flow-module-allowed-entrypoint-roles))
  entrypoint-role)

(def (poo-flow-module-source-collection-validate! collection)
  (poo-flow-module-source-collection-validate-directory-names!
   collection
   (poo-flow-module-source-collection-directory-names collection)))

(def (poo-flow-module-source-collection-role-entrypoints collection
                                                         entrypoint-role)
  (unless (poo-flow-product-module-source-collection? collection)
    (error "POO-FLOW-MODULE-E003 invalid module source collection" collection))
  (poo-flow-module-entrypoint-role-valid! entrypoint-role)
  (let* ((modules-root
          (poo-flow-module-source-collection-modules-root collection))
         (module-names
          (poo-flow-module-source-collection-directory-names collection)))
    (poo-flow-module-source-collection-validate-directory-names!
     collection module-names)
    (map
     (lambda (name)
       (let* ((module-root (path-expand name modules-root))
              (entrypoint
               (path-expand (string-append (symbol->string entrypoint-role) ".ss")
                            module-root)))
         (unless (file-exists? entrypoint)
           (error "POO-FLOW-MODULE-E004 requested optional role is absent"
                  name entrypoint-role))
         (poo-flow-module-source-entrypoint
          collection
          (cons 'custom (string->symbol name))
          module-root
          entrypoint-role)))
     module-names)))

;;; A module collection has one public entrypoint. The hygienic form accepts
;;; exactly one collection expression and lowers to the POO source projection;
;;; callers cannot turn public loading into a role or build-topology selector.
(defrules poo-flow-load-modules ()
  ((_ collection)
   (poo-flow-module-source-collection-role-entrypoints
    collection 'interface)))

(def (make-poo-flow-module-source-collection identity-value owner-value
                                              source-root-value
                                              modules-directory-value)
  (let (collection
        (.o (:: @ poo-flow-module-source-collection-prototype)
            (identity identity-value)
            (owner owner-value)
            (source-root source-root-value)
            (modules-directory modules-directory-value)
            (style-policy poo-flow-default-module-style-policy)
            (locate poo-flow-module-source-collection-default-locate)))
    (unless (poo-flow-product-module-source-collection? collection)
      (error "invalid POO Flow module source collection" collection))
    collection))

(def poo-flow-maintained-module-source
  (make-poo-flow-module-source-collection
   'poo-flow-maintained 'poo-flow "." "modules"))

;;; Repository-specific source paths are inputs to this core-owned loader
;;; policy; contributor repositories do not publish their own source objects.
(def (make-poo-flow-contribution-module-source identity-value source-root-value)
  (make-poo-flow-module-source-collection
   identity-value 'contributor source-root-value "modules"))

;;; A contribution root is an on-demand projection over checked-out package
;;; directories.  The selected module identity chooses packages/<identity>;
;;; no contributor name, URL, or revision is registered in Scheme.
(def (poo-flow-contribution-root-locate collection module-key entrypoint-roles)
  (let* ((identity (cdr module-key))
         (source-root
          (path-expand
           (symbol->string identity)
           (poo-flow-module-source-collection-source-root collection)))
         (contribution
          (make-poo-flow-contribution-module-source identity source-root)))
    (if (file-exists?
         (poo-flow-module-source-collection-modules-root contribution))
      ;; std/list/list append-map reverses each produced list.  Entrypoint order
      ;; is part of the loader contract, so flatten the bounded role projection
      ;; with native map/apply/append and preserve both role and module order.
      (apply append
             (map (lambda (entrypoint-role)
                    (poo-flow-module-source-collection-role-entrypoints
                     contribution entrypoint-role))
                  entrypoint-roles))
      '())))

(def (make-poo-flow-contribution-root-module-source identity-value
                                                     source-root-value)
  (.o (:: @ poo-flow-module-source-collection-prototype)
      (identity identity-value)
      (owner 'contributor)
      (source-root source-root-value)
      (modules-directory ".")
      (style-policy poo-flow-default-module-style-policy)
      (locate poo-flow-contribution-root-locate)))

(def (make-poo-flow-contribution-module-load-path identity-value
                                                  source-root-value)
  ;; A selected contribution owns its module names. Its source must win a
  ;; collision with a maintained module of the same name.
  (make-poo-flow-module-load-path
   identity-value
   (cons (make-poo-flow-contribution-module-source
          identity-value source-root-value)
         (poo-flow-module-load-path-collections
          poo-flow-default-module-load-path))))

(def (make-poo-flow-user-interface-module-source identity-value
                                                  user-interface-root-value)
  (make-poo-flow-module-source-collection
   identity-value 'user user-interface-root-value "modules"))

(def (make-poo-flow-user-interface-module-load-path identity-value
                                                     user-interface-root-value
                                                     base-load-path)
  (make-poo-flow-module-load-path
   identity-value
   (cons
    (make-poo-flow-user-interface-module-source
     identity-value user-interface-root-value)
    (poo-flow-module-load-path-collections base-load-path))))

(def poo-flow-default-module-load-path
  (make-poo-flow-module-load-path
   'poo-flow-default
   (list poo-flow-maintained-module-source)))
