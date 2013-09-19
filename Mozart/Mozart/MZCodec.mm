
//  MZCodecHelper.m
//  Novocaine
//
//  Created by Hassan Uriostegui on 9/10/13.
//  Copyright (c) 2013.
//

#import "MZCodec.h"
#import "FFTBufferManager.h"
#import "MZCodecHelper.h"
#import "NSMutableArray_Shuffling.h"
#import <MediaPlayer/MediaPlayer.h>
#import "Novocaine.h"

@implementation MZCodecPacketDescriptor
@end

@implementation MZCodecDescriptor
@end

@interface MZCodec ()
@property (nonatomic, strong) Novocaine *audioManager;
@property(nonatomic,strong)NSMutableDictionary *encoderBitReferenceDictionary;
@property(nonatomic,strong)NSString *encoderMessageHint;
@property(nonatomic,assign)int encoderLastValidPacketIndex;
@property(nonatomic,assign)int freqHop; //rename this
@property(nonatomic,strong)NSMutableArray *codecFrequenciesTable;


@property(nonatomic,assign) float*                  encoderStream;
@property(nonatomic,assign) int                     encoderStreamLength;
@property(nonatomic,assign) float                   systemPreviousVolume;
//---

@property(nonatomic,assign)	FFTBufferManager*			fftBufferManager;
@property(nonatomic,assign)	DCRejectionFilter*			dcFilter;
@property(nonatomic,assign)	Float32*					l_fftData;
@property(nonatomic,assign)	Float32*						fftData;
@property(nonatomic,assign)	NSUInteger					fftLength;
@property(nonatomic,assign)	Boolean                     hasNewFFTData;



@property(nonatomic,assign) CFAbsoluteTime          decoderInitTime;
@property(nonatomic,assign) CFAbsoluteTime          decoderEndTime;

@property(nonatomic,strong) NSMutableDictionary     *decoderPackets;
@property(nonatomic,strong) NSMutableDictionary     *decodedContents;
@property(nonatomic,assign) long                    counter;

@property(nonatomic,assign) float                   lastMean;
@property(nonatomic,assign) float                   lastBelowMean;
@property(nonatomic,assign) float                   lastMin;

//---


@end


@implementation MZCodec


+(MZCodecPacketDescriptor*)descriptor16bits{
    MZCodecPacketDescriptor *descriptor = [MZCodecPacketDescriptor new];
    
    descriptor.partIndexBits                    = 2;
    descriptor.partMessageBits                  = 8;
    descriptor.partChecksumBits                 = 3;
    descriptor.partIndexNegBits                 = 2;
    descriptor.partStatusBits                   = 1;
    
    descriptor.completePacketLenghtBytes       = 2;
    descriptor.completePacketLenghtBits        = descriptor.completePacketLenghtBytes*8;
    descriptor.maxPacketsNumber                = 4;
    
    descriptor.maxMessageBytes                 = ( descriptor.partMessageBits/8)* descriptor.maxPacketsNumber;
    descriptor.maxMessageBits                  =  descriptor.maxMessageBytes*8;
    descriptor.numberOfSamples                 = 16;
    return descriptor;
}
+(MZCodecPacketDescriptor*)descriptor32bits{
    MZCodecPacketDescriptor *descriptor = [MZCodecPacketDescriptor new];
    
    descriptor.partIndexBits                    = 4;
    descriptor.partMessageBits                  = 16;
    descriptor.partChecksumBits                 = 4;
    descriptor.partIndexNegBits                 = 4;
    descriptor.partStatusBits                   = 4;
    
    descriptor.completePacketLenghtBytes       = 4;
    descriptor.completePacketLenghtBits        = descriptor.completePacketLenghtBytes*8;
    descriptor.maxPacketsNumber                = 2;
    
    descriptor.maxMessageBytes                 = ( descriptor.partMessageBits/8)* descriptor.maxPacketsNumber;
    descriptor.maxMessageBits                  =  descriptor.maxMessageBytes*8;
    descriptor.numberOfSamples                 = 32;
    return descriptor;
}


-(id)init{
    self=[super init];
    if(self){
        
        self.packetDescriptor = [MZCodec descriptor16bits];
        self.parameters=[MZCodecDescriptor new];
     
        self.encoderStream  =NULL;
        self.audioManager = [Novocaine audioManager];
   
        [self switch32bitsMode];
        self.fftBufferManager=NULL;
        
        self.decoderExpectedPackets = self.packetDescriptor.maxPacketsNumber;
    }
    return self;
}

#pragma mark entry points

-(void) resetParameters{
    self.parameters.SAMPLING_FREQUENCY  =   44100 ;
    self.parameters.MIN_FREQ            =   18800;
    self.parameters.MAX_FREQ            =   19800;
    
    self.parameters.ENCODER_AMPLITUDE_ON        =   3.0;
    self.parameters.ENCODER_AMPLITUDE_OFF       =   0.0;
    self.parameters.ENCODER_BINS_SIZE           =   4096;
    self.parameters.ENCODER_PACKET_REPEAT       =   4;
    self.parameters.ENCODER_USE_SILENCE         =   0;
    self.parameters.ENCODER_SHUFFLED_VERSIONS   =   1;
    
    self.parameters.DECODER_SAMPLE_SIZE                 =   4096;
    self.parameters.DECODER_HOP_TOLERANCE_PERCENTAGE    =   0.75;
    self.parameters.DECODER_OK_REPEAT_REQUIREMENT       =   2;
    self.parameters.DECODER_USE_MOVING_AVERAGE          =   0.0;
    self.parameters.ENCODER_USE_TEST_PATTERN            =   TEST_PATTERN_OFF;
}

