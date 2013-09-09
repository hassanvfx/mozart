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

#define BIT_SET(a,b) ((a) |= (1<<(b)))
#define BIT_CLEAR(a,b) ((a) &= ~(1<<(b)))
#define BIT_FLIP(a,b) ((a) ^= (1<<(b)))
#define BIT_CHECK(a,b) ((a) & (1<<(b)))

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
@property(nonatomic,assign) int                     encoderWaveLength;
@property(nonatomic,assign) float*                     encoderStream;
@property(nonatomic,assign) int                     encoderStreamLength;
@property(nonatomic,assign) int                     lastPacketIndex;
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
    
    NSMutableArray *packets = [self packData32bitsX16:@"hello world hello world hello world hello world"];
    [self setupPacketsAsEncoderOutput:packets repeating:8];
    
#if TARGET_IPHONE_SIMULATOR
    [self decoderSetup];
    [self encoderSetup];
#else
    //     [self encoderSetup];
#endif
    
    
    // START IT UP YO
    [self.audioManager play];
    
}

-(void)setupPacketsAsEncoderOutput:(NSMutableArray*)packets repeating:(int)count{
    
    int totalsamples = count * packets.count *self.encoderWaveLength;
    float *result = new float[totalsamples];
    int index =0;
    
    for (int i=0; i<packets.count; i++) {
        NSDictionary *packet =[packets objectAtIndex:i];
        NSData *waveForm = [packet objectForKey:@"waveform"];
        float *waveBytes = new float[self.encoderWaveLength];
        [waveForm getBytes:waveBytes];
        
        for (int j=0; j<count; j++) {
            memcpy(result+ (index*self.encoderWaveLength ), waveBytes, self.encoderWaveLength*sizeof(float));
            ++index;
        }
    }
    
    self.encoderStream = result;
    self.encoderStreamLength =totalsamples;
    
   
    
//    float *encodedWaveForm=[self encodeDataToWave32:1];
//    NSData *waveForm2=[NSData dataWithBytes:encodedWaveForm length:2048*sizeof(float)];
//    float *waveBytes2 = new float[2048];
//    [waveForm2 getBytes:waveBytes2];
//    
//    //self.encoderStream = [self encodeDataToWave32:1];
//    self.encoderStream = waveBytes2;
//     self.encoderStreamLength =self.encoderWaveLength;

}

-(void  )unpackData2BytesX16:(int)pack{
    
    int index=0;
    int indexInverted=0;
    int onCount=0;
    int status=0;
    
   
    char* messageBits=new char[3];
    messageBits[0]='\0';
    messageBits[1]='\0';
    messageBits[2]='\0';
    
    int position=0;
    int onRealCount=0;
    
    for (int i=0; i<4; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(index, i);
        }
        position++;
    }
    
    for (int i=0; i<16; i++) {
        
        
        char *pointer = messageBits+(i/8);
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(*pointer, i);
            onRealCount++;
        }else{
            BIT_CLEAR(*pointer, i);
        }
        position++;
    }
    
    for (int i=0; i<4; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(onCount, i);
        }
        position++;
    }
    
    for (int i=0; i<4; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(indexInverted, i);
        }
        position++;
    }
    
    for (int i=0; i<4; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(status, i);
        }
        position++;
    }
    
//    char message[3];
//    sprintf(message, "%d", messageBits);
//    NSString *msg = [NSString stringWithUTF8String:&messageBits];
    
    if(index==(16-indexInverted) && onRealCount==onCount){
        printf("VALID   idx %d idxChk %d onBits %d status %d msg %c%c\n",
               index,
               indexInverted,
               onCount,
               status,
               messageBits[0],
               messageBits[1]);
    }else{
        printf("INVALID idx %d idxChk %d onBits %d status %d\n",
               index,
               indexInverted,
              
               onCount,
               status);
    }

}


