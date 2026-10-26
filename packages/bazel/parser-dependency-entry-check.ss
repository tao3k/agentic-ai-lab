;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Qualification of explicit dependency API roots, not an import expander.
(export main)
(def (dependency-imports datum (prefix ":gerbil-parser/"))
  (cond
   ((not (pair? datum)) '())
   ((memq (car datum) '(quote quasiquote syntax quasisyntax)) '())
   ((eq? (car datum) 'import)
    (let collect ((item (cdr datum)))
      (cond
       ((symbol? item)
        (let (name (symbol->string item))
          (if (string-prefix? prefix name)
            (list (string-append (substring name (string-length prefix) (string-length name)) ".ss")) '())))
       ((pair? item) (append (collect (car item)) (collect (cdr item))))
       (else '()))))
   (else (append (dependency-imports (car datum) prefix) (dependency-imports (cdr datum) prefix)))))
(def (source-files directory)
  (apply append
   (map (lambda (name)
          (let (path (path-expand name directory))
            (cond
             ((member name '("t" "tests" "benchmarks" "target" ".git" ".gerbil" ".data")) '())
             ((eq? (file-info-type (file-info path)) 'directory) (source-files path))
             ((string=? (path-extension path) ".ss") (list path))
             (else '()))))
        (directory-files directory))))
(def (declared-entries forms)
  (let walk ((datum forms))
    (cond
     ((not (pair? datum)) #f)
     ((and (eq? (car datum) 'def) (pair? (cdr datum))
           (eq? (cadr datum) 'public-entry-modules))
      (match datum
        (['def 'public-entry-modules ['quote entries]] entries)
        (else (error "expected literal native PackageSpec entries" datum))))
     (else (or (walk (car datum)) (walk (cdr datum)))))))
(def (require-coverage entries required owner)
  (for-each (lambda (entry)
              (unless (member entry entries)
                (error "dependency profile omits a consumed API" owner entry))) required))
(def (main generated-entry consumer-build dependency-build product-package
           (prefix ":gerbil-parser/"))
  (let* ((entries (declared-entries (call-with-input-file generated-entry read-all)))
         (dependency-root (path-directory dependency-build))
         (product-root (path-directory product-package))
         (sources (append (if (string=? consumer-build "-") '()
                       (source-files (path-directory consumer-build)))
                          (source-files (path-expand "modules" product-root))
                          (source-files (path-expand "user-interface" product-root))))
         (required-count 0))
    (unless (and (pair? entries) (andmap string? entries)) (error "missing native API roots" entries))
    (for-each (lambda (entry)
                (unless (file-exists? (path-expand entry dependency-root))
                  (error "dependency API root does not exist in the pinned source" entry))) entries)
    (for-each
     (lambda (source)
       (let (required (dependency-imports (call-with-input-file source read-all) prefix))
         (require-coverage entries required source)
         (set! required-count (+ required-count (length required))))) sources)
    ;; Matched controls: phase imports count; quoted sample code does not.
    (unless (equal? (dependency-imports `(import (for-syntax ,(string->symbol
                        (string-append prefix "phase-api")))) prefix)
                    '("phase-api.ss")) (error "phase import control failed"))
    (unless (null? (dependency-imports `(quote (import ,(string->symbol
                        (string-append prefix "unrequested")))) prefix))
      (error "quoted source control failed"))
    (unless (with-catch (lambda (_error) #t)
              (lambda () (require-coverage entries '("not-a-declared-api.ss") 'negative-control) #f))
      (error "missing API negative control failed"))
    (displayln "Dependency API coverage: " (length entries) " roots, "
               required-count " import references; phase/negative controls passed")))