-(void)switch32bitsMode{
    [self resetParameters];
    [self setPacketDescriptor:[MZCodec descriptor32bits]];

    // NO REMOVE !!!!!! THOSE ARE THE GOLDEN VALUES !!
    
//    self.parameters.MIN_FREQ            =   18500;
//    self.parameters.MAX_FREQ            =   20300;
//    self.parameters.ENCODER_PACKET_REPEAT = 64; //very important !!
//    self.parameters.ENCODER_AMPLITUDE_ON  = 4.0;
//    self.parameters.ENCODER_SHUFFLED_VERSIONS =16;
//    self.parameters.DECODER_OK_REPEAT_REQUIREMENT =2;
//    self.parameters.DECODER_USE_MOVING_AVERAGE   =0.75;
//    self.parameters.DECODER_HOP_TOLERANCE_PERCENTAGE =0.95;
//    self.parameters.ENCODER_BINS_SIZE = 4096;  //very important !!
//    self.parameters.DECODER_SAMPLE_SIZE = 4096*4;  //very important !!
        
    self.parameters.MIN_FREQ            =   18500;
    self.parameters.MAX_FREQ            =   20300;
    self.parameters.ENCODER_PACKET_REPEAT = 32; //very important !!
    self.parameters.ENCODER_AMPLITUDE_ON  = AMPLITUDE_ON_5; //4 ->iphone4s and //0.45->iphone5S
    self.parameters.ENCODER_SHUFFLED_VERSIONS = 1;
    self.parameters.DECODER_OK_REPEAT_REQUIREMENT =2;
    self.parameters.DECODER_USE_MOVING_AVERAGE   =0.5;
    self.parameters.DECODER_HOP_TOLERANCE_PERCENTAGE =0.95;
    
    
    self.parameters.ENCODER_BINS_SIZE = 4096;  //very important !!
    self.parameters.DECODER_SAMPLE_SIZE = 4096*2;  //very important !!
    
    [self updateFrequenciesTable];
}



-(void)switch16bitsMode{
    [self resetParameters];
    [self setPacketDescriptor:[MZCodec descriptor16bits]];
    [self updateFrequenciesTable];
}



-(void)setTestPattern:(int)testPattern{
    self.parameters.ENCODER_USE_TEST_PATTERN=testPattern;
    [self setEncoderDataString:@"1234567890123456789012345678901234567890"];
}

-(void)updateFrequenciesTable{
    self.codecFrequenciesTable=[NSMutableArray new];
    float *data=[self encodeDataToWave:0 length:self.packetDescriptor.numberOfSamples];
    free(data);
}


-(void) setEncoderDataWithLong:(long)data{
    [self stopEncoder];
    [self resetEncoder ];
    NSMutableArray *packets =[self packDataLong:data];
    [self setupPacketsAsEncoderOutput:packets];
}


-(void) setEncoderDataString:(NSString*)data{
    [self stopEncoder];
    [self resetEncoder ];
    NSMutableArray *packets =[self packDataString:data];
    [self setupPacketsAsEncoderOutput:packets];
   
}
///
///
///
-(void)stopEncoder{
    [self.audioManager setOutputBlock:nil];
}
-(void)setupEncoder{
    [self prepareEncoder];
}
///
///
///
-(void)stopDecoder{
    [self.audioManager setInputBlock:nil];
    
}
-(void)setupDecoder{
    [self resetDecoder];
    [self prepareDecoder];
}
///
///
///
-(void)startCodec{
    [self.audioManager setForceOutputToSpeaker:YES];
    [self.audioManager play];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.systemPreviousVolume=[MPMusicPlayerController applicationMusicPlayer].volume; //grab current User volume
        if(self.systemPreviousVolume<1.0){
            [[MPMusicPlayerController applicationMusicPlayer] setVolume:1.0];//set system vol to max
        }
        
    });
}
-(void)stopCodec{
    [self.audioManager pause];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.systemPreviousVolume=[MPMusicPlayerController applicationMusicPlayer].volume; //grab current User volume
        [[MPMusicPlayerController applicationMusicPlayer] setVolume:self.systemPreviousVolume];//set system vol to max
        
    });
}
///
///
///
#pragma mark -
#pragma mark PRIVATE STUFF - ENCODER
#pragma mark reset
-(void)resetEncoder{
    
    self.encoderBitReferenceDictionary=[NSMutableDictionary new];
    if( self.encoderStream!=NULL){
        free( self.encoderStream);
        self.encoderStream=NULL;
    }
    self.encoderStreamLength=0;
    self.counter=0;
}


#pragma mark RUN ENCODER

-(void)prepareEncoder{
    __weak MZCodec * wself = self;
    
  
    
    [self.audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
     {
         
         //         float samplingRate = wself.audioManager.samplingRate;
         for (int i=0; i < numFrames; ++i)
         {
             for (int iChannel = 0; iChannel < numChannels; ++iChannel)
             {
                 int index = wself.counter%(wself.encoderStreamLength);
                 float val = wself.encoderStream[index];
                 //                 NSLog(@"%d %f",index,val);
                 data[i*numChannels + iChannel] = val;
             }
             wself.counter++;
         }
     }];
    
    
    
    
}

#pragma  mark set output


