;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(export agentic-ai-lab-opentofu-cty->schema)

(def (nullable schema) `((anyOf . (((type . "null")) ,schema))))

;; cty is a different source format, not another JSON Schema evaluator.
(def (agentic-ai-lab-opentofu-cty->schema type)
  (cond
   ((member type '("string" "number" "bool"))
    `((type . ,(if (equal? type "bool") "boolean" type))))
   ((and (list? type) (= (length type) 2))
    (let ((kind (car type)) (child (cadr type)))
      (cond
       ((member kind '("list" "set"))
        `((type . "array") (items . ,(agentic-ai-lab-opentofu-cty->schema child))))
       ((equal? kind "map")
        `((type . "object") (additionalProperties . ,(agentic-ai-lab-opentofu-cty->schema child))))
       ((equal? kind "tuple")
        `((type . "array")
          (items . ,(if (null? child) #f (map agentic-ai-lab-opentofu-cty->schema child)))
          (minItems . ,(length child)) (maxItems . ,(length child))))
       ((equal? kind "object")
        `((type . "object") (additionalProperties . #f)
          (properties . ,(map (lambda (row)
                                (cons (car row) (nullable (agentic-ai-lab-opentofu-cty->schema (cdr row))))) child))))
       (else (error "unsupported cty constructor" type)))))
   (else (error "unsupported cty type" type))))
