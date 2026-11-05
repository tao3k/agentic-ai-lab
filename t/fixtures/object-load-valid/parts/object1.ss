;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :yuanxu/module-system/schema/interface)
(export Objects)
(def Objects
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
)