-(NSMutableArray*)packData32bitsX16:(NSString*)data{
    
    NSMutableArray *result= [NSMutableArray new];
    
    int fullmessageBytesLength=4;
    int messageLengthPerPacketBits = 16;
    int maxPacketsNumber = 16;
    int maxDataBytes=(messageLengthPerPacketBits*maxPacketsNumber)/8;
//    int maxDataBits= (maxDataBytes)*8;
    int messageBytesPerPacket = messageLengthPerPacketBits/8;
    
    NSData *bytes = [data dataUsingEncoding:NSUTF8StringEncoding];
    printf("---------------\n");
    printf("sizeOfData %d\n",bytes.length);
    
    int maxBytes =(int) fmin( bytes.length, maxDataBytes);

    char *output=new char[32];
    
    for (int i=0; i<32; i++) {
        output[i]=0;
    }
    
    [bytes getBytes:output length:maxBytes];
    
//    output=(char*)"abcdefghijklmnopqrstuvwxyz";
    
//   
//    
//    for (int i=0; i<maxBytes; i++) {
//        output[i]=input[i];
//    }
//
    
    for (int i=0; i<32; i++) {
        char c = output[i];
        printf("%2d = %c ",i,output[i]);
        for (int i=0; i<8; i++) {
            if(BIT_CHECK(c, i)){
                printf("1");
            }else{
                printf("0");
            }
    
        }
          printf("\n");
    }
    
    


    
    
//    printf("input %s\n",input);
    printf("output %s\n",output);
    
    int requiredPackets = (maxBytes*8)/messageLengthPerPacketBits;
    self.lastPacketIndex = fmin(requiredPackets+1,16);
    
    printf("requiredPackets %d\n",requiredPackets);
    
    printf("---------------\n");
    for(int i=0;i<maxPacketsNumber;i++){
        // -- first param destination adress
        // -- second param data source
        // -- third param bytestocppy
        char *packetData = new char[4];
  
        
        int startBytes = i*messageBytesPerPacket;
    
         for (int j=0; j<messageBytesPerPacket; j++) {
             
             char letter = output[startBytes+j];
             packetData[j]  =letter;
            
         }
        
//        memcpy(packetData, output+(i*messageBytesPerPacket), 2*sizeof(char));
        printf("packet %d content ''%c%c''\n",i,packetData[0],packetData[1]);
        
        int highbitsCount=0;
        printf("message part > ");
        //check the final output
        for (int i=0; i<2*8; i++) {
            char letter = packetData[ i/8];
            
            if(BIT_CHECK( letter, i%8)){
                   printf("1");
                ++highbitsCount;
            }else{
                   printf("0");
            }
                  
           
        }
        printf("\n");
        printf("High bits in message = %d\n",highbitsCount);
        
        int packetIndex = i;
        int packetIndexInverted = maxPacketsNumber-i;
        
        // FORMAT
        //  ndex    message       Hbits  ndex-1
        //  0000 0000000000000000 0000   0000
        
        for (int i=0; i<sizeof(char)*8; i++) {
            unsigned int bitmask = 1 << i;
            if( (packetIndex & bitmask) ) {
                printf("1");
            } else{
                printf("0");
            }
        }
        printf("\n");
        
        for (int i=0; i<sizeof(char)*8; i++) {
            unsigned int bitmask = 1 << i;
            if( (packetIndexInverted & bitmask) ) {
                printf("1");
            } else{
                printf("0");
            }
        }
        printf("\n");
        
        /// CREATE THE FINAL MESSAGE
        
        int finalPacket=0;
        int position=0;
        
        /// APPEND THE PART BYTES
        
        for (int i=0; i<4; i++) {
            
            if( BIT_CHECK(packetIndex,i) ){
                BIT_SET(finalPacket, position);
            }
            position++;
            
        }
        
        /// APPEND THE MESSAGE
        
        for (int i=0; i<messageBytesPerPacket*8; i++) {
            
            if( BIT_CHECK((int)* packetData,i) ){
                BIT_SET(finalPacket,   position);
            }
              position++;
        }
        
        /// APPEND THE ON BITS COUNT (IN MESSAGE)
        
        for (int i=0; i<4; i++) {
            
            if( BIT_CHECK((int) highbitsCount,i) ){
                BIT_SET(finalPacket, position);
            }
             position++;
        }
        
        /// APPEND THE INVERTED PART INDEX
        
        for (int i=0; i<4; i++) {
            
            if( BIT_CHECK((int) packetIndexInverted,i) ){
                BIT_SET(finalPacket, position);
            }
            position++;
        }
        
        Boolean iPacketOn = false;
         if(i<=requiredPackets){
             iPacketOn=true;
         }
        
        /// APPEND THE STATUS HELPERS
        for (int j=0; j<4; j++) {
            
            if(iPacketOn){
                BIT_SET(finalPacket, j+4+(messageBytesPerPacket*8)+4+4);
            }
        }
        
        
        /// PRINT THE FINAL OUTPUT
        
        //        finalPacket =  2 << ((int)&packetData & 6);
        //        finalPacket =  3 << ((int)&packetData & 7);
        
        printf("final packet >%d >> ",finalPacket);
        //check the final output
        for (int i=0; i<fullmessageBytesLength*8; i++) {
            int bit;
            bit= 1 & (finalPacket>>i);
            printf("%d",bit);
            if( i+1==4 ||
               i+1==4+(messageBytesPerPacket*8) ||
               i+1==4+(messageBytesPerPacket*8)+4 ||
               i+1==4+(messageBytesPerPacket*8)+4 +4){
                printf(" ");
            }
        }
        printf("\n");
        printf("---------------\n");
        
        //CREATE THE ENCODED WAVEFROM
     
        float *encodedWaveForm=[self encodeDataToWave32:finalPacket];
        
        NSData *waveForm=[NSData dataWithBytes:encodedWaveForm length:self.encoderWaveLength *sizeof(float)];
        
        NSDictionary *packet = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSNumber numberWithInt:packetIndex],@"index",
                                [NSNumber numberWithInt:finalPacket],@"data",
                                [NSNumber numberWithBool:iPacketOn],@"status",
                               waveForm,@"waveform",
                                nil];
        
        [result addObject:packet];
        
    }
    
    return  result;

}


