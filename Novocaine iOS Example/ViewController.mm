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

#define SAMPLING_FREQUENCY 44100
#define MIN_FREQ 18006
#define MAX_FREQ 19000

#define ENCODER_AMPLITUDE_ON  1.0
#define ENCODER_AMPLITUDE_OFF 0.0
#define ENCODER_BINS_SIZE     4096
#define ENCODER_PACKET_REPEAT 16

#define DECODER_SAMPLE_SIZE 4096
#define DECODER_HOP_TOLERANCE_PERCENTAGE 1.0


#define TEST_PATTERN_1111 0
#define TEST_PATTERN_0101 0
#define TEST_PATTERN_1010 0
#define TEST_PATTERN_1001 0
#define TEST_PATTERN_0110 0


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
@property(nonatomic,strong) NSMutableDictionary    *referenceParameters;
@property(nonatomic,assign) int                     decoderValids;
@property(nonatomic,assign) int                     decoderInvalids;
@property(nonatomic,assign) int                     decoderFalsevalids;
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
    
    self.referenceParameters =[NSMutableDictionary new];
    self.audioManager = [Novocaine audioManager];
    self.frequencyHints =[NSMutableArray new];
    self.freqHop=1;
    
//    NSMutableArray *packets = [self packData32bitsX16:@"hello world hello world hello world hello world"];
//    [self setupPacketsAsEncoderOutput:packets repeating:8];
    
    
    NSMutableArray *packets = [self packData16bitsX4:@"SEAN"];
    [self setupPacketsAsEncoderOutput:packets repeating:ENCODER_PACKET_REPEAT];
    
#if TARGET_IPHONE_SIMULATOR
    [self encoderSetup];
    
    [self decoderSetup];
#else
    //     [self encoderSetup];
#endif
    
    
    // START IT UP YO
    [self.audioManager play];
    
}

#pragma  mark  decoder setup

-(void)setupPacketsAsEncoderOutput:(NSMutableArray*)packets repeating:(int)count{
    
#if ENCODER_USE_SILENCE
    int totalsamples = count * packets.count *self.encoderWaveLength *2;
    float *result = new float[totalsamples];
    int index =0;
    
    for (int i=0; i<packets.count*2; i++) {
        
        float *waveBytes;
        
        if(i%2==0){
        
            NSDictionary *packet =[packets objectAtIndex:i/2];
            NSData *waveForm = [packet objectForKey:@"waveform"];
            waveBytes = new float[self.encoderWaveLength];
            [waveForm getBytes:waveBytes];
        }else{
            waveBytes= [self encodeDataToWave:0 length:16];
        }
        
        for (int j=0; j<count; j++) {
            memcpy(result+ (index*self.encoderWaveLength ), waveBytes, self.encoderWaveLength*sizeof(float));
            ++index;
        }
    }
#else
    int totalsamples = count * packets.count *self.encoderWaveLength ;
    float *result = new float[totalsamples];
    int index =0;
    
    for (int i=0; i<packets.count; i++) {
        
        float *waveBytes;
        
       
            NSDictionary *packet =[packets objectAtIndex:i];
            NSData *waveForm = [packet objectForKey:@"waveform"];
            waveBytes = new float[self.encoderWaveLength];
            [waveForm getBytes:waveBytes];
       
        
        for (int j=0; j<count; j++) {
            memcpy(result+ (index*self.encoderWaveLength ), waveBytes, self.encoderWaveLength*sizeof(float));
            ++index;
        }
    }
#endif
    
    self.encoderStream = result;
    self.encoderStreamLength =totalsamples;
    
   
    
//    float *encodedWaveForm=[self encodeDataToWave:1 length:16];
//    NSData *waveForm2=[NSData dataWithBytes:encodedWaveForm length:2048*sizeof(float)];
//    float *waveBytes2 = new float[2048];
//    [waveForm2 getBytes:waveBytes2];
//    
//    //self.encoderStream = [self encodeDataToWave32:1];
//    self.encoderStream = encodedWaveForm;
//     self.encoderStreamLength =self.encoderWaveLength;

}

