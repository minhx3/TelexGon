#ifndef TELEX_H
#define TELEX_H

#include <stdbool.h>
#include <stdint.h>

enum { TELEX_CAPACITY = 32 };

typedef struct {
    uint16_t letters[TELEX_CAPACITY];
    uint8_t length;
    uint8_t tone;
} TelexWord;

bool TelexIsLetter(uint16_t key);
void TelexAppend(TelexWord *word, uint16_t key);
void TelexDelete(TelexWord *word);
void TelexRender(const TelexWord *word, uint16_t output[TELEX_CAPACITY]);

#endif
