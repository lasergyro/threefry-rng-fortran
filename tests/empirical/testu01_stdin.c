/*
 * Runs a TestU01 battery (SmallCrush, Crush or BigCrush) on 32-bit words read
 * from standard input, so threefry_dump can be piped straight in with nothing
 * written to disk -- the same streaming setup as PractRand in
 * run_empirical_tests.sh. TestU01 has no stdin generator of its own; this
 * registers one as an "external generator" returning 32 bits per call.
 *
 * Usage: threefry_dump <nbytes> - [counter|key] [nrounds] | testu01_stdin <small|crush|big> [name]
 *
 * Words are read in the byte order threefry_dump writes them (native),
 * matching PractRand's stdin32.
 * Running out of input before the battery finishes is an error, not a pass.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "unif01.h"
#include "bbattery.h"

#define BUFWORDS (1 << 20)

static uint32_t buf[BUFWORDS];
static size_t nbuf = 0, pos = 0;

static unsigned int next_word(void)
{
    if (pos == nbuf) {
        nbuf = fread(buf, sizeof buf[0], BUFWORDS, stdin);
        pos = 0;
        if (nbuf == 0) {
            fprintf(stderr, "testu01_stdin: input ended before the battery finished\n");
            exit(1);
        }
    }
    return buf[pos++];
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: testu01_stdin <small|crush|big> [name]\n");
        return 2;
    }
    char *name = argc > 2 ? argv[2] : "stdin";
    unif01_Gen *gen = unif01_CreateExternGenBits(name, next_word);

    if (strcmp(argv[1], "small") == 0)
        bbattery_SmallCrush(gen);
    else if (strcmp(argv[1], "crush") == 0)
        bbattery_Crush(gen);
    else if (strcmp(argv[1], "big") == 0)
        bbattery_BigCrush(gen);
    else {
        fprintf(stderr, "testu01_stdin: unknown battery '%s'\n", argv[1]);
        return 2;
    }

    unif01_DeleteExternGenBits(gen);
    return 0;
}
