;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :clan/poo/object
        :tao3k/yuanxu/module-system/feature/bundle-v1-lowering
        :tao3k/yuanxu/module-system/feature/bundle-v1-foreign-arena)

(def (required-output-path variable)
  (let (path (getenv variable))
    (unless (and path (> (string-length path) 0))
      (error "Bundle v1 fixture output path is required" variable))
    path))

(def (write-u8vector-file! path bytes)
  (let (port (open-output-file (list path: path)))
    (unwind-protect
      (let (written
            (write-subu8vector bytes 0 (u8vector-length bytes) port))
        (unless (= written (u8vector-length bytes))
          (error "Incomplete Bundle v1 fixture write"
                 path written (u8vector-length bytes))))
      (close-output-port port))))

(def (fixture-lowering-plan)
  (feature-bundle-v1-lowering/with-symbols
   'bundle-v1-scheme-c-fixture
   73
   (list
    (feature-bundle-v1-symbol 'component 'component-b "Component B" 1)
    (feature-bundle-v1-symbol 'component 'component-a "Component A" 1))
   (list
    (feature-bundle-v1-component
     'case-a 'component-b 'object-b 'type-a 'contract-a 'role-b
     'capability-a 'policy-a 'strategy-a 'adapter-a 'projection-a 1)
    (feature-bundle-v1-component
     'case-a 'component-a 'object-a 'type-a 'contract-a 'role-a
     'capability-a 'policy-a 'strategy-a 'adapter-a 'projection-a 0))
   (list
    (feature-bundle-v1-edge
     'case-a 'component-b 'component-a 'component-parent 1))
   (list
    (feature-bundle-v1-evidence
     'case-a 'obligation-a 'contract-a 'evidence-a 'lean-a 0))))

(def (write-fixture!)
  (let* ((descriptor-path
          (required-output-path "YUANXU_BUNDLE_V1_DESCRIPTOR_OUT"))
         (arena-path
          (required-output-path "YUANXU_BUNDLE_V1_ARENA_OUT"))
         (image
          (require-feature-bundle-v1-foreign-arena-image
           (feature-bundle-v1-write-foreign-arena
            (fixture-lowering-plan))))
         (descriptor-image (.ref image 'descriptor-image))
         (arena-image (.ref image 'arena-image)))
    (write-u8vector-file! descriptor-path descriptor-image)
    (write-u8vector-file! arena-path arena-image)
    (display "schema=yuanxu.bundle-v1.scheme-c-fixture.1\n")
    (display "descriptor-bytes=")
    (display (u8vector-length descriptor-image))
    (newline)
    (display "arena-bytes=")
    (display (u8vector-length arena-image))
    (newline)
    (display "encoding=runtime-packed-little-endian\n")))

(write-fixture!)
