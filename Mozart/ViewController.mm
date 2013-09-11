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
    self.textField.delegate=self;
    [self setupCodec];
    
 
}

-(void)setupCodec{
    
    self.codec = [MZCodec new];

    // START THE CODEC
    [self.codec startCodec];
}

-(void)showMessage:(NSString*)messaget{
    
    dispatch_async(dispatch_get_main_queue(), ^{
    
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Hello World!"
                                                      message:messaget
                                                     delegate:nil
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
    [message show];
    });
}


#pragma mark logic

-(void)cleartStats{
    self.statusLetter.text=@"--";
    self.statusAsserts1.text=@"--";
    self.statusAsserts2.text=@"--";
    self.statusRate1.text=@"--";
    self.statusRate2.text=@"--";
    self.statusFalseAsserts.text=@"--";
    self.statusErrors.text=@"--";
}

-(void)updateStats{
    
    int total = self.codec.decoderInvalids+self.codec.decoderValids;
    int total2 = self.codec.decoderFalsevalids+self.codec.decoderValids;
    
    float rate1 = ((float)self.codec.decoderFalsevalids/(float)total2)*100.0;
    float rate2 = ((float)self.codec.decoderInvalids/(float)total)*100.0;
    
    NSString *letter =self.codec.decoderLastLetter;
    NSString *asserts = [NSString stringWithFormat:@"%d",self.codec.decoderValids];
    NSString *falseAsserts = [NSString stringWithFormat:@"%d",self.codec.decoderFalsevalids];
    NSString *errors = [NSString stringWithFormat:@"%d",self.codec.decoderInvalids];
    NSString *rate1s = [NSString stringWithFormat:@"%1.1f%%",rate1];
    NSString *rate2s = [NSString stringWithFormat:@"%1.1f%%",rate2];
    
   self.statusLetter.text=letter;
    self.statusAsserts1.text=asserts;
    self.statusAsserts2.text=asserts;
    self.statusRate1.text=rate1s;
    self.statusRate2.text=rate2s;
    self.statusFalseAsserts.text=falseAsserts;
    self.statusErrors.text=errors;
}

-(IBAction) tabChanged{
    NSLog(@"tabChanged %d",self.tabBarController.selectedIndex);
    
    if(self.tabControl.selectedSegmentIndex==0){
        //iPhone5
        self.codec.parameters.ENCODER_AMPLITUDE_ON=0.45;
    }else{
        //iPhone4s
        self.codec.parameters.ENCODER_AMPLITUDE_ON=4.0;
    }
      [self.textField resignFirstResponder];
    [self stopEncoder];
    
}
-(IBAction) textChanged{
    NSLog(@"textChanged");
    [self stopEncoder];
    
}
-(IBAction) sendChanged{
    NSLog(@"sendChanged");
    if(self.sendSwitch.isOn){
        NSString *textTosend = self.textField.text;
//        NSString * formattedStr = [NSString stringWithFormat:@"%4s", [textTosend UTF8String]];
        
        NSString *formattedStr = ([textTosend length]>4 ? [textTosend substringToIndex:4] : textTosend);
        for (int i=formattedStr.length; i<4; i++) {
            formattedStr=[NSString stringWithFormat:@"%@ ",formattedStr];
        }
        
        self.outMessage=formattedStr;
        self.labelOut.text=self.outMessage;
        [self runEncoder];
    }else{
        self.labelOut.text=@"----";
        [self stopEncoder];
    }
    [self.textField resignFirstResponder];
    
}
-(IBAction) receiveChanged{
    NSLog(@"receiveChanged");
    if(self.receiveSwitch.isOn){
        self.labelResult.text=@"????";
        self.labelResultTime.text=@"~.s";
        [self runDecoder];
    }else{
        self.labelResult.text=@"----";
        self.labelResultTime.text=@"0s";
        [self stopDecoder];
    }
    [self.textField resignFirstResponder];
}

#pragma mark -

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if ([textField.text length] > 4) {
        textField.text = [textField.text substringToIndex:4-1];
        return NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

-(void)runEncoder{
    NSLog(@"runEncoder");
    
    // SET THE DATA TO SEND
    [self.codec setEncoderData:self.outMessage];
    
     
    // IN  CASE OF NEEDED SETUP THE OVERRIDE OF TEST PATTERNS
    // BEFORE THE ENCODER SETUP
    //    [self.codec setTestPattern:TEST_PATTERN_1111];
    
    // SETUP ENCODER IF NEEDED
    [self.codec setupEncoder];
   

}

-(void)stopEncoder{
    NSLog(@"stopEncoder");
    [self.sendSwitch setOn:false];
    [self.codec stopEncoder];
}

-(void)runDecoder{
    
    [self cleartStats];
    
    // INDICATE TO THE DECODER HOW MANY 2 BYTE PACKETS SHOULD EXPECT
    // THIS NEEDS TO MATCH WITH THE NUMBER OF PACKETS SENT!!!
    int hints =floor(self.outMessage.length/2.0);
    [self.codec setDecoderExpectedPackets: hints];
    
 
    __block ViewController *wself=self;
    [self.codec setDecoderLetterCallback:^(void){
        NSDictionary *packets =wself.codec.decoderDataByIndex;
        NSDictionary *packet0 = [packets objectForKey:@"0"];
        NSDictionary *packet1 = [packets objectForKey:@"1"];
        NSString *letter0 =@"??";
        NSString *letter1 =@"??";
        if(packet0){
            letter0=[packet0 objectForKey:@"letterByte"];
        }
        
        if(packet1){
            letter1=[packet1 objectForKey:@"letterByte"];
        }
        NSString *result =[NSString stringWithFormat:@"%@%@",letter0,letter1];
        NSString *time = [NSString stringWithFormat:@"%.1fs",wself.codec.decoderDecodingLength];
        dispatch_async(dispatch_get_main_queue(), ^{
            wself.labelResult.text=result;
            wself.labelResultTime.text=time;
            [wself updateStats];
        });
      
        
    }];
    
    
    [self.codec setDecoderCallback:^(void) {
        NSString *messaget = [NSString stringWithFormat:@"did receive %@ in %0.1f",
                              wself.codec.decoderReceivedMessage,
                              wself.codec.decoderDecodingLength
                              ];
        [wself showMessage:messaget];
        [wself stopDecoder];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [wself.receiveSwitch setOn:false];
        });
    }];
    
    // SETUP DECODER IF NEEDED
    [self.codec setupDecoder];
    
}

-(void)stopDecoder{
    
    [self.codec stopDecoder];
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
