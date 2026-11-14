;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object o?/slots .get .o .cc .def)
        (only-in :clan/poo/object-contract ObjectContract. diagnose refine)
        (only-in :clan/poo/mop define-type Type. Object Any)
        (only-in :tao3k/yuanxu/types/ports Port)
        (only-in :clan/poo/type List)
        (only-in :clan/poo/object-contract diagnostic-then)
        (only-in :std/list/list every)
        (only-in :tao3k/yuanxu/types/contracts YuanxuContract.)
        (only-in :tao3k/yuanxu/admission/source SourceAdmissionContract. source-diagnose-at)
        (only-in :tao3k/yuanxu/configuration/diagnostics config-diagnostic-locator))
(export ApplicationContract GiteaConfigContract GiteaScopeContract PostgreSQLScopeContract)
(def (gitea-value-contract Port)
  (.cc ObjectContract. identity: 'gitea/config-value
    responsibilities:
    (.o database: (.cc ObjectContract. responsibilities: (.o port: Port))
        allowed-ports: (List Port))))
(define-type (GiteaConfigContract @ YuanxuContract.)
  identity: 'gitea/config
  value-contract: (gitea-value-contract Port))
;; Root value validation owns normalization. Contextual descendants retain the
;; service classifiers/obligations and must admit that exact checked child.
(define-type (ConfigurationAdmission. @ YuanxuContract. database-contract)
  identity: 'gitea/configuration-context
  responsibilities:
  (.o postgresql: (.o (:: @ database-contract) value-contract: #f)
      gitea: (.o (:: @ GiteaConfigContract) value-contract: #f)))
;; These scope probes inspect names only, rather than normalizing lazy exports.
(define-type (PostgreSQLScopeContract @ Type.)
  identity: 'gitea/postgresql-dependency
  .element?:
  (lambda (value)
    (and ((o?/slots '(config types)) value)
         ((o?/slots '(port Config)) (.get value types)))))
(define-type (GiteaScopeContract @ Type.)
  identity: 'gitea/scope .element?: (o?/slots '(config document application types policy)))
(def (issue kind-value path-value actual-value)
  (.o kind: kind-value path: path-value actual: actual-value))
(def ApplicationEnvelope
  (.cc ObjectContract. responsibilities: (.o config: Object plan: Object)))
(def ConfigEnvelope
  (.cc ObjectContract. responsibilities: (.o postgresql: Object gitea: Object)))
(def (application-value-contract database-type client-type Port)
  (def config-type (.cc ObjectContract. responsibilities:
                    (.o postgresql: database-type gitea: client-type)))
  (def plan-type (.cc ObjectContract. responsibilities:
                  (.o configuration: Object
                      postgresql: (.cc ObjectContract. responsibilities: (.o port: Port))
                      gitea: (.cc ObjectContract. responsibilities: (.o database-port: Port)))))
  (refine (.cc ObjectContract. identity: 'gitea/application-value
            responsibilities: (.o config: config-type plan: plan-type))
          application-issues))
(def (application-issues candidate location)
  (def database (.get candidate config postgresql))
  (def client (.get candidate config gitea))
  (cond
     ((not (= (.get database settings port) (.get client database port)))
      (list (.cc (issue 'connection-mismatch (append location '(config gitea database port)) (.get client database port))
        expected: (.get database settings port)
        expected-path: (append location '(config postgresql settings port)))))
     ((not (and (eq? (.get candidate plan configuration) (.get candidate config))
                (= (.get candidate plan postgresql port) (.get database settings port))
                (= (.get candidate plan gitea database-port) (.get client database port))))
      (list (issue 'stale-parent-plan (append location '(plan)) (.get candidate plan))))
     (else '())))

(def (port-contributions requirement-type candidate rows _context)
  (def effective-port (.get candidate config postgresql settings port))
  (def constraint-values
    (map (lambda (row)
           (.o allowed-ports: (.get row payload allowed-ports)
               origin: (.get row origin)
               source-origin: (.get row payload origin)))
         rows))
  (def (satisfied? row)
    (let (ports (.get row allowed-ports))
      (and (null? (diagnose requirement-type row))
           (memv effective-port ports))))
  (if (every satisfied? constraint-values)
    '()
    (list (.o kind: 'unsatisfied-joint-port-requirements
              path: '(config postgresql settings port) actual: effective-port constraints: constraint-values))))
(.def (ApplicationContract @ SourceAdmissionContract. database-contract port-type documents
                            database-value-type client-value-type)
  source-inputs: (append (.get documents postgresql source-inputs) (.get documents gitea source-inputs))
  database-value-type: (.get database-contract value-contract)
  client-value-type: (gitea-value-contract port-type)
  ;; Dependency guards belong to contextual admission, not to the reusable
  ;; runtime value Type. Share its actual child Types and short-circuit before
  ;; forcing a client/plan that depends on invalid database settings.
  .preflight:
  (foldr diagnostic-then (lambda (_value _path) '())
    (list (cut diagnose ApplicationEnvelope <> <>)
          (source-diagnose-at ConfigEnvelope '(config))
          (source-diagnose-at database-value-type '(config postgresql))
          (source-diagnose-at client-value-type '(config gitea))))
  .locate-diagnostic: (config-diagnostic-locator documents '(config))
  identity: 'gitea/application
  value-contract:
  (application-value-contract database-value-type client-value-type port-type)
  responsibilities:
  (.o config: (.cc ConfigurationAdmission. database-contract: database-contract))
  requirement-type: (.cc ObjectContract. responsibilities:
                      (.o allowed-ports: (List port-type) origin: Any source-origin: Any))
  .contribution-obligations:
  (lambda (candidate rows context)
    (port-contributions requirement-type candidate rows context)))