-(void) setupPacketsAsEncoderOutput:(NSMutableArray*)packets{
    
    
    
    int count =self.parameters.ENCODER_PACKET_REPEAT;
    
    if(self.parameters.ENCODER_USE_SILENCE){
        
        int totalsamples = count * packets.count *self.parameters.ENCODER_WAVE_LENGHT *2;
        float *result = new float[totalsamples];
        int index =0;
        
        for (int i=0; i<packets.count*2; i++) {
            
            float *waveBytes;
            
            if(i%2==0){
                
                NSDictionary *packet =[packets objectAtIndex:i/2];
                NSData *waveForm = [packet objectForKey:@"waveform"];
                waveBytes = new float[self.parameters.ENCODER_WAVE_LENGHT];
                [waveForm getBytes:waveBytes];
            }else{
                waveBytes= [self encodeDataToWave:0 length:self.packetDescriptor.numberOfSamples];
            }
            
            for (int j=0; j<count; j++) {
                memcpy(result+ (index*self.parameters.ENCODER_WAVE_LENGHT ), waveBytes, self.parameters.ENCODER_WAVE_LENGHT*sizeof(float));
                ++index;
            }
        }
        
        self.encoderStream = result;
        self.encoderStreamLength =totalsamples;
    }else{
        
        int shuffledVersions =self.parameters.ENCODER_SHUFFLED_VERSIONS;
        
        int totalsamples = count * self.encoderLastValidPacketIndex  *self.parameters.ENCODER_WAVE_LENGHT ;
        int totalsamplesShuffle = totalsamples * shuffledVersions ;
        float *result = new float[totalsamplesShuffle];
        int index =0;
        for (int k=0; k<shuffledVersions; k++) {
            
            [packets shuffle];
            
//            NSLog(@"-------->shuffle");
            for (int i=0; i<self.encoderLastValidPacketIndex ; i++) {
                
                float *waveBytes;
                NSDictionary *packet =[packets objectAtIndex:i];
                NSData *waveForm = [packet objectForKey:@"waveform"];
//                int partIndex = [[packet objectForKey:@"index"]intValue];
//                NSLog(@"appending partindex %d",partIndex);
                
                waveBytes = new float[self.parameters.ENCODER_WAVE_LENGHT];
                [waveForm getBytes:waveBytes];
                
                
                for (int j=0; j<count; j++) {
                    memcpy(result+ (index*self.parameters.ENCODER_WAVE_LENGHT), waveBytes, self.parameters.ENCODER_WAVE_LENGHT*sizeof(float));
                    ++index;
                }
                
                free(waveBytes);
                
                
            }
            
        }
        self.encoderStream = result;
        self.encoderStreamLength =totalsamplesShuffle;
    }
    
    
    
    //    float *encodedWaveForm=[self encodeDataToWave:1 length:16];
    //    NSData *waveForm2=[NSData dataWithBytes:encodedWaveForm length:2048*sizeof(float)];
    //    float *waveBytes2 = new float[2048];
    //    [waveForm2 getBytes:waveBytes2];
    //
    //    //self.encoderStream = [self encodeDataToWave32:1];
    //    self.encoderStream = encodedWaveForm;
    //     self.encoderStreamLength =self.encoderWaveLength;
    
}





#pragma mark packer

-(NSMutableArray*)packDataString:(NSString*)string{
    NSData *data= [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self packDataBytes:data];
}

-(NSMutableArray*)packDataLong:(long)number{
    NSData *data= [NSData dataWithBytes:&number length:sizeof(long)];
    unsigned char *b = new unsigned char[4]  ;
     unsigned char *b2 = new unsigned char[4]  ;
    unsigned char *p = (unsigned char *) &number;
    b[0] = p[3];
    b[1] = p[2];
    b[2] = p[1];
    b[3] = p[0];
    long test ;
    
//    NSString *tests= [[NSString alloc]initWithBytes:&b length:4 encoding:NSUTF8StringEncoding];
//    NSData *bytes = [tests dataUsingEncoding:NSUTF8StringEncoding];
//    [bytes getBytes:&b2 length:4];
    b2=b;
    
    test = ((unsigned long)b2[0] << 24) |
    ((unsigned long)b2[1] << 16) |
    ((unsigned long)b2[2] << 8) |
    ((unsigned long)b2[3]);


    
//    long test;
//    [data getBytes:&test length:sizeof(long)];
    
    return [self packDataBytes:data];
}

