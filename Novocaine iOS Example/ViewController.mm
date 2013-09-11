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

@interface ViewController ()

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
    
    //8 bytes in 40~ seconds
//    NSString *testString =@"cl1KisFun!_1_2_3";
//    int decoderHint = 8;

    //4 bytes in 5~ seconds
    NSString *testString =@"cl1K";
    int decoderHint = 2;

    //2 bytes in 2~ seconds
//    NSString *testString =@"OK";
//    int decoderHint = 1;
    
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
