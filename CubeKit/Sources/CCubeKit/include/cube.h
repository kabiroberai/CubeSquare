#ifndef CCUBEKIT_H
#define CCUBEKIT_H

#include <stdint.h>

typedef struct cubiecube *cube_t;

/**
 Prepares the pruning tables. Must be called exactly once before invoking `cube_solve`.
 */
void cube_setup(void);

cube_t cube_new(uint8_t *cp, uint8_t *co,
                uint8_t *ep, uint8_t *eo);

void cube_free(cube_t cube);

/**
 * Computes the solver string for a given cube.
 *
 * @param facelets
 *          is the cube definition string, see {@link Facelet} for the format.
 *
 * @param maxDepth
 *          defines the maximal allowed maneuver length. For random cubes, a maxDepth of 21 usually will return a
 *          solution in less than 0.5 seconds. With a maxDepth of 20 it takes a few seconds on average to find a
 *          solution, but it may take much longer for specific cubes.
 *
 *@param timeOut
 *          defines the maximum computing time of the method in seconds. If it does not return with a solution, it returns with
 *          an error code.
 *
 * @param useSeparator
 *          determines if a " . " separates the phase1 and phase2 parts of the solver string like in F' R B R L2 F .
 *          U2 U D for example.<br>
 * @return The solution string or an error code:<br>
 *         Error 1: There is not exactly one facelet of each colour<br>
 *         Error 2: Not all 12 edges exist exactly once<br>
 *         Error 3: Flip error: One edge has to be flipped<br>
 *         Error 4: Not all corners exist exactly once<br>
 *         Error 5: Twist error: One corner has to be twisted<br>
 *         Error 6: Parity error: Two corners or two edges have to be exchanged<br>
 *         Error 7: No solution exists for the given maxDepth<br>
 *         Error 8: Timeout, no solution within given time
 */
char *cube_solve(cube_t cube, int maxDepth, long timeOut, int useSeparator);

#endif
