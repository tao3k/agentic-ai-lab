;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Official imports locate code; the domain Contract validates its values.
(import (only-in "./parts/object1" Objects)
        (only-in :tao3k/yuanxu/module-system/schema/validation yuanxu-require-module-objects-validation!))
(export ValidatedObjects)
(def ValidatedObjects (yuanxu-require-module-objects-validation! Objects))
