//
//  LBBarCode.m
//  LightBundle
//
//  Created by Hu Dan 胡丹 on 15/11/3.
//  Copyright © 2015年 Ren Wenchao 任文超. All rights reserved.
//

#import "LBBarCode.h"
#import "LBQRCodeReaderViewController.h"

@implementation LBBarCode

/**
 *  扫描条形码
 */
- (void)jsCallFunction
{
    if (self.viewController)
    {
        LBQRCodeReaderViewController *reader = [LBQRCodeReaderViewController readerWithCancelButtonTitle:@"取消"
            bottomTitle:@"请扫描条形码"
            metadataObjectTypes:@[AVMetadataObjectTypeQRCode,
                                  AVMetadataObjectTypeEAN13Code,
                                  AVMetadataObjectTypeEAN8Code,
                                  AVMetadataObjectTypeCode128Code]];
        reader.modalPresentationStyle = UIModalPresentationFormSheet;
        [reader setCompletionWithBlock:^(NSString *resultAsString)
        {
            [self.viewController dismissViewControllerAnimated:YES completion:^{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // 扫码成功
                    if (resultAsString.length)
                    {
                        [self callbackJsSdk:resultAsString errorCode:LBErrorCodeSuccess msg:kLBMsgBarcodeSuccess];
                    }
                    // 扫码失败
                    else {
                        [self callbackJsSdk:@"" errorCode:LBErrorCodeCancel msg:kLBMsgBarcodeCancel];
                    }
                });
            }];
        }];
        
        [self.viewController presentViewController:reader animated:YES completion:nil];
    }
    else
    {
        [self callbackJsSdk:@"" errorCode:LBErrorCodeFail msg:kLBMsgBarcodeFail];
        [self alertNoVc];
    }
}

@end