-(NSMutableArray*)packDataBytes:(NSData*)bytes{
    
    
    
    NSMutableArray *result= [NSMutableArray new];
    MZCodecPacketDescriptor *descriptor = self.packetDescriptor;
    
    int partIndexBits                    = descriptor.partIndexBits;
    int partMessageBits                  = descriptor.partMessageBits;
    int partChecksumBits                 = descriptor.partChecksumBits;
    int partIndexNegBits                 = descriptor.partIndexNegBits;
    int partStatusBits                   = descriptor.partStatusBits;
    
//    int completePacketLenghtBytes       = descriptor.completePacketLenghtBytes;
//    int completePacketLenghtBits        = descriptor.completePacketLenghtBits;
    int maxPacketsNumber                = descriptor.maxPacketsNumber;
    
    int maxMessageBytes                 =descriptor.maxMessageBytes;
//    int maxMessageBits                  = descriptor.maxMessageBits;
    
    
    
    //--fooo("---------------\n");
    int l=bytes.length;
    printf("sizeOfData %d\n",l);
    
    int maxBytes =(int) MIN(l, maxMessageBytes);
    //--fooo("data trunc to %d\n",maxBytes);
    
    //create the max output and pad with zeros
    unsigned char *output=new unsigned char[maxBytes+1];
    [bytes getBytes:output length:maxBytes];
   long test ;
    
    //check long integrity
    test = ((unsigned long)output[3] << 24) |
    ((unsigned long)output[2] << 16) |
    ((unsigned long)output[1] << 8) |
    ((unsigned long)output[0]);
    
 
        for (int i=0; i<maxBytes; i++) {
            char c = output[i];
            printf("%2d = %c ",i,output[i]);
            for (int j=0; j<8; j++) {
                if(BIT_CHECK(c, j)){
                    BIT_SET(test, j*i);
                    printf("1");
                }else{
                    printf("0");
                }
                
            }
           printf("\n");
        }
    


   
    
    
    //    //--fooo("input %s\n",input);
    //    //--fooo("output %s\n",output);
    
    int requiredPackets = (maxBytes)/(partMessageBits/8);
    self.encoderLastValidPacketIndex = fmin(requiredPackets, maxPacketsNumber);
    
    
    //--fooo("requiredPackets %d\n",requiredPackets);
    
    //--fooo("---------------\n");
    
    for(int i=0;i< requiredPackets;i++){
        
        char *packetData = new char[ (partMessageBits/8)+1];
        
        int startBytes = i*(partMessageBits/8);
        
        for (int j=0; j<(partMessageBits/8); j++) {
            
            char letter = output[startBytes+j];
            packetData[j]  =letter;
            
        }
        
        //        memcpy(packetData, output+(i*messageBytesPerPacket), 2*sizeof(char));
        NSData *test =[NSData dataWithBytes:packetData length:3];
        NSString *test2 = [self bitStringContentFromData:test];
        printf("packet %d content ''%c%c' %s'\n",i,packetData[0],packetData[1],[test2 UTF8String]);
        
        
        int highbitsCount=0;
        //--fooo("message part > ");
        //check the final output
        for (int i=0; i<partMessageBits; i++) {
            char letter = packetData[i/8];
            
            if(BIT_CHECK( letter, i%8)){
                //--fooo("1");
                ++highbitsCount;
            }else{
                //--fooo("0");
            }
            
            
        }
        if(highbitsCount==0){
            highbitsCount=(partMessageBits-1);
        }else if(highbitsCount==(partMessageBits-1)){
            highbitsCount=0;
        }
        
        //--fooo("\n");
        //--fooo("High bits in message = %d\n",highbitsCount);
        
        short packetIndex = i;
        short packetIndexInverted = (maxPacketsNumber-1)-i;
        
        // FORMAT
        //  ndex    message       Hbits  ndex-1
        //  00      00000000      00     00
        
        //--fooo("packetIndex         %d >",packetIndex);
        for (int i=0; i<partIndexBits; i++) {
            
            if( BIT_CHECK(packetIndex, i) ) {
                //--fooo("1");
            } else{
                //--fooo("0");
            }
        }
        //--fooo("\n");
        
        //--fooo("packetIndexInverted %d >",packetIndexInverted);
        for (int i=0; i<partIndexNegBits; i++) {
            if( BIT_CHECK(packetIndexInverted, i) ) {
                //--fooo("1");
            } else{
                //--fooo("0");
            }
        }
        //--fooo("\n");
        
        
        //////**********************************
        /// CREATE THE FINAL MESSAGE
        
        int finalPacket=0;
        int position=0;
        
        /// APPEND THE PART BYTES
        
        for (int i=0; i<partIndexBits; i++) {
            
            if( BIT_CHECK(packetIndex,i) ){
                BIT_SET(finalPacket, position);
            }
            position++;
            
        }
        
        /// APPEND THE MESSAGE
        
        for (int i=0; i<partMessageBits; i++) {
            
            int byte = i/8;
            char pointer = packetData[byte];
            if( BIT_CHECK( pointer,i-(byte*8)) ){
                BIT_SET(finalPacket,   position);
            }else{
                BIT_CLEAR(finalPacket,   position);
            }
            position++;
        }
        
        /// APPEND THE ON BITS COUNT (IN MESSAGE)
        
        for (int i=0; i<partChecksumBits; i++) {
            
            if( BIT_CHECK((int) highbitsCount,i) ){
                BIT_SET(finalPacket, position);
            }
            position++;
        }
        
        /// APPEND THE INVERTED PART INDEX
        
        for (int i=0; i<partIndexNegBits; i++) {
            
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
        for (int j=0; j<partStatusBits; j++) {
            
            if(iPacketOn){
                BIT_SET(finalPacket,position);
            }
            ++position;
        }
        
        
        /// PRINT THE FINAL OUTPUT
        
        //        finalPacket =  2 << ((int)&packetData & 6);
        //        finalPacket =  3 << ((int)&packetData & 7);
        
        
        
        //--fooo("final packet >%d >> ",finalPacket);
        //check the final output
        NSString *outputref = [self stringFromPacket:finalPacket];
        [self.encoderBitReferenceDictionary setObject:outputref forKey:outputref];
        
        printf("%d -> %s \n",i,[outputref UTF8String]);
        //--fooo("---------------\n");
        
        //CREATE THE ENCODED WAVEFROM
        
        float *encodedWaveForm=[self encodeDataToWave:finalPacket length:self.packetDescriptor.numberOfSamples];
        
        NSData *waveForm=[NSData dataWithBytes:encodedWaveForm length:self.parameters.ENCODER_WAVE_LENGHT *sizeof(float)];
        
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

#pragma mark wave



-(float *) encodeDataToWave:(int)data length:(int)length{
    
    float fs = self.parameters.SAMPLING_FREQUENCY;           //sample rate
    uint32_t L =self.parameters.ENCODER_BINS_SIZE;
    uint32_t i = 0;
    
    self.parameters.ENCODER_WAVE_LENGHT=L/2;
    
    /* vector allocations*/
    float *impulses = new float [L];
    float *magWave = new float[L/2];
    float *phase = new float[L/2];
    
    
    for (i = 0 ; i < L; i++)
    {
        impulses[i] = 0;
    }
    
    
    float binSize = L/fs;
    int dataSamples = length;
    int minFreq = self.parameters.MIN_FREQ;
    int maxFreq = self.parameters.MAX_FREQ;
    self.freqHop = (maxFreq-minFreq)/dataSamples;
    
    
    Boolean appendHints=false;
    
    if ([self.codecFrequenciesTable count]<=0) {
        appendHints=true;
    }
    
    
        //--fooo("---------------\n");
        //--fooo(" IMPULSES TABLE\n");
        //--fooo("BIN\tFREQ\tMAG\n");
    for (int i=0; i<dataSamples; i++) {
        
        
        int freq = minFreq + ( i*self.freqHop);
        
        if(appendHints){
            NSMutableDictionary *hint = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                         [NSNumber numberWithInt:freq],@"frequency",
                                         @0,@"magnitude",
                                         nil];
            [ self.codecFrequenciesTable addObject:hint];
        }
        
        float amplitude=self.parameters.ENCODER_AMPLITUDE_OFF;
        
        if( BIT_CHECK(data, i)){
            amplitude=self.parameters.ENCODER_AMPLITUDE_ON;
        }
        
        
        switch (self.parameters.ENCODER_USE_TEST_PATTERN) {
            case TEST_PATTERN_1111:
                amplitude =self.parameters.ENCODER_AMPLITUDE_ON;
                break;
            case TEST_PATTERN_0000:
                amplitude =self.parameters.ENCODER_AMPLITUDE_OFF;
                break;
            case TEST_PATTERN_0101:
                amplitude = (i%2==0)? self.parameters.ENCODER_AMPLITUDE_ON : self.parameters.ENCODER_AMPLITUDE_OFF;
                break;
            case TEST_PATTERN_1010:
                amplitude = (i%2!=0)? self.parameters.ENCODER_AMPLITUDE_ON : self.parameters.ENCODER_AMPLITUDE_OFF;
                break;
            case TEST_PATTERN_1001:
                amplitude = (i==0)||(i==dataSamples)? self.parameters.ENCODER_AMPLITUDE_ON : self.parameters.ENCODER_AMPLITUDE_OFF;
                break;
            case TEST_PATTERN_0110:
                amplitude = (i=!0)&&(i=!dataSamples)? self.parameters.ENCODER_AMPLITUDE_ON :self.parameters.ENCODER_AMPLITUDE_OFF;
                break;
                
            default:
                break;
        }
        
        
        float a = amplitude/L;
        
        
        
        
        //        if((int)i%2==0)a=a*0.0;
        
        
        //        int startFreq   = freq - (freqWindow/2);
        //        int endFreq     = freq + (freqWindow/2);
        //
        //        for (int j=startFreq; j<endFreq; j++) {
        //
        //            int bin = binSize*j;
        //            input[bin ]=a;
        //            //--fooo("freq %d index %d\n", j , bin);
        //        }
        
        
        int bin = binSize*freq;
        impulses[bin ]=a;
        //--fooo("%d\t%d\t%f\n", bin, freq , a);
        
    }
    //--fooo("---------------\n");
    
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
    //    //--fooo("----magnitude wave for : %d\n",data);
    //    for (i = 0 ; i < L/2; i++)
    //    {
    //        //--fooo("%f\n", magWave[i]);
    //    }
    //    //--fooo("----magnitude\n");
    
    
    return magWave;
    
}

#pragma mark -
#pragma mark PRIVATE STUFF - DECODER
#pragma mark reset

-(void)resetDecoder{
    
    UInt32 maxFPS=self.parameters.DECODER_SAMPLE_SIZE; // take this from novocaine
   
    if(self.fftBufferManager==NULL){
        self.dcFilter = new DCRejectionFilter[2];
        self.fftBufferManager = new FFTBufferManager(maxFPS);
        self.l_fftData = new Float32[maxFPS/2];
    }
    
    self.decoderFalsevalids=0;
    self.decoderValids=0;
    self.decoderInvalids=0;
    
    self.decoderInitTime=CFAbsoluteTimeGetCurrent();
    self.decoderEndTime  =-1;
    self.decoderPackets  =[NSMutableDictionary new];
    self.decodedContents =[NSMutableDictionary new];
    
    self.decoderDataByIndex=[NSDictionary new];
    self.decoderDecodingLength = 0;
    
}

-(void)preprocessFrequency{
    
      __weak MZCodec * wself = self;
    
    float binWidth = wself.fftLength /((float) wself.parameters.SAMPLING_FREQUENCY/(float)2);
    float freqSearchWindow = wself.freqHop* wself.parameters.DECODER_HOP_TOLERANCE_PERCENTAGE;
    
    
    double mean=0;
    double min=10000000;
    
    for( int i=0; i<wself.codecFrequenciesTable.count;i++){
        
        NSMutableDictionary *hint = [wself.codecFrequenciesTable objectAtIndex:i];
        NSNumber *frequencyValue = [hint objectForKey:@"frequency"];
         
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
    
    if (max<min) {
        min=max;
    }
    
       [hint setObject:[NSNumber numberWithFloat:max] forKey:@"lastpeak"];
        
        
        mean+=max;
        
    }
    mean=mean/wself.codecFrequenciesTable.count;
    wself.lastMean =mean;
    wself.lastMin  =min;
    
    
    int belowMeancount =0;
    
    for( int i=0; i<wself.codecFrequenciesTable.count;i++){
        
        NSMutableDictionary *hint = [wself.codecFrequenciesTable objectAtIndex:i];
        float peak =[[hint objectForKey:@"lastpeak"]floatValue];
        if(peak<mean){
            ++belowMeancount;
        }
       
    }
    
    wself.lastBelowMean = belowMeancount;
    
}

-(int)processFrequency{
    
    
    __weak MZCodec * wself = self;
    
    
    int packet =0;
    
    for( int i=0; i<wself.codecFrequenciesTable.count;i++){
        
        NSMutableDictionary *hint = [wself.codecFrequenciesTable objectAtIndex:i];
        float peak =[[hint objectForKey:@"lastpeak"]floatValue];
        
        
        float lowPart  = wself.lastMean - wself.lastMin;
        float thershold   = wself.lastMin + (lowPart/ (wself.lastBelowMean));
         
       
        if(peak>= thershold){
//        if(peak >wself.lastMean){
            BIT_SET(packet, i);
            [hint setObject:[NSNumber numberWithInt:1] forKey:@"value"];
        }else{
            BIT_CLEAR(packet, i);
            [hint setObject:[NSNumber numberWithInt:0] forKey:@"value"];
        }
      
        
    }
    
    return packet;
   
    
}

-(void)prepareDecoder{
    
    __weak MZCodec * wself = self;
    
    
    
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
     {
         
         Float32 *singleChannel = new Float32[numFrames];
         
         
         for (int i=0; i<numFrames; i++) {
             singleChannel[i] = data[i*2];
         }
         
         
      
         
         //          Remove DC component
         //                  for(UInt32 i = 0; i < numFrames; ++i){
         wself.dcFilter[0].InplaceFilter((Float32*)singleChannel, numFrames);
         //                  }
         
         
         
       
         
         if (wself.fftBufferManager->NeedsNewAudioData()){
             //data is interleaved so only take half the data
             
             
             
             wself.fftBufferManager->GrabAudioDataFloat32(data, numFrames);
             
             
         }
         
         free(singleChannel);
         
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
            
             
             
             [wself preprocessFrequency];
             int packet = [wself processFrequency];
             
             
//             [self //--fooorequencytable];
             
             NSString *bitMessage = [wself stringFromPacket:packet];
//             printf("---------- result= %s\n",[bitMessage UTF8String]);
             wself.decoderlastBitMessage=bitMessage;
             
             char *letter = [wself unpackData:packet];
             [wself testQuality:bitMessage letter:letter];
             
             
             if(wself.decoderLetterCallback){
                 wself.decoderLetterCallback();
             }
         }
         
     }];
    
}

