//
//  WebBrowserMacros.h
//  Pods
//
//  Created by 李翔宇 on 2017/7/5.
//
//

#ifndef WebBrowserMacros_h
#define WebBrowserMacros_h

#if DEBUG
    #define WebBrowserLog(_Class_Debug, _Object_Debug, _Format, ...)\
    do {\
        if(!(_Class_Debug)) { break; }\
        if(!(_Object_Debug)) { break; }\
        printf("\n");\
        NSString *file = [NSString stringWithUTF8String:__FILE__].lastPathComponent;\
        NSLog((@"\n[%@][%d][%s]\n" _Format), file, __LINE__, __PRETTY_FUNCTION__, ## __VA_ARGS__);\
        printf("\n");\
    } while(0)
#else
        #define WebBrowserLog(_Class_Debug, _Object_Debug, _Format, ...)
#endif

#endif /* WebBrowserMacros_h */