#pragma mark 32bytes

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
     
        float *encodedWaveForm=[self encodeDataToWave:finalPacket length:32];
        
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

#pragma mark 4bytes
-(char* )unpackData1BytesX4:(int)pack{
    
    int index=0;
    int indexInverted=0;
    int onCount=0;
    int status=0;
    
    
    char* messageBits=new char[2];
    messageBits[0]='\0';
    messageBits[1]='\0';
    
    int position=0;
    int onRealCount=0;
    
    for (int i=0; i<2; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(index, i);
        }
        position++;
    }
    
    for (int i=0; i<8; i++) {
        
        
        char *pointer = messageBits+(i/8);
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(*pointer, i);
            onRealCount++;
        }else{
            BIT_CLEAR(*pointer, i);
        }
        position++;
    }
    
    for (int i=0; i<3; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(onCount, i);
        }
        position++;
    }
    
    for (int i=0; i<2; i++) {
        
        if( !BIT_CHECK((int) pack,position) ){
            BIT_SET(indexInverted, i);
        }
        position++;
    }
    
    for (int i=0; i<1; i++) {
        
        if( BIT_CHECK((int) pack,position) ){
            BIT_SET(status, i);
        }
        position++;
    }
    
    //    char message[3];
    //    sprintf(message, "%d", messageBits);
    //    NSString *msg = [NSString stringWithUTF8String:&messageBits];
    
    if(index==(indexInverted) && onRealCount==onCount){
        printf("VALID   idx %d idxChk %d onBits %d status %d msg %c\n",
               index,
               indexInverted,
               onCount,
               status,
               messageBits[0]);
        return messageBits;
    }else{
        printf("INVALID idx %d idxChk %d onBits %d status %d msg %c\n",
               index,
               indexInverted,
               
               onCount,
               status,
               messageBits[0]);
        return NULL;
    }
    
}


