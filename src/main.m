#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <InputMethodKit/InputMethodKit.h>

static TISInputSourceRef copySource(NSString *identifier)
{
    NSDictionary *filter = @{(__bridge NSString *)kTISPropertyInputSourceID: identifier};
    NSArray *sources = CFBridgingRelease(
        TISCreateInputSourceList((__bridge CFDictionaryRef)filter, true));
    TISInputSourceRef source = (__bridge TISInputSourceRef)sources.firstObject;
    if (source) CFRetain(source);
    return source;
}

static bool sourceFlag(TISInputSourceRef source, CFStringRef property)
{
    return TISGetInputSourceProperty(source, property) == kCFBooleanTrue;
}

static int configureInputSource(const char *argument)
{
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *identifier = bundle.bundleIdentifier;
    if (!identifier) return 1;

    if (strcmp(argument, "--stop") == 0) {
        for (NSRunningApplication *app in
             [NSRunningApplication runningApplicationsWithBundleIdentifier:identifier]) {
            if (app.processIdentifier != getpid() &&
                [app.bundleURL.path isEqualToString:bundle.bundlePath]) {
                [app forceTerminate];
            }
        }
        return 0;
    }

    bool registration = strcmp(argument, "--register") == 0;
    bool statusQuery = strcmp(argument, "--status") == 0;
    if (!registration && !statusQuery) return 64;

    if (registration) {
        OSStatus status = TISRegisterInputSource((__bridge CFURLRef)bundle.bundleURL);
        if (status != noErr) {
            fprintf(stderr, "TISRegisterInputSource: %d\n", (int)status);
            return 1;
        }
    }

    TISInputSourceRef parent = copySource(identifier);
    TISInputSourceRef mode = copySource([identifier stringByAppendingString:@".vi"]);
    bool parentEnabled = parent && sourceFlag(parent, kTISPropertyInputSourceIsEnabled);
    bool modeEnabled = mode && sourceFlag(mode, kTISPropertyInputSourceIsEnabled);
    OSStatus status = noErr;
    int result = 0;
    if (statusQuery) {
        bool ready = parentEnabled && modeEnabled;
        puts(ready ? "enabled" : mode ? "registered" : "unavailable");
        result = ready ? 0 : mode ? 2 : 3;
    } else if (parent && mode) {
        if (!parentEnabled) {
            status = TISEnableInputSource(parent);
        }
        if (status == noErr && !modeEnabled) status = TISEnableInputSource(mode);
    } else {
        result = 3;
    }
    if (mode) CFRelease(mode);
    if (parent) CFRelease(parent);
    if (status != noErr) {
        fprintf(stderr, "Text Input Sources: %d\n", (int)status);
        return 1;
    }
    return result;
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc > 1 && strncmp(argv[1], "--", 2) == 0) {
            return configureInputSource(argv[1]);
        }

        NSApplication *application = [NSApplication sharedApplication];
        NSBundle *bundle = NSBundle.mainBundle;
        NSString *connection = [bundle objectForInfoDictionaryKey:@"InputMethodConnectionName"];
        __attribute__((objc_precise_lifetime))
        IMKServer *server = [[IMKServer alloc] initWithName:connection
                                         bundleIdentifier:bundle.bundleIdentifier];
        if (!server) return 1;
        [application run];
        return 0;
    }
}
