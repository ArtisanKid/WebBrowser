//
//  WBStableWebController.m
//  Pods-WebBrowser_Example
//
//  Created by 李翔宇 on 2017/9/25.
//

#import "WBStableWebController.h"
#import "WebBrowserMacros.h"

@interface WBStableWebController ()<UIWebViewDelegate>

@property (nonatomic, strong) UIWebView *webView;

@end

@implementation WBStableWebController

#pragma mark - Class Method

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
    _webView.delegate = nil;
    [_webView stopLoading];
}

- (instancetype)initWithURL:(NSURL *)url {
    self = [super init];
    if(self) {
        _originURL = url;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UIWebView *webView = [[UIWebView alloc] init];
    /**
     UIWebView打开有返回内容的302跳转页面会出现Crash，scalesPageToFit设置为YES的情况下会增加这种Crash的几率
     */
    webView.scalesPageToFit = YES;
    webView.delegate = self;
    [self.view addSubview:webView];
    self.webView = webView;
    
    //autolayout
    NSDictionary *views = NSDictionaryOfVariableBindings(webView);
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[_webView]-0-|" options:NSLayoutFormatAlignmentMask metrics:nil views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[_webView]-0-|" options:NSLayoutFormatAlignmentMask metrics:nil views:views]];
    
    //加载页面
    [self loadURL:self.originURL];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    WebBrowserLog(WBStableWebController.isDebug, self.isDebug, @"%@\n%@", request, @(navigationType));
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    WebBrowserLog(WBStableWebController.isDebug, self.isDebug, @"");
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    WebBrowserLog(WBStableWebController.isDebug, self.isDebug, @"");
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    WebBrowserLog(WBStableWebController.isDebug, self.isDebug, @"%@", error);
}

#pragma mark - Private Method

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

@end
