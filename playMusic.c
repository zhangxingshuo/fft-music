///////////////////////////////////////////////////////////
// 
// ENGR155 Final Project
// playMusic.c
// 
// DIGITAL MUSIC SYNTHESIZER
// Created by:
// Kitty Belling kbelling@hmc.edu
// Andy Zhang    axzhang@hmc.edu
//
// Uses the Raspberry Pi GPIO pins to generate square 
// waves at a given frequency. Reads in from a music
// header file and plays three independent parts specified
// by their note and duration.
//
// Uses the pigpio library to generate independent hardware 
// clock and PWM signals on the pins. Compile using
// 
// gcc -Wall -pthread -o playMusic playMusic.c -lpigpio -lrt
//
// Also uses the provided EasyPIO library, which can be found
// at http://pages.hmc.edu/harris/class/e155/EasyPIO.h
//
///////////////////////////////////////////////////////////

#include <sys/mman.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

// Raspberry Pi libraries
#include <pigpio.h>
#include <wiringPi.h>
#include <softPwm.h> 
#include "EasyPIO.h" 

// Contains type definitions
#include "note.h"

// Contains the music data to be played
#include "bach.h"
#include "canon.h"
#include "sleigh.h"

// Plays a single note at a given frequency for
// a given duration
void playNote(int freq, int dur) {
    if (freq > 0) {
        // Calculate number of cycles and time
        // between peaks
        int cycles = (dur*freq)/1000;
        int delayTime = 500000 / freq;
        int i;
        for (i = 0; i < cycles; i++) {
            // Write a HIGH
            myDigitalWrite(4,  1);
            delayMicros(delayTime);
            // Write a LOW
            myDigitalWrite(4, 0);
            delayMicros(delayTime);
        }
    }
    else {
        delayMicros(dur*1000);
    }
}

// Plays a single chord for 25 ms
// To get around issues with simultaneous clocks
// and PWM frequencies, we chunk the frequencies
// into 25 ms chunks and play every chord for
// 25 ms. 
void playChord(int freq1, int freq2, int freq3) {
    gpioHardwarePWM(13, freq1, 500000);
    softToneWrite(23, freq2);
    playNote(freq3, 25);
}

note_t rest = {R, W};

