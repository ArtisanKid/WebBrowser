//
//  WBWebController.m
//  Pods-WebBrowser_Example
//
//  Created by 李翔宇 on 2017/9/25.
//

#import "WBWebController.h"
#import "WebBrowserMacros.h"

typedef void (^AKWebControllerAlertCompletion)();

static NSString * const AKWebControllerAlertCancelKey = @"AKWebControllerAlertCancelKey";
static NSString * const AKWebControllerAlertSureKey = @"AKWebControllerAlertSureKey";

static NSString * const AKWebReadCookiesFromDocumentSource = @"function AKWebReadCookiesFromDocument() { return document.cookie; }";
static NSString * const AKWebReadCookiesFromDocumentJS = @"AKWebReadCookiesFromDocument();";

@interface WBWebController () <WKNavigationDelegate, WKUIDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) NSMutableArray<id> *pluginsM;

//辅助参数
//{UIAlertView:{key, block}}
@property(nonatomic, strong) NSMutableDictionary<id, NSDictionary<NSString *, dispatch_block_t> *> *alertsM;

@property(nonatomic, strong) NSURL *currentURL;//当前url

@end

@implementation WBWebController

#pragma mark - Class Method

/**
 *  单例processPool
 *
 *  @return WKProcessPool
 */
+ (WKProcessPool *)globalProcessPool {
    static WKProcessPool *processPool = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        processPool = [[WKProcessPool alloc] init];
    });
    return processPool;
}

//debug开关

static BOOL WBWebControllerDebug = NO;
+ (BOOL)isDebug {
    return WBWebControllerDebug;
}

+ (void)setDebug:(BOOL)debug {
    WBWebControllerDebug = debug;
}

#pragma mark - 生命周期
- (void)dealloc {
    _webView.configuration.processPool = [[WKProcessPool alloc] init];
    _webView.navigationDelegate = nil;
    _webView.UIDelegate = nil;
    [_webView stopLoading];
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [super initWithNibName:nil bundle:nil];
    if(self) {
        _originURL = url;
        _alertsM = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if(!self.configuration) {
        WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
        configuration.processPool = self.class.globalProcessPool;
        self.configuration = configuration;
    }
    
    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    self.configuration.userContentController = userContentController;
    
    //注入cookie，支持Ajax等方式使用
    NSString *source = [self allCookieToSourceAtURL:nil];
    WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                               forMainFrameOnly:NO];
    [userContentController addUserScript:script];
    
    //注入读取cookie的js
    WKUserScript *readCookiesScript = [[WKUserScript alloc] initWithSource:AKWebReadCookiesFromDocumentSource
                                                             injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                          forMainFrameOnly:NO];
    [userContentController addUserScript:readCookiesScript];
    
    //初始化
    _webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:self.configuration];
    _webView.navigationDelegate = self;
    _webView.UIDelegate = self;
    _webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_webView];
    
    //autolayout
    NSDictionary *views = NSDictionaryOfVariableBindings(_webView);
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[_webView]-0-|" options:NSLayoutFormatAlignmentMask metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_webView]-0-|" options:NSLayoutFormatAlignmentMask metrics:nil views:views]];
    
    //加载页面
    [self loadURL:self.originURL];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    //每次页面将要显示，写入一次全部Cookie
    [self setCookieToURL:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    //每次页面将要隐藏，写回一次全部Cookie
    [self storeCookieFromDocument];
}

#pragma mark - Public Method

- (NSArray<id<WebBrowserPluginProtocol>> *)plugins {
    return [self.pluginsM copy];
}

- (void)addPlugin:(id<WebBrowserPluginProtocol>)plugin {
    [self.pluginsM addObject:plugin];
}

- (void)removePlugin:(id<WebBrowserPluginProtocol>)plugin {
    [self.pluginsM removeObject:plugin];
}

/**
 加载数据
 */
