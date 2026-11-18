#include "Telex.h"

// Each row contains the unmarked vowel, then sắc, huyền, hỏi, ngã, nặng.
static const uint16_t vowels[][13] = {
    u"aáàảãạAÁÀẢÃẠ", u"ăắằẳẵặĂẮẰẲẴẶ", u"âấầẩẫậÂẤẦẨẪẬ",
    u"eéèẻẽẹEÉÈẺẼẸ", u"êếềểễệÊẾỀỂỄỆ", u"iíìỉĩịIÍÌỈĨỊ",
    u"oóòỏõọOÓÒỎÕỌ", u"ôốồổỗộÔỐỒỔỖỘ", u"ơớờởỡợƠỚỜỞỠỢ",
    u"uúùủũụUÚÙỦŨỤ", u"ưứừửữựƯỨỪỬỮỰ", u"yýỳỷỹỵYÝỲỶỸỴ",
};

static uint16_t lower(uint16_t letter)
{
    if (letter >= 'A' && letter <= 'Z') return letter + ('a' - 'A');
    switch (letter) {
        case u'Ă': return u'ă';
        case u'Â': return u'â';
        case u'Ê': return u'ê';
        case u'Ô': return u'ô';
        case u'Ơ': return u'ơ';
        case u'Ư': return u'ư';
        case u'Đ': return u'đ';
        default: return letter;
    }
}

static uint16_t matchCase(uint16_t original, uint16_t replacement)
{
    if (original == lower(original)) return replacement;
    switch (replacement) {
        case u'ă': return u'Ă';
        case u'â': return u'Â';
        case u'ê': return u'Ê';
        case u'ô': return u'Ô';
        case u'ơ': return u'Ơ';
        case u'ư': return u'Ư';
        case u'đ': return u'Đ';
        default: return replacement - ('a' - 'A');
    }
}

bool TelexIsLetter(uint16_t key)
{
    return lower(key) >= 'a' && lower(key) <= 'z';
}

static bool isVowel(uint16_t key)
{
    switch (lower(key)) {
        case 'a': case u'ă': case u'â': case 'e': case u'ê': case 'i':
        case 'o': case u'ô': case u'ơ': case 'u': case u'ư': case 'y':
            return true;
        default: return false;
    }
}

typedef struct {
    int first;
    int last;
} VowelRun;

static VowelRun lastVowels(const TelexWord *word)
{
    int last = word->length - 1;
    while (last >= 0 && !isVowel(word->letters[last])) last--;
    int first = last;
    while (first > 0 && isVowel(word->letters[first - 1])) first--;
    if (first == 1 && first < last) {
        uint16_t initial = lower(word->letters[0]);
        uint16_t glide = lower(word->letters[first]);
        if ((initial == 'q' && glide == 'u') ||
            (initial == 'g' && glide == 'i')) first++;
    }
    return (VowelRun){first, last};
}

static int tonePosition(const TelexWord *word)
{
    VowelRun run = lastVowels(word);
    for (int i = run.last; i >= 0 && i >= run.first; i--) {
        switch (lower(word->letters[i])) {
            case u'ă': case u'â': case u'ê': case u'ô': case u'ơ': case u'ư':
                return i;
        }
    }

    // Kiểu đặt dấu truyền thống: hòa, khỏe, thúy.
    int count = run.last - run.first + 1;
    if (count >= 3 || (count == 2 && run.last < word->length - 1)) {
        return run.first + 1;
    }
    return run.first;
}

static uint8_t toneForKey(uint16_t key)
{
    switch (key) {
        case 's': return 1;
        case 'f': return 2;
        case 'r': return 3;
        case 'x': return 4;
        case 'j': return 5;
        default: return 0;
    }
}

static void replace(TelexWord *word, int index, uint16_t letter)
{
    word->letters[index] = matchCase(word->letters[index], letter);
}

