// Copyright (c) 2012 Alex Wiltschko
// 
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.


#import "ViewController.h"
#import "FFTBufferManager.h"
#import "aurio_helper.h"


#define CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))

@interface ViewController ()

@property(nonatomic,assign)	FFTBufferManager*			fftBufferManager;
@property(nonatomic,assign)	DCRejectionFilter*			dcFilter;
@property(nonatomic,assign)	Float32*					l_fftData;
@property(nonatomic,assign)	Float32*						fftData;
@property(nonatomic,assign)	NSUInteger					fftLength;
@property(nonatomic,assign)	Boolean                     hasNewFFTData;
@property(nonatomic,assign) int                     freqHop;
@property(nonatomic,strong) NSMutableArray         *frequencyHints;
@end

@implementation ViewController

- (void)dealloc
{
 
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    
    self.audioManager = [Novocaine audioManager];
    self.frequencyHints =[NSMutableArray new];
    self.freqHop=1;
    
#if TARGET_IPHONE_SIMULATOR
        [self decoderSetup];
         [self encoderSetup];
#else
//     [self encoderSetup];
#endif
   

    // START IT UP YO
    [self.audioManager play];

}

-(void)encoderSetup{
    __weak ViewController * wself = self;
    
      
    float fs = 44100;           //sample rate
    uint32_t i = 0;
    
    
    __block uint32_t L =4096;
    
    /* vector allocations*/
    float *input = new float [L];
    float *mag = new float[L/2];
    float *phase = new float[L/2];
    
    
    for (i = 0 ; i < L; i++)
    {
        input[i] = 0;
    }
    
    float amplitude=1;
    

    
    float binSize = L/fs;
    int dataSamples = 32;
    int minFreq = 18000;
    int maxFreq = 20000; //19400
    self.freqHop = (maxFreq-minFreq)/dataSamples;
    
//    17980 18497 18993 19480
//    18000 18500 19000 19500
    
    for (int i=0; i<dataSamples; i++) {
        int freq = minFreq + ( i*self.freqHop);
        int bin = binSize*freq;
        printf("freq %d index %d\n", freq , bin)    ;
        float a = amplitude/L;
        if((int)i%2==0)a=a*0.0;
        
        
        NSMutableDictionary *hint = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithInt:freq],@"frequency",
                                     @0,@"magnitude",
                                     nil];
        [ self.frequencyHints addObject:hint];
        
         input[bin ]=a;
    }

    
    uint32_t log2n = log2f((float)L);
    
    FFTSetup fftSetup;
    COMPLEX_SPLIT A;
    A.realp = (float*) malloc(sizeof(float) * L/2);
    A.imagp = (float*) malloc(sizeof(float) * L/2);
    
    
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
    
    /// FREQ DOMAIN
    /// 1. take the interleaved planar buffer (r1,i1,r2,i2,...) into the split complex buffer
    vDSP_ctoz((COMPLEX *) input, 2, &A, 1, L/2);
    
    /// TIME DOMAIN
    /// 2. convert to a wave take the inverse transform of the complex split buffer
    vDSP_fft_zrip(fftSetup, &A, 1, log2n, FFT_INVERSE);
    
    
    /// CONVERT THE COMPLEX WAVE TO PCM
    /// 3. somehow convert the complex number into a wave
    /// GET THE MAGNITUDES
    /// 8. take the forward transform of the wave amplitude
    mag[0] = sqrtf(A.realp[0]*A.realp[0]);
    
    vDSP_zvphas (&A, 1, phase, 1, L/2);
    phase[0] = 0;
    
    
    //create a wave from phase and magnitude
    for(i = 1; i < L/2; i++){
        mag[i] = sqrtf(A.realp[i]*A.realp[i] + A.imagp[i] * A.imagp[i])*cosf(phase[i]);
    }
    printf("----magnitude\n");
    for (i = 0 ; i < L/4; i++)
    {
        printf("%f\n", mag[i]);
    }
    printf("----magnitude\n");
    
    __block long counter =0;
    
    [self.audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels,AudioBufferList *ioData)
     {
         
         //         float samplingRate = wself.audioManager.samplingRate;
         for (int i=0; i < numFrames; ++i)
         {
             for (int iChannel = 0; iChannel < numChannels; ++iChannel)
             {
                 int index = counter%(L/2);
                 float val = mag[index];
                 //                 NSLog(@"%d %f",index,val);
                 data[i*numChannels + iChannel] = val;
             }
             counter++;
         }
     }];

    

}