#pragma mark 4bytes
    
-(char*)unpackData:(int)pack{
    
    int index=0;
    int indexInverted=0;
    int onCount=0;
    int status=0;
    
    int bytes =(self.packetDescriptor.partMessageBits/8);
    int messageBitsLenght = bytes+1;
    char* messageBits=new char[bytes+1];
    messageBits[bytes]='\0';
//    messageBits[1]='\0';
    
    int position=0;
    int onRealCount=0;
    
    
    NSMutableString *refMessageBits=[NSMutableString new];
    NSMutableString *refMessageBitsContent=[NSMutableString new];
    
    MZCodecPacketDescriptor *descriptor=self.packetDescriptor;
    
    
    for (int i=0; i<descriptor.partIndexBits; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(index, i);
            [refMessageBits appendString:@"1"];
        }else{
            [refMessageBits appendString:@"0"];
        }
        position++;
    }
    
    for (int i=0; i<descriptor.partMessageBits; i++) {
        
        int byte = i/8;
        char *pointer = messageBits+byte;
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(*pointer, i-(byte*8));
            onRealCount++;
            [refMessageBits appendString:@"1"];
            [refMessageBitsContent appendString:@"1"];
        }else{
            [refMessageBits appendString:@"0"];
            [refMessageBitsContent appendString:@"0"];
            BIT_CLEAR(*pointer, i-(byte*8));
        }
        position++;
    }
    
    for (int i=0; i<descriptor.partChecksumBits; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(onCount, i);
            [refMessageBits appendString:@"1"];
        }else{
            [refMessageBits appendString:@"0"];
        }
        position++;
    }
    
    for (int i=0; i<descriptor.partIndexNegBits; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(indexInverted, i);
            [refMessageBits appendString:@"1"];
        }else{
            [refMessageBits appendString:@"0"];
        }
        position++;
    }
    
    for (int i=0; i<descriptor.partStatusBits; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(status, i);
            //            [refMessageBits appendString:@"1"];
        }else{
            //            [refMessageBits appendString:@"0"];
        }
        position++;
    }   
    
    //---
    
    if(onRealCount==(descriptor.partMessageBits-1)){
        onRealCount=0;
    }else if(onRealCount==0){
        onRealCount=(descriptor.partMessageBits-1);
    }
    
    
  