- (void)loadURL:(NSURL *)url {
    if(!url) {
        return;
    }
    
    //携带cookie，支持Ajax等方式使用
    NSMutableURLRequest *requestM = [[NSMutableURLRequest alloc] initWithURL:url];
    NSArray *cookies = [NSHTTPCookieStorage.sharedHTTPCookieStorage cookiesForURL:url];
    NSDictionary *headerFields = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
    requestM.allHTTPHeaderFields = headerFields;
    
    //关联referer
    if(self.referer.length) {
        [requestM addValue:self.referer forHTTPHeaderField:@"Referer"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
        self.referer = nil;
#pragma clang diagnostic pop
    }
    
    [self.webView loadRequest:[requestM copy]];
}

#pragma mark - WKNavigationDelegate

/*! @abstract Decides whether to allow or cancel a navigation.
 @param webView The web view invoking the delegate method.
 @param navigationAction Descriptive information about the action
 triggering the navigation request.
 @param decisionHandler The decision handler to call to allow or cancel the
 navigation. The argument is one of the constants of the enumerated type WKNavigationActionPolicy.
 @discussion If you do not implement this method, the web view will load the request or, if appropriate, forward it to another application.
 */
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"%@", navigationAction);
    
    [self storeCookieFromHeaderFields:navigationAction.request.allHTTPHeaderFields];
    
    NSString *urlStr = navigationAction.request.URL.absoluteString;
    
    if ([urlStr hasPrefix:@"tel"]) { //打电话
        decisionHandler(WKNavigationActionPolicyCancel);
        
        NSString *tel = [urlStr componentsSeparatedByString:@":"].lastObject;
        NSURL *telURL = [NSURL URLWithString:[NSString stringWithFormat:@"telprompt://%@", tel]];
        [UIApplication.sharedApplication openURL:telURL];
    } else if ([urlStr hasPrefix:@"itms-apps://"]) { //跳转
        decisionHandler(WKNavigationActionPolicyCancel);
        
        [UIApplication.sharedApplication openURL:navigationAction.request.URL];
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

/*! @abstract Decides whether to allow or cancel a navigation after its
 response is known.
 @param webView The web view invoking the delegate method.
 @param navigationResponse Descriptive information about the navigation
 response.
 @param decisionHandler The decision handler to call to allow or cancel the
 navigation. The argument is one of the constants of the enumerated type WKNavigationResponsePolicy.
 @discussion If you do not implement this method, the web view will allow the response, if the web view can show it.
 */
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"%@", navigationResponse);
    
    if([navigationResponse.response isKindOfClass:[NSHTTPURLResponse class]]) {
        [self storeCookieFromResponse:(NSHTTPURLResponse *)navigationResponse.response];
    }
    
    decisionHandler(WKNavigationResponsePolicyAllow);
}

/*! @abstract Invoked when a main frame navigation starts.
 @param webView The web view invoking the delegate method.
 @param navigation The navigation.
 */
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"");
    
    UIApplication.sharedApplication.networkActivityIndicatorVisible = YES;
}

/*! @abstract Invoked when a server redirect is received for the main
 frame.
 @param webView The web view invoking the delegate method.
 @param navigation The navigation.
 */
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(null_unspecified WKNavigation *)navigation {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"");
}

/*! @abstract Invoked when an error occurs while starting to load data for
 the main frame.
 @param webView The web view invoking the delegate method.
 @param navigation The navigation.
 @param error The error that occurred.
 */
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"%@", error);
    
    UIApplication.sharedApplication.networkActivityIndicatorVisible = NO;
    
    //这些错误的情况下，不显示错误
    
    if ([error.domain isEqualToString:WKErrorDomain]) {
        return;
    }
    
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        if(error.code == NSURLErrorCancelled
           || error.code == NSURLErrorUnsupportedURL) {
            return;
        }
    }
}

/*! @abstract Invoked when content starts arriving for the main frame.
 @param webView The web view invoking the delegate method.
 @param navigation The navigation.
 */
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"");
}

/*! @abstract Invoked when a main frame navigation completes.
 @param webView The web view invoking the delegate method.
 @param navigation The navigation.
 */
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"");
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

/*! @abstract Invoked when an error occurs during a committed main frame
 navigation.
 @param webView The web view invoking the delegate method.
 @param navigation The navigation.
 @param error The error that occurred.
 */
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"%@", error);
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    //这些错误的情况下，不显示错误
    
    if ([error.domain isEqualToString:WKErrorDomain]) {
        return;
    }
    
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        if(error.code == NSURLErrorCancelled
           || error.code == NSURLErrorUnsupportedURL) {
            return;
        }
    }
}

/*! @abstract Invoked when the web view needs to respond to an authentication challenge.
 @param webView The web view that received the authentication challenge.
 @param challenge The authentication challenge.
 @param completionHandler The completion handler you must invoke to respond to the challenge. The
 disposition argument is one of the constants of the enumerated type
 NSURLSessionAuthChallengeDisposition. When disposition is NSURLSessionAuthChallengeUseCredential,
 the credential argument is the credential to use, or nil to indicate continuing without a
 credential.
 @discussion If you do not implement this method, the web view will respond to the authentication challenge with the NSURLSessionAuthChallengeRejectProtectionSpace disposition.
 */
//- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
//
//}

/*! @abstract Invoked when the web view's web content process is terminated.
 @param webView The web view whose underlying web content process was terminated.
 */
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"");
}

#pragma mark - WKUIDelegate

