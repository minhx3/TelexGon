#import <Foundation/Foundation.h>

@interface TelexAppExclusions : NSObject
+ (instancetype)sharedExclusions;
- (void)startMonitoring;
- (BOOL)containsApplication:(NSString *)identifier;
- (BOOL)hasExcludedApplications;
- (void)showSettings;
@end
