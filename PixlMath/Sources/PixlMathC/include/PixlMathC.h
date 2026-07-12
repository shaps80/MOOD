#ifndef PIXL_MATH_C_H
#define PIXL_MATH_C_H

typedef struct {
    float sine;
    float cosine;
} pixl_sin_cosf_t;

typedef struct {
    double sine;
    double cosine;
} pixl_sin_cos_t;

float pixl_sinf(float radians);
float pixl_cosf(float radians);
pixl_sin_cosf_t pixl_sin_cosf(float radians);
double pixl_sin(double radians);
double pixl_cos(double radians);
pixl_sin_cos_t pixl_sin_cos(double radians);

#endif
