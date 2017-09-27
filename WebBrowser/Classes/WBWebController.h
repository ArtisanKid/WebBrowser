//
//  WBWebController.h
//  Pods-WebBrowser_Example
//
//  Created by 李翔宇 on 2017/9/25.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "WebBrowserPluginProtocol.h"

/**
 Can I set the cookies to be used by a WKWebView?
 https://stackoverflow.com/questions/26573137/can-i-set-the-cookies-to-be-used-by-a-wkwebview
 
 Document.cookie:
 https://developer.mozilla.org/en-US/docs/Web/API/document/cookie
 
 How to get cookies from WKWebView
 https://stackoverflow.com/questions/28232963/how-to-get-cookies-from-wkwebview/
 
 Getting all cookies from WKWebView
 https://stackoverflow.com/questions/33156567/getting-all-cookies-from-wkwebview
 
 How to delete WKWebview cookies
 https://codedump.io/share/WK3hb7JwqrE1/1/how-to-delete-wkwebview-cookies
 
 iOS WKWebView Tips
 http://atmarkplant.com/ios-wkwebview-tips/
 
 WKWebView那些坑
 http://mp.weixin.qq.com/s/rhYKLIbXOsUJC_n6dt9UfA
 */

NS_ASSUME_NONNULL_BEGIN

/**
 !!!301和302跳转时的Cookie问题还未解决
 */

@interface WBWebController : UIViewController

@property (class, nonatomic, assign, getter=isDebug) BOOL debug;
@property (class, nonatomic, strong, readonly) WKProcessPool *globalProcessPool;

@property (nonatomic, assign, getter=isDebug) BOOL debug;

- (instancetype)initWithURL:(NSURL *)url;
@property (nonatomic, strong, readonly) WKWebView *webView;
@property (nonatomic, strong) NSURL *originURL;//原始url

@property (nonatomic, strong) WKWebViewConfiguration *configuration;

@property (nonatomic, copy) NSArray<id<WebBrowserPluginProtocol>> *plugins;
- (void)addPlugin:(id<WebBrowserPluginProtocol>)plugin;
- (void)removePlugin:(id<WebBrowserPluginProtocol>)plugin;

@property(nonatomic, strong) NSString *referer;//用于连接转场跳转的referer，需要添加到HTTP Header

@end

NS_ASSUME_NONNULL_END