-(void)decoderSetup{
    
    __weak ViewController * wself = self;
    
    self.dcFilter = new DCRejectionFilter[2];
    
    UInt32 maxFPS=4096*4; // take this from novocaine
    
    self.fftBufferManager = new FFTBufferManager(maxFPS);
    self.l_fftData = new Float32[maxFPS/2];
    
    
    // VOICE-MODULATED OSCILLATOR
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels, AudioBufferList *ioData)
     {
         
         // Remove DC component
//         for(UInt32 i = 0; i < ioData->mNumberBuffers; ++i){
//             wself.dcFilter[i].InplaceFilter((Float32*)(ioData->mBuffers[i].mData), numFrames);
//         }
         
         
         if (wself.fftBufferManager->NeedsNewAudioData()){
             wself.fftBufferManager->GrabAudioData(ioData);
             
//             wself.fftBufferManager->GrabAudioDataFloat32(data,numFrames);
             
//             printf("grabbing data<<-------------------------\n");
         }
         
         
         if (wself.fftBufferManager->HasNewAudioData())
         {
             
             if (wself.fftBufferManager->ComputeFFT(wself.l_fftData)){
                 
                 [wself setFFTData:wself.l_fftData length:wself.fftBufferManager->GetNumberFrames() / 2];
             }else{
                 wself.hasNewFFTData = NO;
             }
         }
         
         if (wself.hasNewFFTData)
         {
             
             wself.hasNewFFTData = NO;
             
        
            /*
  
             float max=0;
             for (int i = 0 ; i < wself.fftLength; i++)
             {
                 
                 int freq = (int)(i*freqWidth);
                 float mag =wself.fftData[i];
                 
//                 if(mag>1 &&freq>16000){
//                     
//                     [wself.dataFreqs setObject:[NSNumber numberWithFloat:mag] forKey:[NSString stringWithFormat:@"%d",freq]];
//                     
//                 }
                 
                 if(freq>17900 && freq<18100 ){
//                     printf("freq=%d mag=%f\n",freq,mag);
                     
                     if(mag>max){
                         max=mag;
                     }
                 }
                 
//                 if(freq==16640
//                    ){
//                     
//                     [wself.dataFreqs setObject:[NSNumber numberWithFloat:mag] forKey:[NSString stringWithFormat:@"%d",freq]];
//                     
//                 }
             }
             */
             
             float binWidth = wself.fftLength /(44100.0/2);
             float freqSearchWindow = wself.freqHop*.75;
          
             NSMutableString *result=[NSMutableString new];
             for( int i=0; i<[wself.frequencyHints count];i++){
                 
                 NSMutableDictionary *hint = [wself.frequencyHints objectAtIndex:i];
                 NSNumber *frequencyValue = [hint objectForKey:@"frequency"];
                 float lastMax =[[hint objectForKey:@"magnitude"]floatValue];
                 
                 int frequency = [frequencyValue intValue];
                 int freqWindowBeginsAt = frequency - (freqSearchWindow/2);
                 int freqWindowEndsAt   = frequency + (freqSearchWindow/2);
                
                 int binStarts = binWidth*freqWindowBeginsAt;
                 int binEnds = binWidth*freqWindowEndsAt;
                 
                 float max =0;
                 
                 for (int i=binStarts; i<=binEnds; i++) {
                     
                     float magnitude =wself.fftData[i];
//                     max+=magnitude;
                     if(magnitude>max){
                         max=magnitude;
                     }
                 }
                 
                 max = lastMax*0.6 + max*0.4;
                 [hint setObject:[NSNumber numberWithFloat:max] forKey:@"magnitude"];
                 
                 float maxref=0.2;
                 
                 if(i> [wself.frequencyHints count]-16){
                     maxref=0.1;
                 }
                 
                 if(i> [wself.frequencyHints count]-8){
                     maxref=0.035;
                 }
                 
                 if(max> maxref){

                     [result appendString:@"1"];
                      printf("(%d -%d) (%d -%d) %d peak> %f [1]\n",binStarts,binEnds,freqWindowBeginsAt,freqWindowEndsAt,frequency, max);
                 }else{
                       [result appendString:@"0"];
                      printf("(%d -%d) (%d -%d) %d off > %f [0]\n",binStarts,binEnds,freqWindowBeginsAt,freqWindowEndsAt,frequency,max);
                 }
                 
               
                 
             }
             printf("---------- result= %s\n",[result UTF8String]);

           
             
//             NSLog(@"dataFreqs=%@",wself.dataFreqs);
            
             
//             
//             int y, maxY;
//             maxY = drawBufferLen;
//             for (y=0; y<maxY; y++)
//             {
//                 CGFloat yFract = (CGFloat)y / (CGFloat)(maxY - 1);
//                 CGFloat fftIdx = yFract * ((CGFloat)wself.fftLength);
//                 
//                 double fftIdx_i, fftIdx_f;
//                 fftIdx_f = modf(fftIdx, &fftIdx_i);
//                 
//                 SInt8 fft_l, fft_r;
//                 CGFloat fft_l_fl, fft_r_fl;
//                 CGFloat interpVal;
//                 
//                 fft_l = (wself.fftData[(int)fftIdx_i] & 0xFF000000) >> 24;
//                 fft_r = (wself.fftData[(int)fftIdx_i + 1] & 0xFF000000) >> 24;
//                 fft_l_fl = (CGFloat)(fft_l + 80) / 64.;
//                 fft_r_fl = (CGFloat)(fft_r + 80) / 64.;
//                 interpVal = fft_l_fl * (1. - fftIdx_f) + fft_r_fl * fftIdx_f;
//                 
//                 interpVal = CLAMP(0., interpVal, 1.);
//                 if(interpVal>0)
//                 printf("%d interpVal %f\n",y,interpVal);
//                 
//             }
             
         }
   
     }];

    
}


- (void)setFFTData:(Float32 *)FFTDATA length:(NSUInteger)LENGTH
{
	if (LENGTH != self.fftLength)
	{
		self.fftLength = LENGTH;
		self.fftData = (Float32 *)(realloc(self.fftData, LENGTH * sizeof(Float32)));
	}
	memmove(self.fftData, FFTDATA, self.fftLength * sizeof(Float32));
	self.hasNewFFTData = YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

@end
