#import <substrate.h>
#import "Constants.h"

#pragma mark #region [ NSLog Helper ]
#ifdef DEBUG
	// // #define Log(s, ...) NSLog(@"[OpenNotifier] %s(%d): %@", __FUNCTION__, __LINE__, [NSString stringWithFormat:s, ##__VA_ARGS__])
	// #define Log(fmt, ...) NSLog((@"[OpenNotifier] [Line %d]: "  fmt), __LINE__, ##__VA_ARGS__)
	#define Log(s, ...)
#else
	#define Log(s, ...)
	#define NSLog(s, ...)
#endif
#pragma mark #endregion

#pragma mark #region [ Notifications Helper ]
#define AddObserver(notification, callback) \
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)&callback, notification, NULL, \
		CFNotificationSuspensionBehaviorHold);

#define PostNotification(notification) \
	CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterGetDarwinNotifyCenter(), \
		notification, NULL, NULL, kCFNotificationDeliverImmediately)

#pragma mark #endregion

#pragma mark #region [ Boolean Helper ]
#define NSTrue         			((id) kCFBooleanTrue)
#define NSFalse        			((id) kCFBooleanFalse)
#define NSBool(x)       		((x) ? NSTrue : NSFalse)
#pragma mark #endregion
