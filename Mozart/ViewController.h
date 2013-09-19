// Copyright (c) 2012 Hassan Uriostegui
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


#import <UIKit/UIKit.h>
#import "MZCodec.h"

#define MAX_PACKETS 2 // 1 or 2 for now

@interface ViewController : UIViewController<UITextFieldDelegate>

@property(nonatomic,strong)UILabel IBOutlet *labelResult;
@property(nonatomic,strong)UILabel IBOutlet *labelResultTime;
@property(nonatomic,strong)UILabel IBOutlet *labelOut;
@property(nonatomic,strong)UILabel IBOutlet *labelBits;
@property(nonatomic,strong)UITextField IBOutlet *textField;
@property(nonatomic,strong)UISwitch IBOutlet *sendSwitch;
@property(nonatomic,strong)UISwitch IBOutlet *receiveSwitch;
@property (nonatomic,strong) MZCodec *codec;
@property(nonatomic,strong)NSString *outMessage;


@property(nonatomic,strong)UILabel IBOutlet *statusLetter;
@property(nonatomic,strong)UILabel IBOutlet *statusAsserts1;
@property(nonatomic,strong)UILabel IBOutlet *statusFalseAsserts;
@property(nonatomic,strong)UILabel IBOutlet *statusRate1;
@property(nonatomic,strong)UILabel IBOutlet *statusAsserts2;
@property(nonatomic,strong)UILabel IBOutlet *statusErrors;
@property(nonatomic,strong)UILabel IBOutlet *statusRate2;

-(IBAction) tabChanged;
-(IBAction) textChanged;
-(IBAction) sendChanged;
-(IBAction) receiveChanged;


@end
