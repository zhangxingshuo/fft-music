
// Define the frequency in Hz for different notes
enum pitch {
    C2 = 131,
    sC2 = 139,
    fD2 = 139,
    D2 = 147,
    sD2 = 156,
    fE2 = 156,
    E2 = 165,
    F2 = 175,
    sF2 = 185,
    fG2 = 185,
    G2 = 196,
    sG2 = 208,
    fA3 = 208,
    A3 = 220,
    sA3 = 233,
    fB3 = 233, 
    B3 = 247, 
    C3 = 262, 
    sC3 = 277,
    fD3 = 277, 
    D3 = 294, 
    sD3 = 311,
    fE3 = 311, 
    E3 = 330, 
    F3 = 349, 
    sF3 = 370,
    fG3 = 370, 
    G3 = 392, 
    sG3 = 415,
    fA4 = 415,
    A4 = 440, 
    sA4 = 466,
    fB4 = 466,
    B4 = 494, 
    C4 = 523,
    sC4 = 554,
    fD4 = 554,
    D4 = 587,
    sD4 = 622,
    fE4 = 622,
    E4 = 659,
    F4 = 698,
    sF4 = 740,
    fG4 = 740,
    G4 = 784,
    sG4 = 831,
    fA5 = 831,
    A5 = 880,
    sA5 = 932,
    fB5 = 932,
    B5 = 988,
    C5 = 1046,
    sC5 = 1109,
    fD5 = 1109,
    D5 = 1175,
    R = 0      // rest
};
typedef enum pitch pitch_t;

// Define the duration of a note in ms
enum dur {
    E = 125,  // eighth
    Q = 250,  // quarter
    H = 500,  // half
    W = 1000, // whole
    DONE = 42 // done
};
typedef enum dur dur_t;

// Define a note struct, with a frequency
// and duration pair
struct noteStruct {
  pitch_t p;
  dur_t d;
};
typedef struct noteStruct note_t;

// Define a chord struct, with three separate
// frequencies to play
struct chordStruct {
    pitch_t p1;
    pitch_t p2;
    pitch_t p3;
};
typedef struct chordStruct chord_t;