/*! @abstract Creates a new web view.
 @param webView The web view invoking the delegate method.
 @param configuration The configuration to use when creating the new web
 view.
 @param navigationAction The navigation action causing the new web view to
 be created.
 @param windowFeatures Window features requested by the webpage.
 @result A new web view or nil.
 @discussion The web view returned must be created with the specified configuration. WebKit will load the request in the returned web view.
 
 If you do not implement this method, the web view will cancel the navigation.
 */
- (nullable WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"%@\n%@\n%@", configuration, navigationAction, windowFeatures);
    
    if (navigationAction.targetFrame.isMainFrame) {
        WBWebController *controller = [[WBWebController alloc] initWithURL:navigationAction.request.URL];
        controller.configuration = configuration;
        
        if(self.navigationController) {
            [self.navigationController pushViewController:controller animated:YES];
        } else {
            UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
            [self presentViewController:navController animated:YES completion:^{}];
        }
        return nil;
    } else {
        WKWebView *webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
        [webView loadRequest:navigationAction.request];
        return webView;
    }
}

/*! @abstract Notifies your app that the DOM window object's close() method completed successfully.
 @param webView The web view invoking the delegate method.
 @discussion Your app should remove the web view from the view hierarchy and update
 the UI as needed, such as by closing the containing browser tab or window.
 */
- (void)webViewDidClose:(WKWebView *)webView {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"");
}

/*! @abstract Displays a JavaScript alert panel.
 @param webView The web view invoking the delegate method.
 @param message The message to display.
 @param frame Information about the frame whose JavaScript initiated this
 call.
 @param completionHandler The completion handler to call after the alert
 panel has been dismissed.
 @discussion For user security, your app should call attention to the fact
 that a specific website controls the content in this panel. A simple forumla
 for identifying the controlling website is frame.request.URL.host.
 The panel should have a single OK button.
 
 If you do not implement this method, the web view will behave as if the user selected the OK button.
 */
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"%@\n%@", message, frame);
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
    [alertView show];
    
    AKWebControllerAlertCompletion cancleCompletionHandler = ^{
        !completionHandler ? : completionHandler();
    };
    self.alertsM[@(alertView.hash)] = @{AKWebControllerAlertCancelKey : cancleCompletionHandler};
}

/*! @abstract Displays a JavaScript confirm panel.
 @param webView The web view invoking the delegate method.
 @param message The message to display.
 @param frame Information about the frame whose JavaScript initiated this call.
 @param completionHandler The completion handler to call after the confirm
 panel has been dismissed. Pass YES if the user chose OK, NO if the user
 chose Cancel.
 @discussion For user security, your app should call attention to the fact
 that a specific website controls the content in this panel. A simple forumla
 for identifying the controlling website is frame.request.URL.host.
 The panel should have two buttons, such as OK and Cancel.
 
 If you do not implement this method, the web view will behave as if the user selected the Cancel button.
 */
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL result))completionHandler {
    WebBrowserLog(WBWebController.isDebug, self.isDebug, @"%@\n%@", message, frame);
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil message:message delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
    [alertView show];
    
    AKWebControllerAlertCompletion cancleCompletionHandler = ^{
        !completionHandler ? : completionHandler(NO);
    };
    AKWebControllerAlertCompletion sureCompletionHandler = ^{
        !completionHandler ? : completionHandler(YES);
    };
    self.alertsM[@(alertView.hash)] = @{AKWebControllerAlertCancelKey : cancleCompletionHandler,
                                        AKWebControllerAlertSureKey : sureCompletionHandler};
}

/*! @abstract Displays a JavaScript text input panel.
 @param webView The web view invoking the delegate method.
 @param message The message to display.
 @param defaultText The initial text to display in the text entry field.
 @param frame Information about the frame whose JavaScript initiated this call.
 @param completionHandler The completion handler to call after the text
 input panel has been dismissed. Pass the entered text if the user chose
 OK, otherwise nil.
 @discussion For user security, your app should call attention to the fact
 that a specific website controls the content in this panel. A simple forumla
 for identifying the controlling website is frame.request.URL.host.
 The panel should have two buttons, such as OK and Cancel, and a field in
 which to enter text.
 
 If you do not implement this method, the web view will behave as if the user selected the Cancel button.
 */
//- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(nullable NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable result))completionHandler {
//
//}

#pragma mark - UIAlertViewDelegate
// Called when a button is clicked. The view will be automatically dismissed after this call returns
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(buttonIndex == alertView.cancelButtonIndex) {
        AKWebControllerAlertCompletion cancleCompletionHandler = self.alertsM[@(alertView.hash)][AKWebControllerAlertCancelKey];
        !cancleCompletionHandler ? : cancleCompletionHandler();
    } else {
        AKWebControllerAlertCompletion sureCompletionHandler = self.alertsM[@(alertView.hash)][AKWebControllerAlertSureKey];
        !sureCompletionHandler ? : sureCompletionHandler();
    }
    self.alertsM[@(alertView.hash)] = nil;
}