// Apply a shape key. A second press restores the base and leaves a literal key.
static bool applyShape(TelexWord *word, uint16_t key)
{
    uint16_t base = lower(key);
    uint16_t shaped;
    switch (base) {
        case 'a': shaped = u'â'; break;
        case 'e': shaped = u'ê'; break;
        case 'o': shaped = u'ô'; break;
        case 'd':
            if (word->length == 0) return false;
            if (lower(word->letters[0]) == 'd') {
                replace(word, 0, u'đ');
                return true;
            }
            if (lower(word->letters[0]) == u'đ') replace(word, 0, 'd');
            return false;
        default: return false;
    }

    VowelRun run = lastVowels(word);
    for (int i = run.last; i >= 0 && i >= run.first; i--) {
        uint16_t letter = lower(word->letters[i]);
        if (letter == shaped) {
            replace(word, i, base);
            return false;
        }
        if (letter == base || (base == 'a' && letter == u'ă') ||
            (base == 'o' && letter == u'ơ')) {
            replace(word, i, shaped);
            return true;
        }
    }
    return false;
}

static bool applyBreveOrHorn(TelexWord *word)
{
    VowelRun run = lastVowels(word);
    for (int i = run.last; i >= 0 && i >= run.first; i--) {
        uint16_t letter = lower(word->letters[i]);
        uint16_t previous = i > run.first ? lower(word->letters[i - 1]) : 0;
        switch (letter) {
            case 'a':
                if (previous == 'u' || previous == u'ư') continue;
                replace(word, i, u'ă');
                return true;
            case u'â': replace(word, i, u'ă'); return true;
            case 'o': case u'ô': replace(word, i, u'ơ'); return true;
            case 'u': replace(word, i, u'ư'); return true;
            case u'ă': replace(word, i, 'a'); return false;
            case u'ư': replace(word, i, 'u'); return false;
            case u'ơ':
                replace(word, i, 'o');
                if (previous == u'ư') replace(word, i - 1, 'u');
                return false;
        }
    }
    return false;
}

void TelexAppend(TelexWord *word, uint16_t key)
{
    if (word->length == TELEX_CAPACITY || !TelexIsLetter(key)) return;
    uint16_t base = lower(key);
    uint8_t tone = toneForKey(base);
    if (tone && tonePosition(word) >= 0) {
        if (word->tone != tone) {
            word->tone = tone;
            return;
        }
        word->tone = 0;
    } else if (base == 'z' && word->tone) {
        word->tone = 0;
        return;
    } else if (base == 'w' ? applyBreveOrHorn(word) : applyShape(word, key)) {
        return;
    }
    word->letters[word->length++] = key;
}

void TelexDelete(TelexWord *word)
{
    if (word->length == 0) return;
    if (word->tone && tonePosition(word) == word->length - 1) word->tone = 0;
    word->length--;
}

void TelexRender(const TelexWord *word, uint16_t output[TELEX_CAPACITY])
{
    TelexWord rendered = *word;

    // Open uơ is retained in thuở/huơ. A coda makes the nucleus ươ.
    VowelRun run = lastVowels(word);
    for (int i = run.first + 1; run.first >= 0 && i <= run.last; i++) {
        if (i + 1 < word->length && lower(word->letters[i]) == u'ơ' &&
            lower(word->letters[i - 1]) == 'u') {
            replace(&rendered, i - 1, u'ư');
        }
    }
    for (int i = 0; i < rendered.length; i++) output[i] = rendered.letters[i];
    if (!rendered.tone) return;

    int position = tonePosition(&rendered);
    if (position < 0) return;
    for (unsigned row = 0; row < sizeof vowels / sizeof vowels[0]; row++) {
        if (output[position] == vowels[row][0]) {
            output[position] = vowels[row][rendered.tone];
            return;
        }
        if (output[position] == vowels[row][6]) {
            output[position] = vowels[row][6 + rendered.tone];
            return;
        }
    }
}
