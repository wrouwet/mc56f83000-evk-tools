/*
 * Placeholder application source.
 *
 * Deliberately not a hand-written blinky: the MC56F83xxx family's GPIO/SIM
 * register addresses and startup sequence are device-variant-specific, and
 * guessing them from documentation rather than a verified source risks
 * shipping wrong register addresses in example code meant to run on real
 * hardware.
 *
 * Replace this file with the .c/.h sources from the MC56F83000-EVK example
 * project that ships with your CodeWarrior install (matched to your board's
 * exact device variant, e.g. MC56F83789 — check the chip silkscreen).
 * See README.md "Important note on src/ and linker/" and docs/SETUP.md
 * step 5 for where to find it.
 */

int main(void)
{
    for (;;) {
        /* application code goes here */
    }
}
