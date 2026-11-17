;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(export arm-terminal-cleanup!)
(extern namespace: #f arm-terminal-cleanup!)

(begin-foreign
  (c-declare #<<END-C
#include <dlfcn.h>

static int arm_terminal_cleanup(void)
{
    int (*arm)(void) = (int (*)(void))dlsym(RTLD_DEFAULT, "lab_arm_terminal_cleanup");
    return arm ? arm() : 0;
}
END-C
  )
  (define arm-terminal-cleanup! (c-lambda () int "arm_terminal_cleanup")))
