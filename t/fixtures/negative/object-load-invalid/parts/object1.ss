;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :tao3k/yuanxu/module-system/schema/interface)
(export Objects)
(def Objects
(list
 (yuanxu-module-object
  'objects.fixture.invalid
  '()
  (list
   (yuanxu-module-field-contract
    'broken 'Unknown 'override #f '((scope . fixture))))
  '((namespace . objects.fixture)
    (domain . fixture))))
)
