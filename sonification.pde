// Sonification, image as sound
// Reimplementation of image -> raw -> wav -> audacity filters -> wav -> raw -> image process
// Tomasz Sulej, generateme.blog@gmail.com, http://generateme.tumblr.com
// Licence: http://unlicense.org/

// Usage:
//   * press SPACE to save
//   * click to randomize effect settings
//   * f to randomize filters
//   * r to randomize raw settings

// set up filename
String filename = "test";
String fileext = ".jpg";
String foldername = "./";

int max_display_size = 700; // viewing window size (regardless image size)

boolean do_blend = false; // blend image after process
int blend_mode = OVERLAY; // blend type

// image reader config
int r_rawtype = PLANAR; // planar: rrrrr...ggggg....bbbbb; interleaved: rgbrgbrgb...
int r_law = NONE; // NONE, A_LAW, U_LAW
int r_sign = SIGNED; // SIGNED or UNSIGNED
int r_bits = B8; // B8, B16 or B24, bits per sample
int r_endianess = LITTLE_ENDIAN; // BIG_ENDIAN or LITTLE_ENDIAN
int r_colorspace = RGB; // list below 

// image writer config
int w_rawtype = PLANAR; // planar: rrrrr...ggggg....bbbbb; interleaved: rgbrgbrgb...
int w_law = NONE; // NONE, A_LAW, U_LAW
int w_sign = SIGNED; // SIGNED or UNSIGNED
int w_bits = B8; // B8, B16 or B24, bits per sample
int w_endianess = LITTLE_ENDIAN; // BIG_ENDIAN or LITTLE_ENDIAN
int w_colorspace = RGB; // list below

// put list of the filters { name, sample rate }
float[][] filters = {
//  { DJEQ, 44100.0 },
//  { VYNIL, 43100.0},
  { ECHO, 44100.0 }
};

// EFFECTS!
final static int DJEQ = 0;
final static int COMB = 1;
final static int VYNIL = 2;
final static int CANYONDELAY = 3; 
final static int VCF303 = 4;
final static int ECHO = 5, PHASER = 6, WAHWAH = 7, BASSTREBLE = 8;

// configuration constants
final static int A_LAW = 0;
final static int U_LAW = 1;
final static int NONE = 2;

final static int UNSIGNED = 0;
final static int SIGNED = 1;

final static int B8 = 8;
final static int B16 = 16;
final static int B24 = 24;

final static int LITTLE_ENDIAN = 0;
final static int BIG_ENDIAN = 1;

final static int PLANAR = 0;
final static int INTERLEAVED = 1;

// colorspaces, NONE: RGB
final static int OHTA = 1001;

// working buffer
PGraphics buffer;

// image
PImage img;

String sessionid;

AFilter afilter; // filter handler
RawReader isr; // image reader
RawWriter isw; // image writer
ArrayList<AFilter> filterchain = new ArrayList<AFilter>();

void setup() {
  sessionid = hex((int)random(0xffff),4);
  img = loadImage(foldername+filename+fileext);
  
  buffer = createGraphics(img.width, img.height);
  buffer.beginDraw();
  buffer.noStroke();
  buffer.smooth(8);
  buffer.background(0);
  buffer.image(img,0,0);
  buffer.endDraw();
  
  // calculate window size
  float ratio = (float)img.width/(float)img.height;
  int neww, newh;
  if(ratio < 1.0) {
    neww = (int)(max_display_size * ratio);
    newh = max_display_size;
  } else {
    neww = max_display_size;
    newh = (int)(max_display_size / ratio);
  }

  size(neww,newh);

  isr = new RawReader(img.get(), r_rawtype, r_law, r_sign, r_bits, r_endianess);
  isr.r.convertColorspace(r_colorspace);
  isw = new RawWriter(img.get(), w_rawtype, w_law, w_sign, w_bits, w_endianess);

  prepareFilters(filters);
  
  processImage();
}

void prepareFilters(float[][] f) {
  filterchain.clear();
  Piper p = isr;
  for(int i = 0; i<f.length;i++) {
    afilter = createFilter((int)f[i][0],p,f[i][1]);
    p = afilter;
    filterchain.add(afilter);
  }
}

void randomizeConfig() {
  for(AFilter f : filterchain) f.randomize();
  resetStreams();
}

// TODO: print settings
void randomizeFilters() {
  int filterno = (int)random(1,4); // 1, 2 or 3 filters in chain
  filters = new float[filterno][2];
  for(int i=0;i<filterno;i++) {
    filters[i][0] = (int)random(MAX_FILTERS);
    filters[i][1] = random(1)<0.5?44100.0:random(1)<0.334?22050:random(1)<0.5?100000:random(3000,120000);
  }
  prepareFilters(filters);
  resetStreams();  
}

