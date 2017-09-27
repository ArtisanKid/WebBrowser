//
//  WKWebView+WBExtension.h
//  Pods-WebBrowser_Example
//
//  Created by 李翔宇 on 2017/9/27.
//

#import <WebKit/WebKit.h>

@interface WKWebView (WBExtension)

- (id)wb_evaluateJavaScript:(NSString *)javaScriptString error:(NSError * _Nullable *)error;

@end