-(NSMutableArray*)packData16bitsX4:(NSString*)data{
    
    NSMutableArray *result= [NSMutableArray new];
    
    int completePacketLenghtBytes   = 2;
    int maxPacketsNumber            = 4;
    int messageLengthBytes          = 1;  // 1 message per packet
    int maxCompleteMessageLength    = messageLengthBytes*maxPacketsNumber; //4 bytes maximum in 4 packets
    
    
    NSData *bytes = [data dataUsingEncoding:NSUTF8StringEncoding];
    printf("---------------\n");
    printf("sizeOfData %d\n",bytes.length);
    
    int maxBytes =(int) fmin( bytes.length, maxCompleteMessageLength);
    
    char *output=new char[maxCompleteMessageLength];
    
    for (int i=0; i<maxCompleteMessageLength; i++) {
        output[i]=0;
    }
    
    [bytes getBytes:output length:maxBytes];
    
  
    
    for (int i=0; i<maxCompleteMessageLength; i++) {
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
//    printf("output %s\n",output);
    
    int requiredPackets = (maxBytes)/messageLengthBytes;
    self.lastPacketIndex = fmin(requiredPackets+1,16);
    
    printf("requiredPackets %d\n",requiredPackets);
    
    printf("---------------\n");
    for(int i=0;i<maxPacketsNumber;i++){
        
        char *packetData = new char[1];
 
        int startBytes = i*messageLengthBytes;
        
       
        for (int j=0; j<messageLengthBytes; j++) {
            
            char letter = output[startBytes+j];
            packetData[j]  =letter;
            NSData *data = [NSData dataWithBytes:&letter length:1];
            NSString *reference = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
            [self.referenceParameters setObject:reference forKey:reference];
        }
        
        //        memcpy(packetData, output+(i*messageBytesPerPacket), 2*sizeof(char));
        printf("packet %d content ''%c''\n",i,packetData[0]);
        
        int highbitsCount=0;
        printf("message part > ");
        //check the final output
        for (int i=0; i<messageLengthBytes*8; i++) {
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
        
        short packetIndex = i;
        short packetIndexInverted = (maxPacketsNumber-i)-1;
        
        // FORMAT
        //  ndex    message       Hbits  ndex-1
        //  00      00000000      00     00
        
        printf("packetIndex         %d >",packetIndex);
        for (int i=0; i<4; i++) {
            
            if( BIT_CHECK(packetIndex, i) ) {
                printf("1");
            } else{
                printf("0");
            }
        }
        printf("\n");
        
         printf("packetIndexInverted %d >",packetIndexInverted);
        for (int i=0; i<4; i++) {
            if( BIT_CHECK(packetIndexInverted, i) ) {
                printf("1");
            } else{
                printf("0");
            }
        }
        printf("\n");
        
        
        //////**********************************
        /// CREATE THE FINAL MESSAGE
        
        int finalPacket=0;
        int position=0;
        
        /// APPEND THE PART BYTES
        
        for (int i=0; i<2; i++) {
            
            if( BIT_CHECK(packetIndex,i) ){
                BIT_SET(finalPacket, position);
            }
            position++;
            
        }
        
        /// APPEND THE MESSAGE
        
        for (int i=0; i<messageLengthBytes*8; i++) {
            
            char *pointer = packetData+(i/8);
            if( BIT_CHECK(* pointer,i) ){
                BIT_SET(finalPacket,   position);
            }else{
                BIT_CLEAR(finalPacket,   position);
            }
            position++;
        }
        
        /// APPEND THE ON BITS COUNT (IN MESSAGE)
        
        for (int i=0; i<3; i++) {
            
            if( BIT_CHECK((int) highbitsCount,i) ){
                BIT_SET(finalPacket, position);
            }
            position++;
        }
        
        /// APPEND THE INVERTED PART INDEX
        
        for (int i=0; i<2; i++) {
            
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
        for (int j=0; j<1; j++) {
            
            if(iPacketOn){
                BIT_SET(finalPacket,position);
            }
            ++position;
        }
        
        
        /// PRINT THE FINAL OUTPUT
        
        //        finalPacket =  2 << ((int)&packetData & 6);
        //        finalPacket =  3 << ((int)&packetData & 7);
        
        
      
        printf("final packet >%d >> ",finalPacket);
        //check the final output
        for (int i=0; i<completePacketLenghtBytes*8; i++) {
            int bit;
            bit= 1 & (finalPacket>>i);
           
            
            printf("%d",bit);
            if( i+1==2 ||
               i+1==2+(messageLengthBytes*8) ||
               i+1==2+(messageLengthBytes*8)+3 ||
               i+1==2+(messageLengthBytes*8)+3+2){
                printf(" ");
            }
        }
        
        
        printf("\n");
        printf("---------------\n");
        
        //CREATE THE ENCODED WAVEFROM
        
        float *encodedWaveForm=[self encodeDataToWave:finalPacket length:16];
        
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
#pragma mark wave



-(float *) encodeDataToWave:(int)data length:(int)length{
    
    float fs = SAMPLING_FREQUENCY;           //sample rate
    uint32_t L =ENCODER_BINS_SIZE;
    uint32_t i = 0;
    
    self.encoderWaveLength=L/2;
    
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
    int minFreq = MIN_FREQ;
    int maxFreq = MAX_FREQ;
    self.freqHop = (maxFreq-minFreq)/dataSamples;
    
    
    Boolean appendHints=false;
    
    if ([self.frequencyHints count]<=0) {
        appendHints=true;
    }
    printf("---------------\n");
    printf(" IMPULSES TABLE\n");
    printf("BIN\tFREQ\tMAG\n");
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
            amplitude=ENCODER_AMPLITUDE_ON;
        }
        
        
#if     TEST_PATTERN_1111
        amplitude =ENCODER_AMPLITUDE_ON;
        
#elif   TEST_PATTERN_0000
        amplitude =ENCODER_AMPLITUDE_OFF;
        
#elif   TEST_PATTERN_0101
        amplitude = i%2==0? ENCODER_AMPLITUDE_ON ? ENCODER_AMPLITUDE_OFF;
        
#elif   TEST_PATTERN_1010
        amplitude = i%2!=0? ENCODER_AMPLITUDE_ON ? ENCODER_AMPLITUDE_OFF;
        
#elif   TEST_PATTERN_1001
        amplitude = (i==0)||(i==dataSamples)? ENCODER_AMPLITUDE_ON ? ENCODER_AMPLITUDE_OFF;
        
#elif   TEST_PATTERN_0110
        amplitude = (i=!0)&&(i=!dataSamples)? ENCODER_AMPLITUDE_ON ? ENCODER_AMPLITUDE_OFF;
        
#endif
        
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
        printf("%d\t%d\t%f\n", bin, freq , a);
        
    }
    printf("---------------\n");
    
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



#pragma mark codec


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
    
    UInt32 maxFPS=DECODER_SAMPLE_SIZE; // take this from novocaine
    
    self.fftBufferManager = new FFTBufferManager(maxFPS);
    self.l_fftData = new Float32[maxFPS/2];
    
    self.decoderFalsevalids=0;
    self.decoderValids=0;

    self.decoderInvalids=0;

    
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels, AudioBufferList *ioData)
     {
         
         // Remove DC component
         //         for(UInt32 i = 0; i < ioData->mNumberBuffers; ++i){
         //             wself.dcFilter[i].InplaceFilter((Float32*)(ioData->mBuffers[i].mData), numFrames);
         //         }
         
         
         if (wself.fftBufferManager->NeedsNewAudioData()){
             wself.fftBufferManager->GrabAudioData(ioData);
             
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
             
             
             
             float binWidth = wself.fftLength /((float)SAMPLING_FREQUENCY/(float)2);
             float freqSearchWindow = wself.freqHop*DECODER_HOP_TOLERANCE_PERCENTAGE;
             
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
                 
                 float maxref=1.0;
                 
//                 if(i> [wself.frequencyHints count]-16){
//                     maxref=0.05;
//                 }
//                 
//                 if(i> [wself.frequencyHints count]-8){
//                     maxref=0.01;
//                 }
                 
                 
                 
                 if(max> maxref){
                      BIT_SET(packet, i);
                     
                     [result appendString:@"1"];
                     printf("(%d -%d) (%d -%d) %d peak> %f [1]\n",binStarts,binEnds,freqWindowBeginsAt,freqWindowEndsAt,frequency, max);
                 }else{
                     
                     BIT_CLEAR(packet, i);
                     [result appendString:@"0"];
                     printf("(%d -%d) (%d -%d) %d off > %f [0]\n",binStarts,binEnds,freqWindowBeginsAt,freqWindowEndsAt,frequency,max);
                 }

                 //32 bytes
//                 if( i+1==4 ||
//                    i+1==4+(2*8) ||
//                    i+1==4+(2*8)+4 ||
//                    i+1==4+(2*8)+4 +4){
//                      [result appendString:@" "];
//                 }
                 
                 //4 bytes
                 
                 if( i+1==2 ||
                    i+1==2+(8) ||
                    i+1==2+(8)+3 ||
                    i+1==2+(8)+3 +2){
                     [result appendString:@" "];
                 }

                 
                 
             }
             printf("---------- result= %s\n",[result UTF8String]);

             char* letter= [wself unpackData1BytesX4:packet];
             if(letter!=NULL){
             NSData *data =[NSData dataWithBytes:letter length:1];
             NSString *reference =[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
             
             if([wself.referenceParameters objectForKey:reference]){
                 ++wself.decoderValids;
             }else{
                 ++wself.decoderFalsevalids;
             }
             }else{
                 ++wself.decoderInvalids;
             }
             printf("---------- valids\tfalseValid\tratio\n");
             printf("---------- %8d\t %8d\t %f\n",wself.decoderValids,wself.decoderFalsevalids, ((float)wself.decoderFalsevalids)/(float)wself.decoderValids );
             
             printf("---------- valids\terrors\tratio\n");
             printf("---------- %8d\t %8d\t %f\n",wself.decoderValids,wself.decoderInvalids, ((float)wself.decoderInvalids/(float)wself.decoderValids));
             
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