#pragma mark - 私有方法

/**
 将指定URL的Cookie写入浏览器
 如果url为nil时，表示将本地全部写入
 
 @param url 对应的URL
 */
- (void)setCookieToURL:(NSURL *)url {
    NSString *source = [self allCookieToSourceAtURL:url];
    [self.webView evaluateJavaScript:source completionHandler:^(id value, NSError *error) {
        if(error) {
            WebBrowserLog(WBWebController.isDebug, self.isDebug, @"向Document注入全部Cookie的JS调用失败\n%@", error);
        }
    }];
}

/**
 将浏览器的Cookie写回本地
 */
- (void)storeCookieFromDocument {
    [self.webView evaluateJavaScript:AKWebReadCookiesFromDocumentJS completionHandler:^(id _Nullable object, NSError * _Nullable error) {
        
        if(error) {
            WebBrowserLog(WBWebController.isDebug, self.isDebug, @"Document中获取全部Cookie的JS调用失败\n%@", error);
            return;
        }
        
        if(![object isKindOfClass:[NSString class]]) {
            WebBrowserLog(WBWebController.isDebug, self.isDebug, @"Document中获取全部Cookie的类型错误\n%@", error);
            return;
        }
        
        WebBrowserLog(WBWebController.isDebug, self.isDebug, @"Document中获取全部Cookie\n%@", object);
        
        NSString *documentCookie = object;
        documentCookie = [documentCookie stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSArray<NSString *> *cookiePairs = [documentCookie componentsSeparatedByString:@";"];
        
        [cookiePairs enumerateObjectsUsingBlock:^(NSString * _Nonnull cookiePair, NSUInteger idx, BOOL * _Nonnull stop) {
            NSArray<NSString *> *cookieProperties = [cookiePair componentsSeparatedByString:@"="];
            if(!cookieProperties.count) {
                return;
            }
            NSDictionary *propertyDic = @{ NSHTTPCookieDomain : self.webView.URL.host,
                                           NSHTTPCookiePath : @"/",
                                           NSHTTPCookieName : cookieProperties.firstObject,
                                           NSHTTPCookieValue : cookieProperties.lastObject};
            NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:propertyDic];
            if(!cookie) {
                return;
            }
            
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
        }];
    }];
}

- (void)storeCookieFromResponse:(NSHTTPURLResponse *)response {
    //多个stackoverflow的答案提到了这个办法，但是我真的不认为这个是可行的好办法，如果有更好的方式，请修改
    if(![response isKindOfClass:NSHTTPURLResponse.class]) {
        return;
    }
    
    [self storeCookieFromHeaderFields:response.allHeaderFields];
}

- (void)storeCookieFromHeaderFields:(NSDictionary *)allHeaderFields {
    NSArray<NSHTTPCookie *> *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:allHeaderFields forURL:[NSURL URLWithString:@""]];
    if(!cookies.count) {
        return;
    }
    
    [cookies enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull cookie, NSUInteger idx, BOOL * _Nonnull stop) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    }];
}

#pragma mark - 工具方法
/**
 获取URL对应的Cookie拼接成的JS源码
 如果urlStr为nil时，表示将本地全部Cookie拼接成JS源码
 
 @param url 对应的URL
 @return JS源码
 */
- (NSString *)allCookieToSourceAtURL:(NSURL *)url {
    NSArray *cookies = NSHTTPCookieStorage.sharedHTTPCookieStorage.cookies;
    if(url) {
        cookies = [NSHTTPCookieStorage.sharedHTTPCookieStorage cookiesForURL:url];
    }
    
    NSMutableString *sourceM = [NSMutableString string];
    [cookies enumerateObjectsUsingBlock:^(NSHTTPCookie * _Nonnull cookie, NSUInteger idx, BOOL * _Nonnull stop) {
        /*
         尽管document.cookie看上去就像一个属性，可以赋不同的值。但它和一般的属性不一样，改变它的赋值并不意味着丢失原来的值，例如连续执行下面两条语句：
         document.cookie='a=1';
         document.cookie='b=2';
         这时浏览器将维护两个cookie，分别是a和b
         */
        
        NSMutableString *cookieStrM = [@"document.cookie='" mutableCopy];
        [cookie.properties enumerateKeysAndObjectsUsingBlock:^(NSHTTPCookiePropertyKey _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [cookieStrM appendString:[NSString stringWithFormat:@"%@=%@;", key, obj]];
        }];
        [cookieStrM appendString:@"';"];
        [sourceM appendString:[cookieStrM copy]];
    }];
    return [sourceM copy];
}

@end
