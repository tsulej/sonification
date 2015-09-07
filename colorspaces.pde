
// # of colorspaces
final static int MAX_COLORSPACES = 2;
// colorspaces, NONE: RGB
final static int OHTA = 1001;
final static int CMY = 1002;

// colorspace converters
color fromColorspace(color c, int cs) {
  switch(cs) {
    case OHTA: return fromOHTA(c);
    case CMY: return fromCMY(c); 
    default: return c;     
  }
}

color toColorspace(color c, int cs) {
  switch(cs) {
    case OHTA: return toOHTA(c); 
    case CMY: return toCMY(c);
    default: return c;     
  }
}


final int getR(color c) { return (c & 0xff0000) >> 16; }
final int getG(color c) { return (c & 0xff00) >> 8; }
final int getB(color c) { return c & 0xff; }

color blendRGB(color c, int r, int g, int b) {
  return (c & 0xff000000) | ( constrain(r,0,255) << 16) | ( constrain(g,0,255) << 8 ) | (constrain(b,0,255));
}

color toCMY(color c) {
  return blendRGB(c, 255-getR(c), 255-getG(c), 255-getB(c));
}

color fromCMY(color c) {
  return toCMY(c);
}

color fromOHTA(color c) {
  int I1 = getR(c);
  float I2 = map(getG(c),0,255,-127.5,127.5);
  float I3 = map(getB(c),0,255,-127.5,127.5);
  
  int R = (int)(I1+1.00000*I2-0.66668*I3);
  int G = (int)(I1+1.33333*I3);
  int B = (int)(I1-1.00000*I2-0.66668*I3);
  
  return blendRGB(c,R,G,B);
}

color toOHTA(color c) {
  int R = getR(c);
  int G = getG(c);
  int B = getB(c);
 
  int I1 = (int)(0.33333*R+0.33334*G+0.33333*B);
  int I2 = (int)map(0.50000*R-0.50000*B,-127.5,127.5,0,255);
  int I3 = (int)map(-0.25000*R+0.50000*G-0.25000*B,-127.5,127.5,0,255);
    
  return blendRGB(c,I1,I2,I3);  
}
