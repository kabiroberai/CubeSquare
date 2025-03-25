#ifndef SEARCH_H
#define SEARCH_H

typedef struct {
    int ax[31];             // The axis of the move
    int po[31];             // The power of the move
    int flip[31];           // phase1 coordinates
    int twist[31];
    int slice[31];
    int parity[31];         // phase2 coordinates
    int URFtoDLF[31];
    int FRtoBR[31];
    int URtoUL[31];
    int UBtoDF[31];
    int URtoDF[31];
    int minDistPhase1[31];  // IDA* distance do goal estimations
    int minDistPhase2[31];
} search_t;

search_t* get_search(void);

// generate the solution string from the array data including a separator between phase1 and phase2 moves
char* solutionToString(search_t* search, int length, int depthPhase1);

// Apply phase2 of algorithm and return the combined phase1 and phase2 depth. In phase2, only the moves
// U,D,R2,F2,L2 and B2 are allowed.
int totalDepth(search_t* search, int depthPhase1, int maxDepth);


// Add a pattern to the state of a cube, so that the solution for new_facelets
// applied to facelets will result into the given pattern
void patternize(char* facelets, char* pattern, char* patternized);

#endif
