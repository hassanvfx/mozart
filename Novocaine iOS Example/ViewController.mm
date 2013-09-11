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

#import <MediaPlayer/MediaPlayer.h>
#import "MZCodec.h"
#import "ViewController.h"
#import "FFTBufferManager.h"
#import "aurio_helper.h"
#import "NSMutableArray_Shuffling.h"

#define ECONDER_MESSAGE @"alfaALFAalfaALFAalfaALFAalfaALFAalfaALFAalfaALFAalfaALFAalfaALFAalfa"

#define SAMPLING_FREQUENCY 44100
#define MIN_FREQ 18800
#define MAX_FREQ 19800

#define ENCODER_AMPLITUDE_ON  3.0
#define ENCODER_AMPLITUDE_OFF 0.0
#define ENCODER_BINS_SIZE     4096
#define ENCODER_PACKET_REPEAT 4
#define ENCODER_USE_SILENCE   0
#define ENCODER_SHUFFLED_VERSIONS 16

#define DECODER_SAMPLE_SIZE 4096
#define DECODER_HOP_TOLERANCE_PERCENTAGE 0.75
#define DECODER_OK_REPEAT_REQUIREMENT  2
#define DECODER_USE_MOVING_AVERAGE  0.0

//#define TEST_PATTERN_1111 0
//#define TEST_PATTERN_0101 0
//#define TEST_PATTERN_1010 0
//#define TEST_PATTERN_1001 0
//#define TEST_PATTERN_0110 0


@interface ViewController ()

//@property(nonatomic,assign)	FFTBufferManager*			fftBufferManager;
//@property(nonatomic,assign)	DCRejectionFilter*			dcFilter;
//@property(nonatomic,assign)	Float32*					l_fftData;
//@property(nonatomic,assign)	Float32*						fftData;
//@property(nonatomic,assign)	NSUInteger					fftLength;
//@property(nonatomic,assign)	Boolean                     hasNewFFTData;
@property(nonatomic,assign) int                     freqHop;
@property(nonatomic,strong) NSMutableArray         *frequencyHints;
@property(nonatomic,assign) int                     encoderWaveLength;
@property(nonatomic,assign) float*                     encoderStream;
@property(nonatomic,assign) int                     encoderStreamLength;
@property(nonatomic,assign) int                     lastPacketIndex;
@property(nonatomic,strong) NSMutableDictionary    *referenceParameters;
//@property(nonatomic,assign) int                     decoderValids;
//@property(nonatomic,assign) int                     decoderInvalids;
//@property(nonatomic,assign) int                     decoderFalsevalids;
@property(nonatomic,strong) NSMutableDictionary     *receivedPacket;
//@property(nonatomic,assign) CFAbsoluteTime          decoderInitTime;
//@property(nonatomic,assign) CFAbsoluteTime          decoderEndTime;
@property(nonatomic,strong) NSString                *lastReceivedMessage;
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
    
    ViewController *wself=self;
    
    
    NSString *testString =@"cl1K";
    int decoderHint = 2;
    
    self.codec = [MZCodec new];
    [self.codec switch32bitsMode];
    [self.codec setDecoderExpectedPackets:decoderHint];
    
    [self.codec setEncoderData:testString];
    
//    [self.codec setTestPattern:TEST_PATTERN_1111];
    [self.codec setupEncoder];
    
    [self.codec setupDecoder];
    
    [self.codec setDecoderCallback:^(void) {
        NSLog(@"did receive %@ in %0.1f",
              wself.codec.decoderReceivedMessage,
              wself.codec.decoderDecodingLength
              );
        
        [wself.codec stopCodec];
    }];
    
    [self.codec startCodec];
    
    
#if TARGET_IPHONE_SIMULATOR

#else

#endif

    
}

#pragma  mark  decoder setup

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

@end
