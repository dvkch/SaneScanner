#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "NSObject+SY.h"
#import "SaneSwiftC.h"
#import "sane.h"
#import "saneopts.h"

FOUNDATION_EXPORT double SaneSwiftVersionNumber;
FOUNDATION_EXPORT const unsigned char SaneSwiftVersionString[];

