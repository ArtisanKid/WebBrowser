//
//  WBStableWebController.h
//  Pods-WebBrowser_Example
//
//  Created by 李翔宇 on 2017/9/25.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WBStableWebController : UIViewController

@property (class, nonatomic, assign, getter=isDebug) BOOL debug;
@property (nonatomic, assign, getter=isDebug) BOOL debug;

- (instancetype)initWithURL:(NSURL *)url;
@property (nonatomic, strong, readonly) UIWebView *webView;
@property (nonatomic, strong) NSURL *originURL;//原始url

@property(nonatomic, strong) NSString *referer;//用于连接转场跳转的referer，需要添加到HTTP Header

@end

NS_ASSUME_NONNULL_END