-(float *) encodeDataToWave32:(int)data{
    
    float fs = 44100;           //sample rate
    uint32_t i = 0;
    
    
    __block uint32_t L =4096;
    
    self.encoderWaveLength=L/2;
    
    /* vector allocations*/
    float *impulses = new float [L];
    float *magWave = new float[L/2];
    float *phase = new float[L/2];
    
    
    for (i = 0 ; i < L; i++)
    {
        impulses[i] = 0;
    }
    
//    float amplitude=1;
    
    
    
    float binSize = L/fs;
    int dataSamples = 32;
    int minFreq = 18000;
    int maxFreq = 20000; //19400
    self.freqHop = (maxFreq-minFreq)/dataSamples;
    
    //    17980 18497 18993 19480
    //    18000 18500 19000 19500
    
    Boolean appendHints=false;
    
    if ([self.frequencyHints count]<=0) {
        appendHints=true;
    }
    
    for (int i=0; i<dataSamples; i++) {
        
        
        int freq = minFreq + ( i*self.freqHop);
        
        if(appendHints){
        NSMutableDictionary *hint = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithInt:freq],@"frequency",
                                     @0,@"magnitude",
                                     nil];
        [ self.frequencyHints addObject:hint];
        }
        
        float amplitude=0.0;
        
        if( BIT_CHECK(data, i)){
            amplitude=2.0;
        }
        
//        amplitude=10.0;
        
//        if( i%2==0){
//            amplitude=1.0;
//        }

        
        float a = amplitude/L;
        //        if((int)i%2==0)a=a*0.0;
        
        
        //        int startFreq   = freq - (freqWindow/2);
        //        int endFreq     = freq + (freqWindow/2);
        //
        //        for (int j=startFreq; j<endFreq; j++) {
        //
        //            int bin = binSize*j;
        //            input[bin ]=a;
        //            printf("freq %d index %d\n", j , bin);
        //        }
        
        
        int bin = binSize*freq;
        impulses[bin ]=a;
