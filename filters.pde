
final static int MAX_FILTERS = 5; // number of filters here, used for randomization, update every new filter
public AFilter createFilter(int type, Piper previous, float srate) {
  switch(type) {
    case DJEQ: return new DjEq(previous, srate);
    case COMB: return new Comb(previous, srate);
    case VYNIL: return new Vynil(previous, srate);
    case CANYONDELAY: return new CanyonDelay(previous, srate);
    case VCF303: return new Vcf303(previous, srate);
    case AUPHAS: return new AuPhaser(previous, srate);
    default: return new Empty(previous, srate); 
  }
}

abstract class AFilter implements Piper {
  public float srate;
  public float rsrate;
  Piper reader;
  
  public AFilter(Piper reader, float srate) {
    this.srate = srate;
    this.reader = reader;
    rsrate = 1.0/srate;
  }

  public void randomize() {}
}

// stub for stereo
public class EmptyStereo extends AFilter {
  Pipe buffer = new Pipe(2);
  
  public EmptyStereo(Piper reader, float srate) {
    super(reader, srate);
    initialize();
  }

  public void initialize() {
    buffer.ridx = buffer.widx = 0;
  }
  
  public void randomize() {
    initialize();
  }
  
  public float read() {
    if(buffer.ridx==0) {
      buffer.write(reader.read()); // left
      buffer.write(reader.read()); // right
    }
    return buffer.read();
  }  
  
}


// stub for mono
public class Empty extends AFilter {
  
  public Empty(Piper reader, float srate) {
    super(reader, srate);
    initialize();
  }

  public void initialize() {}
  public void randomize() {
    initialize();
  }
  
  public float read() {
    return reader.read();
  }  
  
}

public class DjEq extends AFilter {
  
  public float lo, mid, hi;
  public float peak_bw, shelf_slope;
  public Biquad f1,f2,f3;
  
  public DjEq(Piper reader, float srate) {
    super(reader, srate);
    
    f1 = new Biquad();
    f2 = new Biquad();
    f3 = new Biquad();
    
    lo = -10.0;
    mid = 1.0;
    hi = -10.0;
    peak_bw = 0.3;
    shelf_slope = 1.5;
    
    initialize();
  }

  public void initialize() {
    f1.eq_set_params(100.0,lo,peak_bw,srate);
    f2.eq_set_params(1000.0,mid,peak_bw,srate);
    f3.hs_set_params(10000.0,hi,shelf_slope,srate);
  }
  
  public void randomize() {
    lo = random(-70,10);
    hi = random(-70,10);
    mid = random(-70,10);
    peak_bw = random(1);
    shelf_slope = random(2);
    initialize();
  }
  
  public float read() {
    return f3.biquad_run(f2.biquad_run(f1.biquad_run(reader.read())));
  }  
  
}


public class Comb extends AFilter {
  private static final int COMB_SIZE = 0x4000;
  private static final int COMB_MASK = 0x3fff;

  public float freq, feedback;

  float[] comb_tbl;
  int comb_pos;
  float offset;
  float xf, xf_step;

  public Comb(Piper reader, float srate) {
    super(reader, srate);
    
    comb_tbl = new float[COMB_SIZE];
    freq = 100;
    feedback = 0.1;
    
    initialize();
  }

  public void initialize() {
    comb_pos = 0;
    for(int i=0;i<COMB_SIZE;i++) comb_tbl[i] = 0.0;
    
    offset = constrain(srate / freq, 0, COMB_MASK);
  }

  public void randomize() {
    freq = random(16,640);
    feedback = random(-1,1);
    initialize();
  }

  public float read() {
    float d_pos = comb_pos - offset;
    int data_pos = d_pos < 0 ? ceil(d_pos) : floor(d_pos);
    float fr = d_pos - data_pos;
    float interp =  cube_interp(fr, comb_tbl[(data_pos - 1) & COMB_MASK], comb_tbl[data_pos & COMB_MASK], comb_tbl[(data_pos + 1) & COMB_MASK], comb_tbl[(data_pos + 2) & COMB_MASK]);
    float sample = reader.read();
    comb_tbl[comb_pos] = sample + feedback * interp;
    float result = (sample + interp) * 0.5;
    comb_pos = (comb_pos + 1) & COMB_MASK;
    return result;
  }  
}

public class Vynil extends AFilter {
  Pipe buffer = new Pipe(2);
  float [] buffer_m, buffer_s;
  int buffer_mask;
  int buffer_pos;
  float[] click_buffer;
  int click_buffer_pos, click_buffer_omega;
  float click_gain;
  float phi, def, def_target;
  int sample_cnt;
  Biquad lowp_m, lowp_s, noise_filt, highp;  
    
  public float year = 1987;
  public float rpm = 63;
  public float warp = 0.45;
  public float click = 0.235;
  public float wear = 0;  
    
  float omega;
  float age;
  int click_prob;
  float noise_amp;
  float bandwidth;
  float noise_bandwidth;
  float stereo;
  float wrap_gain;
  float wrap_bias;  
    
