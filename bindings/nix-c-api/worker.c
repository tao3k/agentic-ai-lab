/* SPDX-FileCopyrightText: 2026 tao3k team and Contributors
 * SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
 * A product-owned serial evaluator process, not a daemon or compiler patch.
 */
#include <stdio.h>
#include "session.h"

int main(int argc, char **argv)
{
    if (argc != 3) return 64;
    FILE *file = fopen(argv[1], "rb");
    if (!file || fseek(file, 0, SEEK_END)) return 66;
    long size = ftell(file);
    if (size < 0 || size > 1024 * 1024 || fseek(file, 0, SEEK_SET)) return 65;
    char *expression = calloc((size_t)size + 1, 1);
    if (!expression || fread(expression, 1, (size_t)size, file) != (size_t)size) return 74;
    fclose(file);
    agentic_ai_lab_nix_session *s = agentic_ai_lab_nix_open(expression, argv[2]);
    free(expression);
    if (!s || s->error) {
        fprintf(stderr, "Nix C API initialization: %s\n", s ? s->error : "allocation failed");
        agentic_ai_lab_nix_close(s);
        return 70;
    }
    printf("READY %s\n", nix_version_get());
    fflush(stdout);
    char *input = NULL;
    size_t capacity = 0;
    ssize_t length;
    int status = 0;
    while ((length = getline(&input, &capacity, stdin)) >= 0) {
        if (length > 1024 * 1024) { status = 65; break; }
        if (length && input[length - 1] == '\n') input[length - 1] = 0;
        if (!agentic_ai_lab_nix_query(s, input)) {
            fprintf(stderr, "Nix C API evaluation: %s\n", s->error ? s->error : "allocation failed");
            status = 70;
            break;
        }
        puts(s->output);
        fflush(stdout);
    }
    free(input);
    agentic_ai_lab_nix_close(s);
    return status;
}