int main(void) {
    // Initialize the Raspberry Pi for EasyPIO
    pioInit();
    // Initialize pigpio
    if (gpioInitialise() < 0) printf("pigpio initialization error\n");
    // Initialize wiringPi
    wiringPiSetupGpio();

    // GPIO pin 4 is systimer tone generator
    myPinMode(4, OUTPUT);

    // Software PWM from wiringPi
    if (softToneCreate(23) != 0) printf("wiringPi initialization error\n");

    // Reading from keypad
    myPinMode(17, INPUT);
    myPinMode(27, INPUT);
    myPinMode(22, INPUT);

    // Wait for input
    int in0 = 0;
    int in1 = 0;
    int in2 = 0;
    while (!in0 && !in1 && !in2) {
        in0 = myDigitalRead(17);
        in1 = myDigitalRead(27);
        in2 = myDigitalRead(22);
    }

    // Initialize our counters to the arrays
    int i0 = 0;
    int i1 = 0;
    int i2 = 0;

    note_t* note0;
    note_t* note1;
    note_t* note2;
    if (in0) {
        note0 = &bach0[i0];
        note1 = &bach1[i1];
        note2 = &bach2[i2];
    }
    else if (in1) {
    	note0 = &canon0[i0];
        note1 = &canon1[i1];
        note2 = &canon2[i2];
    }
    else if (in2) {
        note0 = &sleigh0[i0];
        note1 = &sleigh1[i1];
        note2 = &sleigh2[i2];
    }

    // Initialize running average
    int num0 = note0->d;
    int num1 = 0;
    int num2 = 0;
    double running_dur = 0.0;
    double pwm_duty = 0.0;

    // Create note copies
    note_t copy0 = {note0->p, note0->d};
    note_t copy1 = {note1->p, note1->d};
    note_t copy2 = {note2->p, note2->d};

    printf("Playing...\n");

    // Continue playing until all notes read DONE
    //while ((copy0.d != DONE) || (copy1.d != DONE) || (copy2.d != DONE)) {
    while (1) {

        int freq0 = copy0.p;
        int dur0 = copy0.d;
        int freq1 = copy1.p;
        int dur1 = copy1.d;
        int freq2 = copy2.p;
        int dur2 = copy2.d;

        // Calculate new duration by subtracting 25 ms, 
        // keeping at DONE if reached the end
        copy0.d = (dur0 != DONE) ? dur0 - 25 : DONE;
        copy1.d = (dur1 != DONE) ? dur1 - 25 : DONE;
        copy2.d = (dur2 != DONE) ? dur2 - 25 : DONE;

        // Calculate running average of durations
        if (i0 == 0) {
            running_dur = (double) num0;
        }
        else if (i0 == 1) {
           running_dur = (double) (num0 + num1) / 2;
        }
        else {
           running_dur = (double) (num0 + num1 + num2) / 3;
        }

        // Transform average to a PWM duty cycle
        pwm_duty = (-0.0457 * running_dur + 70.7) * 10000;
        gpioHardwarePWM(18, 120, pwm_duty);

        printf("Note 0: %d, %d, %d\n", i0, freq0, dur0);
        printf("Note 1: %d, %d, %d\n", i1, freq1, dur1);
        printf("Note 2: %d, %d, %d\n", i2, freq2, dur2);
        // printf("%f\n", pwm_duty);
        playChord(freq0, freq1, freq2);

        // Advance if duration is 25
        if (dur0 == 25) {
            i0++;
            if (i0 == 1) {
                if (in0) {
                    num1 = bach0[i0].d;
                }
                else if (in1) {
                    num1 = canon0[i0].d;
                }
                else if (in2) {
                    num1 = sleigh0[i0].d;
                }
            }
            else if (i0 == 2) {
                if (in0) {
                    num2 = bach0[i0].d;
                }
                else if (in1) {
                    num2 = canon0[i0].d;
                }
                else if (in2) {
                    num2 = sleigh0[i0].d;
                }
            }
            else {
                num0 = num1;
                num1 = num2;
                if (in0) {
                    num2 = bach0[i0].d;
                }
                else if (in1) {
                    num2 = canon0[i0].d;
                }
                else if (in2) {
                    num2 = sleigh0[i0].d;
                }
            }

            if (in0) {
                note0 = &bach0[i0];
            } 
            else if (in1) {
                note0 = &canon0[i0];
            }
            else if (in2) {
                note0 = &sleigh0[i0];
            }
            else {
                i0 = 0;
                note0 = &rest;
            }
            copy0.p = note0->p;
            copy0.d = note0->d;
        }

        if (dur1 == 25) {
            i1++;
            if (in0) {
                note1 = &bach1[i1];
            } 
            else if (in1) {
                note1 = &canon1[i1];
            }
            else if (in2) {
                note1 = &sleigh1[i1];
            }
            else {
                i1 = 0;
                note1 = &rest;
            }
            copy1.p = note1->p;
            copy1.d = note1->d;
        }
        if (dur2 == 25) {
            i2++;
            if (in0) {
                note2 = &bach2[i2];        
            } 
            else if (in1) {
                note2 = &canon2[i2];
            }
            else if (in2) {
                note2 = &sleigh2[i2];
            }
            else {
                i2 = 0;
                note2 = &rest;
            }
            copy2.p = note2->p;
            copy2.d = note2->d;
        }

        // Read GPIO pins
        int newin0 = myDigitalRead(17);
        int newin1 = myDigitalRead(27);
        int newin2 = myDigitalRead(22);

        // If input has changed
        if ((in0 != newin0) || (in1 != newin1) || (in2 != newin2)) {
            i0 = 0;
            i1 = 0;
            i2 = 0;

            if (newin0) {
                note0 = &bach0[i0];
                note1 = &bach1[i1];
                note2 = &bach2[i2];
            }
            else if (newin1) {
                note0 = &canon0[i0];
                note1 = &canon1[i1];
                note2 = &canon2[i2];
            }
            else if (newin2) {
                note0 = &sleigh0[i0];
                note1 = &sleigh1[i1];
                note2 = &sleigh2[i2];
            }
            else {
                note0 = &rest;
                note1 = &rest;
                note2 = &rest;
            }
        
            copy0.p = note0->p;
            copy0.d = note0->d;
            copy1.p = note1->p;
            copy1.d = note1->d;
            copy2.p = note2->p;
            copy2.d = note2->d;

            running_dur = 0;
            num0 = note0->d;
            num1 = 0;
            num2 = 0;
        }

        // Update input
        in0 = newin0;
        in1 = newin1;
        in2 = newin2;
    }

    // Play a silent chord
    playChord(0, 0, 0);
    
    printf("Done.\n");
    return 0;
}