  public Vynil(Piper reader, float srate) {
    super(reader, srate);
    
    int buffer_size = 4096;
    while(buffer_size < srate * 0.1) {
      buffer_size *= 2;
    }
    buffer_m = new float[buffer_size];
    buffer_s = new float[buffer_size];
    buffer_mask = buffer_size - 1;
    buffer_pos = 0;
    click_gain = 0;
    phi = 0.0;
    
    click_buffer = new float[4096];
    for(int i=0; i<click_buffer.length;i++) {
      if(i<click_buffer.length / 2) {
        click_buffer[i] = (float)i /(float)(click_buffer.length / 2);
        click_buffer[i] *= click_buffer[i];
        click_buffer[i] *= click_buffer[i];
        click_buffer[i] *= click_buffer[i];
      } else {
        click_buffer[i] = click_buffer[click_buffer.length - i];
      }
    }
    
    lowp_m = new Biquad();
    lowp_s = new Biquad();
    highp = new Biquad();
    noise_filt = new Biquad();
    
    initialize();
  }
  
  public void initialize() {
    buffer.ridx = buffer.widx = 0;
    sample_cnt = 0;
    def = 0.0;
    def_target = 0.0;
    buffer_pos = 0;
    click_buffer_pos = 0;
    click_buffer_omega = 0;
    click_gain = 0;
    phi = 0.0f;
    for(int i=0;i<buffer_m.length;i++) {
      buffer_m[i] = buffer_s[i] = 0.0;
    }
    
    omega = 960.0 / (rpm * srate);
    age = (2000-year) * 0.01;
    click_prob = abs((int)(age*age*(MAX_INT*0.1) + click * (0.02 * MAX_INT)));
    noise_amp = (click + wear * 0.3) * 0.12 + (1993.0 - year) * 0.0031;
    bandwidth = (year - 1880.0) * (rpm * 1.9);
    noise_bandwidth = bandwidth * (0.25 - wear * 0.02) + click * 200.0 + 300.0;
    stereo = constrain( (year-1940.0) * 0.02,0.0,1.0);
    wrap_gain = age * 3.1 + 0.05;
    wrap_bias = age * 0.1;
    
    lowp_m.reset();
    lowp_s.reset();
    highp.reset();
    noise_filt.reset();
    lowp_m.lp_set_params(bandwidth * (1.0 - wear * 0.86), 2.0, srate);
    lowp_s.lp_set_params(bandwidth * (1.0 - wear * 0.89), 2.0, srate);
    highp.hp_set_params( (2000.0-year) * 8.0, 1.5, srate);
    noise_filt.lp_set_params(noise_bandwidth, 4.0 + wear * 2.0, srate);
  }
  
  public void randomize() {
    year = random(1900,1990);
    rpm = random(33,78);
    warp = random(0.4);
    click = random(1);
    wear = random(1); 
    initialize();
  }
  
  final private float df(float x) { return ((sin(x) + 1.0) * 0.5); }
  
  public float read() {
    if(buffer.ridx==0) {
      float deflec = def;
      float deflec_target = def_target;
      float src_m, src_s;
      
      int o1,o2;
      float ofs;
      
      if((sample_cnt & 15) == 0) {
        float ang = phi * 2.0 * PI;
        float w = warp * (2000 - year) * 0.01;
        deflec_target = w * df(ang) * 0.5 + w*w*df(2.0*ang)*0.31 + w*w*w*df(3.0*ang)*0.129;
        phi+=omega;
        while(phi > 1.0) { phi -= 1.0; }
        if(random(MAX_INT)<click_prob) {
          click_buffer_omega = int(((((int)random(MAX_INT)) >> 6) + 1000) * rpm);
          click_gain = noise_amp * 5.0 * fnoise();
        }
      }
      deflec = deflec * 0.1 + deflec_target * 0.9;
      
      float in_l = reader.read();
      float in_r = reader.read();
      buffer_m[buffer_pos] = in_l + in_r;
      buffer_s[buffer_pos] = in_l - in_r;
      
      ofs = srate * 0.009 * deflec;
      o1 = int(floor(ofs));
      o2 = int(ceil(ofs));
      ofs -= o1;
      src_m = lerp(buffer_m[(buffer_pos - o1 - 1) & buffer_mask], buffer_m[(buffer_pos - o2 - 1) & buffer_mask], ofs);
      src_s = lerp(buffer_s[(buffer_pos - o1 - 1) & buffer_mask], buffer_s[(buffer_pos - o2 - 1) & buffer_mask], ofs);
      
      src_m = lowp_m.biquad_run(src_m + click_buffer[click_buffer_pos & 4095] * click_gain);
      src_m = lerp(src_m, sin(src_m * wrap_gain + wrap_bias),age);      
      src_m = highp.biquad_run(src_m) + noise_filt.biquad_run(fnoise()) * noise_amp + click_buffer[click_buffer_pos & 4095] * click_gain * 0.5f;
      src_s = lowp_s.biquad_run(src_s) * stereo;

      buffer.write( 0.5 * (src_s+src_m) );
      buffer.write( 0.5 * (src_m-src_s) );
      
      buffer_pos = (buffer_pos + 1) & buffer_mask;
      click_buffer_pos += click_buffer_omega;
      if(click_buffer_pos >= 4096) {
        click_buffer_pos = 0;
        click_buffer_omega = 0;
      }
      sample_cnt++;
      def = deflec;
      def_target = deflec_target;
      
    }
    return buffer.read();
  }
}

