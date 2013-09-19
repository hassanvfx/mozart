//
//  MZCodecHelper.h
//  Novocaine
//
//  Created by Hassan Uriostegui on 9/10/13.
//  Copyright (c) 2013.
//

#import <Foundation/Foundation.h>


typedef void (^MZCodecEncoderDidSentPackets)(void);
typedef void (^MZCodecDecoderDidReceiveMessage)(void);
typedef void (^MZCodecDecoderDidReceiveLetter)(void);

#define CODEC_16 16
#define CODEC_32 32

#define AMPLITUDE_ON_4S 6.0
#define AMPLITUDE_ON_5  6.0


#define TEST_PATTERN_OFF    0
#define TEST_PATTERN_1111   1001
#define TEST_PATTERN_0000   1002
#define TEST_PATTERN_0101   1003
#define TEST_PATTERN_1010   1004
#define TEST_PATTERN_1001   1005
#define TEST_PATTERN_0110   1006

#define BIT_SET(a,b) ((a) |= (1<<(b)))
#define BIT_CLEAR(a,b) ((a) &= ~(1<<(b)))
#define BIT_FLIP(a,b) ((a) ^= (1<<(b)))
#define BIT_CHECK(a,b) ((a) & (1<<(b)))

#define CLAMP(min,x,max) (x < min ? min : (x > max ? max : x))

@interface MZCodecPacketDescriptor : NSObject


@property(nonatomic,assign)int partIndexBits;
@property(nonatomic,assign)int partMessageBits;
@property(nonatomic,assign)int partChecksumBits;
@property(nonatomic,assign)int partIndexNegBits;
@property(nonatomic,assign)int partStatusBits;

@property(nonatomic,assign)int completePacketLenghtBytes;
@property(nonatomic,assign)int completePacketLenghtBits;
@property(nonatomic,assign)int maxPacketsNumber ;

@property(nonatomic,assign)int maxMessageBytes ;
@property(nonatomic,assign)int maxMessageBits;
@property(nonatomic,assign)int numberOfSamples;


@end

@interface MZCodecDescriptor : NSObject


@property(nonatomic,assign)int  SAMPLING_FREQUENCY ;
@property(nonatomic,assign)int  MIN_FREQ ;
@property(nonatomic,assign)int  MAX_FREQ ;

@property(nonatomic,assign)float ENCODER_AMPLITUDE_ON  ;
@property(nonatomic,assign)float  ENCODER_AMPLITUDE_OFF ;
@property(nonatomic,assign)int  ENCODER_BINS_SIZE     ;
@property(nonatomic,assign)int  ENCODER_WAVE_LENGHT     ;
@property(nonatomic,assign)int  ENCODER_PACKET_REPEAT ;
@property(nonatomic,assign)int  ENCODER_USE_SILENCE   ;
@property(nonatomic,assign)int  ENCODER_SHUFFLED_VERSIONS ;
@property(nonatomic,assign)int  ENCODER_USE_TEST_PATTERN  ;

@property(nonatomic,assign)int  DECODER_SAMPLE_SIZE ;
@property(nonatomic,assign)float  DECODER_HOP_TOLERANCE_PERCENTAGE ;
@property(nonatomic,assign)int  DECODER_OK_REPEAT_REQUIREMENT  ;
@property(nonatomic,assign)float  DECODER_USE_MOVING_AVERAGE  ;


@end







@interface MZCodec : NSObject

@property(nonatomic,strong)MZCodecEncoderDidSentPackets     encoderCallback;
@property(nonatomic,strong)MZCodecDecoderDidReceiveMessage  decoderCallback;
@property(nonatomic,strong)MZCodecDecoderDidReceiveLetter   decoderLetterCallback;
@property(nonatomic,strong)MZCodecDescriptor  *parameters;
@property(nonatomic,strong)MZCodecPacketDescriptor  *packetDescriptor;
@property(nonatomic,strong)NSString  *decoderReceivedMessage;
@property(nonatomic,assign)long      decoderReceivedLong;
@property(nonatomic,strong)NSString  *decoderReceivedMessageBits;
@property(nonatomic,assign)int       *decoderReceivedBuffer;
@property(nonatomic,assign)CFAbsoluteTime decoderDecodingLength;
@property(nonatomic,assign)int decoderExpectedPackets;
@property(nonatomic,strong)NSDictionary *decoderDataByIndex;

@property(nonatomic,assign) int                     decoderValids;
@property(nonatomic,assign) int                     decoderInvalids;
@property(nonatomic,assign) int                     decoderFalsevalids;
@property(nonatomic,strong) NSString                *decoderLastLetter;

@property(nonatomic,strong) NSString                *decoderlastBitMessage;

-(void)setTestPattern:(int)testPattern;

+(MZCodecPacketDescriptor*)descriptor16bits;
+(MZCodecPacketDescriptor*)descriptor32bits;
-(void)updateFrequenciesTable;
-(void) setEncoderDataString:(NSString*)data;
-(void) setEncoderDataWithLong:(long)data;


-(void)stopEncoder;
-(void)setupEncoder;

-(void)stopDecoder;
-(void)setupDecoder;

-(void)startCodec;
-(void)stopCodec;

-(void)switch32bitsMode;
-(void)switch16bitsMode;

@end
