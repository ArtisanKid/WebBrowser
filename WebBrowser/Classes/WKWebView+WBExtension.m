//
//  WKWebView+WBExtension.m
//  Pods-WebBrowser_Example
//
//  Created by 李翔宇 on 2017/9/27.
//

#import "WKWebView+WBExtension.h"

@implementation WKWebView (WBExtension)

- (id)wb_evaluateJavaScript:(NSString *)javaScriptString error:(NSError * _Nullable *)error {
    __block id result = nil;
    __block BOOL finish = NO;
    [self evaluateJavaScript:javaScriptString completionHandler:^(NSString *_result, NSError *_error){
        result = _result;
        *error = _error;
        finish = YES;
    }];
    
    while(!finish) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
    }
    
    return result;
}

@end
