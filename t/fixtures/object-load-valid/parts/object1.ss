;;; -*- Gerbil -*-
;;; Boundary: included by ../objects.ss.
;;; This part is loaded through object practice macros, not package compile.
;;; The fixture proves valid included fragments keep their declared identity.

;;; This object is a valid load! fragment used to prove included object parts
;;; preserve field contracts and metadata.
;; : [AgenticAILabModuleObject]
(list
 (yuanxu-module-object
  'objects.fixture.loaded
  '()
  (list
   (yuanxu-module-field-contract
    'title YuanxuModuleStringType 'override "loaded" '((scope . fixture)))
   (yuanxu-module-field-contract
    'tags
    (yuanxu-module-list-type YuanxuModuleSymbolType)
    'append
    '()
    '((scope . fixture))))
  '((namespace . objects.fixture)
    (domain . fixture))))