//        printf("freq %d index %d\n", freq , bin);
        
    }
    
    
    uint32_t log2n = log2f((float)L);
    
    FFTSetup fftSetup;
    COMPLEX_SPLIT A;
    A.realp = (float*) malloc(sizeof(float) * L/2);
    A.imagp = (float*) malloc(sizeof(float) * L/2);
    
    
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
    
    /// FREQ DOMAIN
    /// 1. take the interleaved planar buffer (r1,i1,r2,i2,...) into the split complex buffer
    vDSP_ctoz((COMPLEX *) impulses, 2, &A, 1, L/2);
    
    /// TIME DOMAIN
    /// 2. convert to a wave take the inverse transform of the complex split buffer
    vDSP_fft_zrip(fftSetup, &A, 1, log2n, FFT_INVERSE);
    
    
    /// CONVERT THE COMPLEX WAVE TO PCM
    /// 3. somehow convert the complex number into a wave
    /// GET THE MAGNITUDES
    /// 8. take the forward transform of the wave amplitude
    magWave[0] = sqrtf(A.realp[0]*A.realp[0]);
    
    vDSP_zvphas (&A, 1, phase, 1, L/2);
    phase[0] = 0;
    
    
    //create a wave from phase and magnitude
    for(i = 1; i < L/2; i++){
        magWave[i] = sqrtf(A.realp[i]*A.realp[i] + A.imagp[i] * A.imagp[i])*cosf(phase[i]);
    }
//    printf("----magnitude wave for : %d\n",data);
//    for (i = 0 ; i < L/2; i++)
//    {
//        printf("%f\n", magWave[i]);
//    }
//    printf("----magnitude\n");
    
 
    return magWave;
    
}


-(void)encoderSetup{
    __weak ViewController * wself = self;
  
    
    __block long counter =0;
    
    [self.audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels,AudioBufferList *ioData)
     {
         
         //         float samplingRate = wself.audioManager.samplingRate;
         for (int i=0; i < numFrames; ++i)
         {
             for (int iChannel = 0; iChannel < numChannels; ++iChannel)
             {
                 int index = counter%(wself.encoderStreamLength);
                 float val = wself.encoderStream[index];
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
    
    UInt32 maxFPS=4096; // take this from novocaine
    
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
             
             
             
             float binWidth = wself.fftLength /(44100.0/2);
             float freqSearchWindow = wself.freqHop*.75;
             
             NSMutableString *result=[NSMutableString new];
             
             int packet =0;
             
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
                 
//                 max = lastMax*0.6 + max*0.4;
                 [hint setObject:[NSNumber numberWithFloat:max] forKey:@"magnitude"];
                 
                 float maxref=0.1;
                 
                 if(i> [wself.frequencyHints count]-16){
                     maxref=0.05;
                 }
                 
                 if(i> [wself.frequencyHints count]-8){
                     maxref=0.01;
                 }
                 
                 
                 
                 if(max> maxref){
                      BIT_SET(packet, i);
                     
                     [result appendString:@"1"];
                     printf("(%d -%d) (%d -%d) %d peak> %f [1]\n",binStarts,binEnds,freqWindowBeginsAt,freqWindowEndsAt,frequency, max);
                 }else{
                     
                     BIT_CLEAR(packet, i);
                     [result appendString:@"0"];
                     printf("(%d -%d) (%d -%d) %d off > %f [0]\n",binStarts,binEnds,freqWindowBeginsAt,freqWindowEndsAt,frequency,max);
                 }
                 
                 if( i+1==4 ||
                    i+1==4+(2*8) ||
                    i+1==4+(2*8)+4 ||
                    i+1==4+(2*8)+4 +4){
                      [result appendString:@" "];
                 }
                 
                 
             }
             printf("---------- result= %s\n",[result UTF8String]);

             [wself unpackData2BytesX16:packet];
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
