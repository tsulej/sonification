public class AuPhaser extends AFilter {
  float gain, fbout, lfoskip, phase;

  float[] old;
  float mSampleRate = 128;
  //constants
  float phaserlfoshape = 4.0;
  int lfoskipsamples = 20; //how many samples are processed before recomputing lfo
  int numStages = 24;
  //defaults
  float mFreq = 0.4, mPhase = 0;
  int mStages = 2, mDryWet = 128, mDepth = 100, mFeedback = 0;
  int skipcount = 0;

  public AuPhaser(Piper reader, float srate) {
    super(reader, srate);
    mSampleRate = srate;
    initialize();
  }

  public void initialize() {
    gain = 0;
    fbout = 0;
    lfoskip = mFreq * 2 * PI / mSampleRate;
    phase = mPhase * PI / 180;
    old   = new float[mStages];
  }

  public void randomize() {
    initialize();
  }

  public float read() {
    float in = reader.read();
    float m = in + fbout * mFeedback / 100;
    if ( (( skipcount++) % lfoskipsamples ) == 0 ) { //recomopute lfo
      gain = (1.0 + cos(skipcount * lfoskip + phase)) / 2.0; //compute sine between 0 and 1
      gain = exp(gain * phaserlfoshape) / exp(phaserlfoshape); // change lfo shape
      gain = 1.0 - gain / 255.0 * mDepth; // attenuate the lfo
    }
    //phasing routine
    for ( int j = 0; j<mStages; j++) {
      float tmp = old[j];
      old[j] = gain * tmp + m;
      m = tmp - gain * old[j];
    }
    fbout = m;
    return (float) (( m * mDryWet + in * (mDryWet)) );
  }
}


