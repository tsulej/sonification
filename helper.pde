final float cosh(float x) {
  return 0.5 * (exp(x) + exp(-x));
}

final float sinh(float x) {
  return 0.5 * (exp(x) - exp(-x));
}

final float tanh(float x) {
  return sinh(x)/cosh(x);
}

final float safesqrt(float x) {
  return (x<1e-10) ? 0.0 : sqrt(x);
}

final float sgn(float a) {
  if(a == 0.0) return 0.0;
  return a > 0.0 ? 1.0 : -1.0;
}

final float modulate(float amp, float freq, float x, float phase) {
   return amp * cos(x * freq * TWO_PI + phase);
 }

final float acosh(float a) {
  return log(a + sqrt(a-1) * sqrt(a+1));
}

int randSeed = 23;
final float fnoise() {
  randSeed = (randSeed * 196314165) + 907633515;
  return randSeed / (float)MAX_INT;
}

float cube_interp(float fr, float inm1, float in, float inp1, float inp2)
{
  return in + 0.5f * fr * (inp1 - inm1 +
   fr * (4.0f * inp1 + 2.0f * inm1 - 5.0f * in - inp2 +
   fr * (3.0f * (in - inp1) - inm1 + inp2)));
}

final static int MIN = 0;
final static int MAX = 1;

void equalize(color[] p) {
  float[][] hist = new float[3][256];
  int[][] look = new int[3][256];

  for (int i=0;i<256;i++) {
    hist[0][i] = 0;
    hist[1][i] = 0;
    hist[2][i] = 0;
  }

  float d = 1.0/p.length; 
  for (int i=0;i<p.length;i++) {
    color c = p[i];
    hist[0][ (c >> 16) & 0xff ] += d;
    hist[1][ (c >> 8) & 0xff ] += d;
    hist[2][ (c) & 0xff ] += d;
  }

  for (int c=0;c<3;c++) {
    float sum = 0.0;
    for (int i=0;i<256;i++) {
      sum += hist[c][i];
      look[c][i] = (int)constrain(floor(sum * 255), 0, 255);
    }
  }

  int[][] minmax = new int[3][2];
  minmax[0][MIN] = 256;
  minmax[1][MIN] = 256;
  minmax[2][MIN] = 256;
  minmax[0][MAX] = -1;
  minmax[1][MAX] = -1;
  minmax[2][MAX] = -1;
  for (int i=0;i<256;i++) {
    int r = look[0][i];
    int g = look[1][i];
    int b = look[2][i];    
    if (r<minmax[0][MIN]) minmax[0][MIN]=r;
    if (r>minmax[0][MAX]) minmax[0][MAX]=r;
    if (g<minmax[1][MIN]) minmax[1][MIN]=g;
    if (g>minmax[1][MAX]) minmax[1][MAX]=g;
    if (b<minmax[2][MIN]) minmax[2][MIN]=b;
    if (b>minmax[2][MAX]) minmax[2][MAX]=b;
  }

  for (int i=0;i<p.length;i++) {
    color c = p[i];
    int r = (int)map(look[0][ (c >> 16) & 0xff ], minmax[0][MIN], minmax[0][MAX], 0, 255);
    int g = (int)map(look[1][ (c >> 8) & 0xff ], minmax[1][MIN], minmax[1][MAX], 0, 255);
    int b = (int)map(look[2][ (c) & 0xff ], minmax[2][MIN], minmax[2][MAX], 0, 255);    
    int cres = 0xff000000 | (r << 16) | (g << 8) | b; 
    p[i] = cres;
  }
}
