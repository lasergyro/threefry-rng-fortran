/* Measures the CPU clock in GHz from a chain of dependent integer adds,
 * each of which takes exactly one cycle, so that tests/bench can report
 * cycles as well as nanoseconds. Used by run_bench.sh. */
#include <stdio.h>
#include <time.h>

#if defined(__aarch64__)
#define ADD8 "add %0,%0,#1\n add %0,%0,#1\n add %0,%0,#1\n add %0,%0,#1\n" \
             "add %0,%0,#1\n add %0,%0,#1\n add %0,%0,#1\n add %0,%0,#1"
#elif defined(__x86_64__)
#define ADD8 "add $1,%0\n add $1,%0\n add $1,%0\n add $1,%0\n" \
             "add $1,%0\n add $1,%0\n add $1,%0\n add $1,%0"
#else
#error "clock.c: add an 8-instruction dependent add chain for this architecture"
#endif

int main(void)
{
    struct timespec t0, t1;
    unsigned long x = 0, n = 200000000;
    double best = 0;
    for (int rep = 0; rep < 3; rep++) {
        clock_gettime(CLOCK_MONOTONIC, &t0);
        for (unsigned long i = 0; i < n; i++)
            __asm__ volatile(ADD8 : "+r"(x));
        clock_gettime(CLOCK_MONOTONIC, &t1);
        double ns = (t1.tv_sec - t0.tv_sec) * 1e9 + (t1.tv_nsec - t0.tv_nsec);
        if (8.0 * n / ns > best) best = 8.0 * n / ns;
    }
    printf("%.3f\n", best);
    return x == 0;
}