public class CanyonDelay extends AFilter {
  public float ltr_time = 0.5;
  public float rtl_time = 0.5;
  public float ltr_feedback = 0.1;
  public float rtl_feedback = -0.1;
  public float cutoff = 1000.0;
  
  Pipe buffer = new Pipe(2);
  float[] data_l, data_r;
  int datasize;
  int pos;
  float accum_l, accum_r;
  
  int ltr_offset, rtl_offset;
  float ltr_invmag, rtl_invmag;
  float filter_invmag, filter_mag;
  
  public CanyonDelay(Piper reader, float srate) {
    super(reader,srate);
    datasize = (int)(floor(srate)+1);
    data_l = new float[datasize];
    data_r = new float[datasize];
    initialize();
  }
  
  public void initialize() {
    buffer.ridx = buffer.widx = 0;
    pos = 0;
    for(int i=0;i<datasize;i++) {
      data_l[i]=0.0;
      data_r[i]=0.0;
    }
    accum_l = accum_r = 0.0;
    ltr_offset = (int)(ltr_time * srate);
    rtl_offset = (int)(rtl_time * srate);
    ltr_invmag = 1.0 - abs(ltr_feedback);
    rtl_invmag = 1.0 - abs(rtl_feedback);
    filter_invmag = pow(0.5, (4.0 * PI * cutoff * rsrate) );
    filter_mag = 1.0 - filter_invmag;
  }
  
  public void randomize() {
    ltr_time = random(0.001,1);
    rtl_time = random(0.001,1);;
    ltr_feedback = random(-1,1);
    rtl_feedback = random(-1,1);
    cutoff = random(10000);
    initialize();
  }
  
  public float read() {
    if(buffer.ridx==0) {
      float l = reader.read();
      float r = reader.read();
      
      int pos1 = (pos - rtl_offset + datasize) % datasize;
      int pos2 = (pos - ltr_offset + datasize) % datasize;
      
      l = l * rtl_invmag + data_r[pos1] * rtl_feedback;
      r = r * ltr_invmag + data_l[pos2] * ltr_feedback;
      
      l = accum_l * filter_invmag + l * filter_mag;
      r = accum_r * filter_invmag + r * filter_mag;
      
      accum_l = l;
      accum_r = r;
      
      data_l[pos] = l;
      data_r[pos] = r;
      
      buffer.write(l);
      buffer.write(r);
      
      pos=(pos+1)%datasize;
    }
    
    return buffer.read();
  }
}

public class Vcf303 extends AFilter {
  float scale;
  
  public float env_mod = 0.5;
  public float cutoff = 0.5;
  public float resonance = 1;
  public float decay = 1;
  public float trigger = 0.001;

  float d1, d2, c0, dec, res, e0;
  int envpos;
  PVector abc;
  
  public Vcf303(Piper reader, float srate) {
    super(reader, srate);
    scale = PI * rsrate;
    initialize();
  }
  
  void initialize() {
    d1 = d2 = c0 = 0.0; 
    envpos = 0;  
    e0 = exp(5.613 - 0.8 * env_mod + 2.1553 * cutoff - 0.7696 * (1.0 - resonance));
    e0 *= scale;
    if(trigger>0) {
      float e1 = exp(6.109 + 1.5876 * env_mod + 2.1553 * cutoff - 1.2 * (1.0 - resonance));
      e1 *= scale;
      c0 = e1 - e0;
    }
    float d = 0.2 + (2.3 * decay);
    d *= srate;
    d = pow(0.1,1.0/d);
    dec = pow(d,64);
    res = exp(-1.2 + 3.455 * resonance);
    abc = recalc_a_b_c();
  }
  
  public void randomize() {
    env_mod = random(1);
    cutoff = random(1);
    resonance = random(1);
    decay = random(1);
    trigger = random(1)<0.2?random(0.02):0;
    initialize();
  }
  
  float read() {
    if(random(1)<trigger) initialize();
    float in = reader.read();
    float sample = abc.x * d1 + abc.y * d2 + abc.z * in;

    d2 = d1;
    d1 = sample;
    
    envpos++;
    if(envpos >=64) {
      envpos = 0;
      c0 *= dec;
      abc = recalc_a_b_c();
    }
    return sample;
  }
  
  PVector recalc_a_b_c() {
    float whopping = e0 + c0;
    float k = exp(-whopping / res);
    float a = 2.0 * cos(2.0 * whopping) * k;
    float b = -k * k;
    return new PVector(a, b, (1.0 - a - b) * 0.2);
  }
}
