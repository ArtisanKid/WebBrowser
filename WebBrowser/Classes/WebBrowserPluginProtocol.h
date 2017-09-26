//
//  WebBrowserPluginProtocol.h
//  Pods-WebBrowser_Example
//
//  Created by 李翔宇 on 2017/9/25.
//

#import <Foundation/Foundation.h>
#import "WebBrowserViewProtocol.h"

@protocol WebBrowserPluginProtocol <NSObject>

@optional
- (BOOL)webView:(id<WebBrowserViewProtocol>)webView initializeWithURL:(NSURL *)url;

- (BOOL)webView:(id<WebBrowserViewProtocol>)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType;
- (void)webViewDidStartLoad:(id<WebBrowserViewProtocol>)webView;
- (void)webViewDidFinishLoad:(id<WebBrowserViewProtocol>)webView;
- (void)webView:(id<WebBrowserViewProtocol>)webView didFailLoadWithError:(NSError *)error;

@end