//    NSString *packet = [self stringFromPacket:pack];
    //--fooo("CHECKING   %s\n",[packet UTF8String]);
    
//    NSData *data = [NSData dataWithBytes:messageBits length:(self.packetDescriptor.partMessageBits/8)+1];
    NSString *letter = [[NSString alloc]initWithUTF8String:messageBits];
    NSData *finalbytes = [NSData dataWithBytes:messageBits length:messageBitsLenght-1];
    
//    NSString *letterByte=[self bitStringContentFromData:finalbytes];
    
    self.decoderLastLetter =[letter copy];
    
    Boolean secondPacketIsOff =false;
    if( onRealCount==0 && onCount==0 && index==1){
        secondPacketIsOff=true;
    }
    
    if( (index==( (descriptor.maxPacketsNumber-1)-indexInverted)
       &&
       onRealCount==onCount
       && onRealCount!=0
         ) || secondPacketIsOff
       //       && status
       ){
 
        
        [self didReceive:finalbytes
                    part:index
              refMessage:refMessageBits
              refContent:refMessageBitsContent
                   valid:YES];
   
        
        //--fooo("VALID   idx %d idxChk %d onBits %d status %d msg %s\n",
//               index,
//               indexInverted,
//               onCount,
//               status,
//               [letter UTF8String]);
        return messageBits;
    }else{
        
        [self didReceive:finalbytes
                    part:index
              refMessage:refMessageBits
              refContent:refMessageBitsContent
                   valid:NO];
        

        
        //--fooo("INVALID idx %d idxChk %d onBits %d status %d msg %s\n",
//               index,
//               indexInverted,
//               
//               onCount,
//               status,
//              [letter UTF8String]);
        return NULL;
    }
    
}

