#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>

static inline TISInputSourceRef TelexCopyInputSource(NSString *identifier)
{
    NSDictionary *filter = @{(__bridge NSString *)kTISPropertyInputSourceID: identifier};
    NSArray *sources = CFBridgingRelease(
        TISCreateInputSourceList((__bridge CFDictionaryRef)filter, true));
    TISInputSourceRef source = (__bridge TISInputSourceRef)sources.firstObject;
    if (source) CFRetain(source);
    return source;
}

static inline bool TelexInputSourceHasFlag(TISInputSourceRef source, CFStringRef property)
{
    return TISGetInputSourceProperty(source, property) == kCFBooleanTrue;
}