// TODO: print settings
void randomizeRaw() {
  boolean keepsame = random(1)<0.75;
  int rawtype = random(1)<0.5?INTERLEAVED:PLANAR;
  int law = random(1)<0.334?NONE:random(1)<0.5?A_LAW:U_LAW;
  int sign = random(1)<0.5?SIGNED:UNSIGNED;
  int bits = random(1)<0.334?B8:random(1)<0.5?B16:B24;
  int endian = random(1)<0.5?BIG_ENDIAN:LITTLE_ENDIAN;
  int cs = random(1)<0.5?RGB:OHTA;
  isr = new RawReader(img.get(), rawtype, law, sign, bits, endian);
  isr.r.convertColorspace(cs);
  if(!keepsame) {
    rawtype = random(1)<0.5?INTERLEAVED:PLANAR;
    law = random(1)<0.334?NONE:random(1)<0.5?A_LAW:U_LAW;
    sign = random(1)<0.5?SIGNED:UNSIGNED;
    bits = random(1)<0.334?B8:random(1)<0.5?B16:B24;
    endian = random(1)<0.5?BIG_ENDIAN:LITTLE_ENDIAN;
    w_colorspace = random(1)<0.5?RGB:OHTA;
  }
  isw = new RawWriter(img.get(), rawtype, law, sign, bits, endian);
  prepareFilters(filters);
  resetStreams();
}

void draw() {
  // fill for iterative processing
}

void processImage() {
  buffer.beginDraw();
  
  // process every byte
  while(!isr.r.taken) isw.write(afilter.read());
  
  // change result colorspace
  isw.w.convertColorspace(w_colorspace);
  // equalize and normalize histogram
  equalize(isw.w.wimg.pixels);
  isw.w.wimg.updatePixels();

  buffer.image(isw.w.wimg, 0, 0);

  if(do_blend)
    buffer.blend(img,0,0,img.width,img.height,0,0,buffer.width,buffer.height,blend_mode);
    
  buffer.endDraw();
  image(buffer,0,0,width,height);
}

void resetStreams() {
  isr.reset();
  isw.reset();
}

void mouseClicked() {
  randomizeConfig();
    
  processImage();
}

void keyPressed() {
  // SPACE to save
  if(keyCode == 32) {
    String fn = foldername + filename + "/res_" + sessionid + hex((int)random(0xffff),4)+"_"+filename+fileext;
    buffer.save(fn);
    println("Image "+ fn + " saved");
  }
  if(key == 'r') {
    randomizeRaw();
    processImage();
  }
  if(key == 'f') {
    randomizeFilters();
    processImage();
  }
}

//

final static int[] blends = {ADD, SUBTRACT, DARKEST, LIGHTEST, DIFFERENCE, EXCLUSION, MULTIPLY, SCREEN, OVERLAY, HARD_LIGHT, SOFT_LIGHT, DODGE, BURN};

// ANIMATION
//
//float p1 = random(TWO_PI);
//float p2 = random(TWO_PI);
//float p3 = random(TWO_PI);
//float p4 = random(TWO_PI);
//float p5 = random(TWO_PI);
//float ang = 0;

//void draw() {
  /* 
   background(0);
   vcf303.env_mod = sin(ang+p1);
   vcf303.cutoff = sin(ang+p2);
   vcf303.resonance = sin(ang+p3);
   vcf303.decay = sin(ang+p4)+0.5;
   vcf303.initialize();
   
   cdelay.ltr_time = map( sin(ang+p1),-1,1,0.1,0.6);
   cdelay.rtl_time = map( sin(ang+p2),-1,1,0.1,0.5);
   cdelay.ltr_feedback = sin(ang+p3);
   cdelay.rtl_feedback = sin(ang+p4);
   cdelay.cutoff = map(sin(ang+p5),-1,1,100,10000);
   cdelay.initialize();
   
   for(int i=0; i<img.width*img.height*3;i++) {
   isw.write(afilter.read());
   }
   
   equalize(isw.w.wimg.pixels);
   isw.w.wimg.updatePixels();
   
   image(isw.w.wimg,0,0);
   
   isr.reset();
   isw.reset();
   ang+=TWO_PI/60.0;
   if(ang<TWO_PI) {
   //  saveFrame("goham/frames_"+(100+frameCount)+".jpg");
   }
   */
//}