#pragma mark decoding



-(void)didReceive:(NSData*)bytes part:(int)index refMessage:(NSString*)refMessage refContent:(NSString*)refContent valid:(Boolean)valid{
    
    if(bytes==nil){
        return;
    }
    short refNum;
    [bytes getBytes:&refNum length:2];
    
//    NSString *letterByte=[self bitStringContentFromData:bytes];
    
    NSString *refletter = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
    if(refletter==nil){
        
        refletter=[NSString stringWithFormat:@"%d",refNum];
    }
    NSString * key=[NSString stringWithFormat:@">%@-%d-%@<",refletter, index,refMessage];
    
    NSMutableDictionary *contentHint = [self.decodedContents objectForKey:refContent];
    if(contentHint==nil){
        
        //first time
        NSMutableDictionary *hint=[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInt:1],@"count",
                                   refContent,@"refContent",
                                   nil];
        
        [self.decodedContents setObject:hint forKey:refContent];
    }else{
        int count = [[contentHint objectForKey:@"count"]intValue];
        count++;
        NSMutableDictionary *hint=[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInt:count],@"count",
                                   refContent,@"refContent",
                                   nil];
        
        [self.decodedContents setObject:hint forKey:refContent];
        
    }
    
    if (!valid) {
        return;
    }
    
    NSMutableDictionary *part =[self.decoderPackets objectForKey:key];
    if(part==nil){
        //first time
        NSMutableDictionary *part=[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInt:1],@"count",
                                   [NSNumber numberWithInt:index],@"index",
                                   refletter,@"letter",
                                   bytes,@"bytes",
                                   refMessage,@"refMessage",
                                   refContent,@"refContent",
                                   nil];
        
        [self.decoderPackets setObject:part forKey:key];
    }else{
        
//        NSString *oldLetterBytes= [part objectForKey:@"letterByte"];
//        int oldindex = [[part objectForKey:@"index"]intValue];
        int count = [[part objectForKey:@"count"]intValue];
        
        if ([part objectForKey:@"locked"]) {
            //--fooo("---------------> %s LOCKED AT POSITION > %d (ignoring %s-%d)\n",[oldLetterByes UTF8String],oldindex,[letterByte UTF8String],index);
           [self checkPacketStatus];
            return;
        }
        
         ++count;
        
        NSMutableDictionary *partnew=[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:count],@"count",
                                      [NSNumber numberWithInt:index],@"index",
                                      refletter,@"letter",
                                      bytes,@"bytes",
                                      refMessage,@"refMessage",
                                      refContent,@"refContent",
                                      nil];

        
        [self.decoderPackets setObject:partnew forKey:key];
        
    }
    
    [self checkPacketStatus];
}


-(void)checkPacketStatus{
    
    
    
    int totalPackets=self.decoderExpectedPackets;
    int okPerPacket=self.parameters.DECODER_OK_REPEAT_REQUIREMENT;
    int okPerHints=self.parameters.ENCODER_PACKET_REPEAT/4;
    int ok=0;
    
    NSArray *allKeys = [self.decoderPackets allKeys];
    for (int i=0; i<self.decoderPackets.count; i++) {
        NSString *key =[allKeys objectAtIndex:i];
        NSMutableDictionary *part =[self.decoderPackets objectForKey:key];
        int count = [[part objectForKey:@"count"]intValue];
      
        ///// CHECK IF THE PACKET CONTENT HAS CAME BEFORE
        ///// IF THE PACKET HAD CAME BEFORE, ADD THIS CONTRIBUTIONS TO THE FULL PACKET
        int hintCount =0;
        NSString *refcontentkey = [part objectForKey:@"refContent"];
        NSMutableDictionary *contentHint = [self.decodedContents objectForKey:refcontentkey];
        if(contentHint!=nil){
            hintCount = [[contentHint objectForKey:@"count"]intValue];
            
            printf("%s hintcount = %d\n",[refcontentkey UTF8String],hintCount);
        }
        if( hintCount >= okPerHints){
            count+=(okPerPacket/2);
        }
        count=fmin(count, okPerPacket   );
        
        if(count>=okPerPacket ){
            [part setObject:@1 forKey:@"locked"];
            ok++;
        }
        
    }
    
    // sort by index
    
    //         NSMutableDictionary *final=[NSMutableDictionary new];
    NSMutableDictionary *byIndex=[NSMutableDictionary new];
    
    for (int i=0; i<self.decoderPackets.count; i++) {
        NSString *key =[allKeys objectAtIndex:i];
        NSMutableDictionary *part =[self.decoderPackets objectForKey:key];
        int count = [[part objectForKey:@"count"]intValue];
        int index = [[part objectForKey:@"index"]intValue];
        NSString *indexKey = [NSString stringWithFormat:@"%d",index];
        NSDictionary *oldPart =[byIndex objectForKey:indexKey];
        if(oldPart==nil){
            [byIndex setObject:part forKey:indexKey];
        }else{
            int oldcount = [[oldPart objectForKey:@"count"]intValue];
            if(count>oldcount){
                [byIndex setObject:part forKey:indexKey];
            }
        }
        
    }
    
    self.decoderDataByIndex=[NSDictionary dictionaryWithDictionary:byIndex];
    self.decoderDecodingLength = CFAbsoluteTimeGetCurrent()-self.decoderInitTime;
    

    if(ok>=totalPackets){
        [self receivedPacketDone:byIndex];
    }
    
}


