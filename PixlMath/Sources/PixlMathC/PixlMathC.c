#include <math.h>
#include "PixlMathC.h"

float pixl_sinf(float radians) {
    return sinf(radians);
}

float pixl_cosf(float radians) {
    return cosf(radians);
}

pixl_sin_cosf_t pixl_sin_cosf(float radians) {
    return (pixl_sin_cosf_t) {
        .sine = sinf(radians),
        .cosine = cosf(radians)
    };
}

double pixl_sin(double radians) {
    return sin(radians);
}

double pixl_cos(double radians) {
    return cos(radians);
}

pixl_sin_cos_t pixl_sin_cos(double radians) {
    return (pixl_sin_cos_t) {
        .sine = sin(radians),
        .cosine = cos(radians)
    };
}