-(void)receivedPacketDone:(NSDictionary*)byIndex{
    
    
        NSLog(@"packet received");
        self.decoderDecodingLength = CFAbsoluteTimeGetCurrent()-self.decoderInitTime;
    
      
        NSMutableArray *allObjects = [NSMutableArray arrayWithArray:[byIndex allValues]];

        NSSortDescriptor *aSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
        [allObjects sortUsingDescriptors:[NSArray arrayWithObject:aSortDescriptor]];
        
        NSMutableData *finalBytes = [NSMutableData new];
        
        
        NSMutableArray *letters=[NSMutableArray new];
        for (int i=0; i<allObjects.count; i++) {
            NSMutableDictionary *part =[allObjects objectAtIndex:i];
            NSString *letter=[[part objectForKey:@"letter"]copy];
            NSData *data =[part objectForKey:@"bytes"];
            
            NSString *check =[self bitStringContentFromData:data];
            
            [finalBytes appendData:data];
            if (letter==nil) {
                letter=@"  ";
            }
            
            printf("%d -> %s |%d\n",i,[check UTF8String],finalBytes.length);
            [letters addObject:letter];
        }
        
        
        NSString *content =[letters componentsJoinedByString:@""];
        
        unsigned char buffer[4];
        [finalBytes getBytes:&buffer length:4];
        
        long test = ((unsigned long)buffer[3] << 24) |
        ((unsigned long)buffer[2] << 16) |
        ((unsigned long)buffer[1] << 8) |
        ((unsigned long)buffer[0]);
       
        
        self.decoderReceivedLong = test;
        self.decoderReceivedMessage = content;
        self.decoderReceivedMessageBits = [self stringFromPacket:1];
        self.decoderReceivedBuffer=nil;
        if(self.decoderCallback){
            self.decoderCallback();
        }
        [self stopDecoder];
   
}


#pragma mark helpers


-(void)testQuality:(NSString*)bitMessage letter:(char*)buffer{
    
    
    if (buffer!=NULL) {

        NSString *reference = [self.encoderBitReferenceDictionary objectForKey:bitMessage];
        if(reference!=nil){
            //logic message good data
            ++self.decoderValids;
            
        }else{
            //logic messages corrupted data
            ++self.decoderFalsevalids;
        }
        
    }else{
        //ilogic messages
        ++self.decoderInvalids;
    }
 
    //--fooo("---------- valids\tfalseValid\tratio\n");
    //--fooo("---------- %8d\t %8d\t %f\n",self.decoderValids,self.decoderFalsevalids, ((float)self.decoderFalsevalids)/(float)self.decoderValids );
    
    //--fooo("---------- valids\terrors\tratio\n");
    //--fooo("---------- %8d\t %8d\t %f\n",self.decoderValids,self.decoderInvalids, ((float)self.decoderInvalids/(float)self.decoderValids));
    
    //--fooo("---------- result= %s\n",[bitMessage UTF8String]);
    
   
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


#pragma mark string helpers

-(NSString*)stringFromPacket:(int)packet{
    
    MZCodecPacketDescriptor *descriptor = self.packetDescriptor;
    NSMutableString *result = [NSMutableString new];
    
    for (int i=0; i< (descriptor.completePacketLenghtBytes*8) -descriptor.partStatusBits; i++) {
        int bit;
        bit= 1 & (packet>>i);
        [result appendString:[NSString stringWithFormat:@"%d",bit]];
        
        
        if( i+1==descriptor.partIndexBits ||
           i+1==descriptor.partIndexBits+descriptor.partMessageBits ||
           i+1==descriptor.partIndexBits+descriptor.partMessageBits+descriptor.partChecksumBits ||
           i+1==descriptor.partIndexBits+descriptor.partMessageBits+descriptor.partChecksumBits+descriptor.partIndexNegBits){
            [result appendString:@" "];
        }
    }
    
    return  result;
    
}

//-(NSString*)bitStringFromData:(NSData*)data{
//    
//    MZCodecPacketDescriptor *descriptor = self.packetDescriptor;
//    NSMutableString *result = [NSMutableString new];
//    int packet;
//    [data getBytes:&packet length:sizeof(int)];
//    
//    for (int i=0; i< (descriptor.completePacketLenghtBytes*8) -descriptor.partStatusBits; i++) {
//        int bit;
//        bit= 1 & (packet>>i);
//        [result appendString:[NSString stringWithFormat:@"%d",bit]];
//        
//        
//        if( i+1==descriptor.partIndexBits ||
//           i+1==descriptor.partIndexBits+descriptor.partMessageBits ||
//           i+1==descriptor.partIndexBits+descriptor.partMessageBits+descriptor.partChecksumBits ||
//           i+1==descriptor.partIndexBits+descriptor.partMessageBits+descriptor.partChecksumBits+descriptor.partIndexNegBits){
//            [result appendString:@" "];
//        }
//    }
//    
//    return  result;
//    
//}

-(NSString*)bitStringContentFromData:(NSData*)data{
    
    MZCodecPacketDescriptor *descriptor = self.packetDescriptor;
    NSMutableString *result = [NSMutableString new];
    int packet;
    [data getBytes:&packet length:sizeof(int)];
    
    for (int i=0; i< (descriptor.partMessageBits) ; i++) {
        int bit;
        bit= 1 & (packet>>i);
        [result appendString:[NSString stringWithFormat:@"%d",bit]];

    }
    
    return  result;
    
}

@end
