#import "Tweak.h"
#import "Preferences.h"
#import <LibStatusBar/LSStatusBarItem.h>
#import <notify.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBAwayController.h>
#import <SpringBoard7/SBMediaController.h>
#import <SpringBoard7/SBUserAgent.h>
#import <SpringBoard7/SBSoundPreferences.h>
#import <SpringBoard7/SBTelephonyManager.h>
#import <SpringBoard7/BluetoothManager.h>
#import <SpringBoard7/SBStatusBarStateAggregator.h>
#import <SpringBoard7/SBOrientationLockManager.h>
#import <UIKit7/UIStatusBarItem.h>
#import <AVFoundation/AVAudioSession.h>

#undef HBLogInfo
#define HBLogInfo(fmt, ...)

#define UIKitVersionNumber_iOS_7_0 847.200000
#define UIKitVersionNumber_iOS_7_1_1 847.260000
#define UIKitVersionNumber_iOS_7_1_2 847.270000
#define UIKitVersionNumber_iOS_9_1 1241.11

@interface NCNotificationSection : NSObject
@property(nonatomic, retain) NSMutableDictionary *coalescedNotifications;
@property(nonatomic, readonly) NSUInteger notificationsCount;
@end

@interface NCNotificationStore : NSObject
@property(nonatomic, retain) NSMutableDictionary *notificationSections;
@property(nonatomic, readonly) NSUInteger sectionsCount;
@property(nonatomic, readonly) NSUInteger notificationsCount;
@end

@interface NCNotificationDispatcher : NSObject
@property(nonatomic, retain) NCNotificationStore *notificationStore;
@end

@interface NCBulletinNotificationSource : NSObject
@property(nonatomic, retain) NCNotificationDispatcher *dispatcher;
- (NSMutableDictionary *)bulletinFeeds;
@end

@interface NCNotificationRequest : NSObject
@property(nonatomic, copy, readonly) NSString *sectionIdentifier;
@end

@interface NCNotificationChronologicalList : NSObject
- (NSUInteger)sectionCount;
- (NSUInteger)rowCountForSectionIndex:(NSUInteger)arg1;
- (id)allNotificationRequests;
@end

@interface NCNotificationSectionListViewController : UICollectionViewController // NCNotificationListViewController
@property(nonatomic, retain) id sectionList; // NCNotificationChronologicalList
- (BOOL)hasContent;
@end

@interface SBBulletinObserverViewController : UIViewController
- (id)firstSection;
- (unsigned int)_numberOfVisibleSections;
- (unsigned int)_numberOfBulletinsInSection:(id)arg1;
@end

@interface SBNotificationsViewController : SBBulletinObserverViewController
@end

@interface SBNotificationCenterLayoutViewController : UIViewController
-(SBNotificationsViewController *)notificationsViewController;
@end

@interface SBNotificationCenterViewController : UIViewController
- (id)_allModeViewControllerCreateIfNecessary:(BOOL)arg1;
- (BOOL)notificationsPending;
@end

@interface SBNotificationCenterController : NSObject
+ (id)sharedInstanceIfExists;
+ (id)sharedInstance;
@property(readonly, nonatomic) SBNotificationCenterViewController *viewController;
@end

@interface BBSectionInfo
@property(nonatomic, copy) NSString *sectionID;
@property(assign, nonatomic) NSUInteger bulletinCount;
@end

@interface BBBulletin
@property(copy, readonly) NSString *sectionDisplayName;
@property(copy, nonatomic) NSString *bulletinID;
@property(copy, nonatomic) NSString *recordID;
@property(copy, nonatomic) NSString *sectionID;
@property(copy, nonatomic) NSString *section;
@property(copy, nonatomic) NSString *message;
@property(copy, nonatomic) NSString *subtitle;
@property(copy, nonatomic) NSString *title;
@end

@interface BBServer
- (void)publishBulletin:(id)arg1 destinations:(NSUInteger)arg2 alwaysToLockScreen:(_Bool)arg3;
- (id)_allBulletinsForSectionID:(id)arg1;

- (id)allBulletinIDsForSectionID:(id)arg1;
- (id)noticesBulletinIDsForSectionID:(id)arg1;
- (id)bulletinIDsForSectionID:(id)arg1 inFeed:(NSUInteger)arg2;
@end

@interface SBIconModel : NSObject
+ (id)sharedInstance;
- (id)visibleIconIdentifiers;
@end

@interface SBIconModel (iOS8)
- (id)applicationIconForBundleIdentifier:(id)bundleIdentifier;
@end

@interface BCBatteryDevice : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@end

@interface BCBatteryDeviceController : NSObject
+ (id)sharedInstance;
@property(nonatomic, readonly) NSArray *connectedDevices;
@end

@interface TUAudioSystemController : NSObject // TUAudioController
+ (id)sharedAudioSystemController;
- (BOOL)isUplinkMuted;
@end

#pragma mark #region [ Private Variables ]
static ONPreferences* preferences = nil;
static NSMutableDictionary* statusBarItems = nil;
static NSMutableDictionary* currentIconSetList = nil;
static NSMutableDictionary* trackedBadges = nil;
static NSMutableDictionary* trackedBadgeCount = nil;
static NSMutableDictionary* trackedNotifications = nil;
static NSMutableDictionary* trackedNotificationCount = nil;
//static BOOL isAirplane = NO;
static int isAirPlay = 0;
static BOOL isPhoneMicMuted = NO;
static BOOL isSpringBoardLoaded = NO;
static BOOL isAlarm = NO;
static BOOL isBluetooth = NO;
static BOOL isQuiet = NO;
static BOOL isRotation = NO;
static BOOL isVPN = NO;
static BOOL isWiFiCallingActive = NO;
static BOOL changeTether = NO;
static id mailBadge = nil;

static NSDate *lastProcessDateNC = nil;
static NCBulletinNotificationSource *bulletinNotificationSource = nil;
#pragma mark #endregion

#pragma mark #region [ Global Functions ]

static inline NSString *IconNameFromItem(UIStatusBarItem *item)
{
	NSRange range = [[item description] rangeOfString:@"[" options:NSLiteralSearch];
	NSRange iconNameRange;
	iconNameRange.location = range.location + 1;
	iconNameRange.length = ((NSString *)[item description]).length - range.location - 2;
	return [[item description] substringWithRange:iconNameRange];
}

static void SetSystemIcon(NSString *name, bool enable, bool reset = false)
{
	for (int i = 0; i < 36; i++)
	{
		UIStatusBarItem *item = [%c(UIStatusBarItem) itemWithType:i idiom:0];
		if (!item)
		{
			break;
		}

		if ([IconNameFromItem(item) isEqualToString:name])
		{
			if (reset) {
				[[%c(SBStatusBarStateAggregator) sharedInstance] _setItem:i enabled:NO];
				[[%c(SBStatusBarStateAggregator) sharedInstance] updateStatusBarItem:i];
				Log(@"SetSystemIcon reset %@", name);
			} else {
				[[%c(SBStatusBarStateAggregator) sharedInstance] _setItem:i enabled:enable];
				Log(@"SetSystemIcon %@ %@", enable ? @"Yes" : @"No", name);
			}
			break;
	}
		}
}

static LSStatusBarItem* CreateStatusBarItem(NSString* uniqueName, NSString* iconName, bool onLeft)
{
	LSStatusBarItem* item = [[[%c(LSStatusBarItem) alloc]
		initWithIdentifier:[NSString stringWithFormat:@"opennotifier.%@", uniqueName]
		alignment:onLeft ? StatusBarAlignmentLeft : StatusBarAlignmentRight] autorelease];

	item.imageName = [NSString stringWithFormat:@"ON_%@", iconName];
	return item;
}

static void ProcessApplicationIcon(NSString* identifier, int type = 0) //0 = badges, 1 = NC
{
	if (!preferences.enabled) return;

	ONApplication* app;
	if (!(app = [preferences getApplication:identifier])) return;

	////////////////////////////////////////////////////////////////////
	//
	// iOS10_Temp
	if (type == 1) return; // iOS10_Temp

	BOOL shouldShow = YES;
	int count = 0;
	int countBadges = [[trackedBadgeCount objectForKey:identifier] intValue];
	int countNotifications = 0;
	//
	////////////////////////////////////////////////////////////////////

	// ////////////////////////////////////////////////////////////////////
	// // iOS10_Temp Use Notifications and Badges
	// if (type == 0 && !(app.useBadges == 1 || preferences.globalUseBadges || (app.useNotifications != 1 && !preferences.globalUseNotifications))) return;
	// if (type == 1 && app.useNotifications != 1 && !preferences.globalUseNotifications) return;
	//
	// BOOL shouldShow = YES;
	// int count = 0;
	// int countBadges = 0;
	// int countNotifications = 0;
	// if (app.useBadges == 1 || preferences.globalUseBadges || (app.useNotifications != 1 && !preferences.globalUseNotifications)) {
	// 	countBadges = [[trackedBadgeCount objectForKey:identifier] intValue];
	// }
	//
	// if (app.useNotifications == 1 || preferences.globalUseNotifications) {
	// 	countNotifications = [[trackedNotificationCount objectForKey:identifier] intValue];
	// }
	// //
	// ////////////////////////////////////////////////////////////////////

	Log(@"ProcessApplicationIcon (%d) %d, %d -- %@", type, countBadges, countNotifications, identifier);

	BOOL isCountIcon = NO;

	count = countBadges > countNotifications ? countBadges : countNotifications;

	if (count <= 0) {
		count = 0;
		shouldShow = NO;
	}

	for (NSString* name in app.icons.allKeys)
	{
		if (![currentIconSetList.allKeys containsObject:name]) continue; // icon doesn't exist

		ONApplicationIcon* icon = [app.icons objectForKey:name];
		bool onLeft;
		switch (icon.alignment)
		{
			case ONIconAlignmentLeft: onLeft = true; break;
			case ONIconAlignmentRight: onLeft = false; break;
			default: onLeft = preferences.iconsOnLeft; break;
		}

		// avoid colliding with another icon with the same name	and alignment
		NSString* uniqueName = [NSString stringWithFormat:@"%@~%d", name, onLeft];

		if ([name hasPrefix:@"Count_"])
		{
			NSString* tmpName = [NSString stringWithFormat:@"Count%d%@", 1, [name substringFromIndex:5]];
			NSString *path = @"/System/Library/Frameworks/UIKit.framework/libmoorecon";
			if (![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@@2x.png", path, tmpName]]
				&& ![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@_Color@2x.png", path, tmpName]]) {
				path = @"/System/Library/Frameworks/UIKit.framework";
			}

			isCountIcon = true;
			if (count > 99)
			{
				tmpName = [NSString stringWithFormat:@"Count%d%@", 100, [name substringFromIndex:5]];
			}
			else if (count > 0)
			{
				tmpName = [NSString stringWithFormat:@"Count%d%@", count, [name substringFromIndex:5]];
			}
			else
			{
				// Needed for an odd situtation where count is sometimes not > 0
				tmpName = [NSString stringWithFormat:@"Count%d%@", 1, [name substringFromIndex:5]];
			}

			if (![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@@2x.png", path, tmpName]]
				&& ![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@_Color@2x.png", path, tmpName]]) {
				tmpName = [NSString stringWithFormat:@"Count%d%@", 100, [name substringFromIndex:5]];
			}

			if (![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@@2x.png", path, tmpName]]
				&& ![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@_Color@2x.png", path, tmpName]]) {
				name = [NSString stringWithFormat:@"Count%d%@", 10, [name substringFromIndex:5]];
			} else {
				name = tmpName;
			}
		}

		// applications may be sharing name and alignment so lets
		// track it properly before we readd or remove it
		NSMutableDictionary* uniqueIcon = [statusBarItems objectForKey:uniqueName];
		if (!uniqueIcon) uniqueIcon = [NSMutableDictionary dictionary];

		NSMutableArray* apps = [uniqueIcon objectForKey:ONApplicationsKey];
		if (!apps)
		{
			apps = [NSMutableArray array];
		}

		if (!shouldShow && apps.count > 0)
		{
			Log(@"OpenNotifier Remove App A %d - %@ - %@ - %@", apps.count, [trackedNotifications objectForKey:identifier], identifier, [NSDate date]);
			[apps removeObject:identifier];
			if (apps.count == 0) [statusBarItems removeObjectForKey:uniqueName];
		}
		else if (shouldShow)
		{
			Log(@"OpenNotifier Add App A %d - %@ - %@ - %@", apps.count, [trackedNotifications objectForKey:identifier], identifier, [NSDate date]);
			[apps addObject:identifier];
			[uniqueIcon setObject:apps forKey:ONApplicationsKey];

			if (![uniqueIcon.allKeys containsObject:ONIconNameKey] || isCountIcon)
				[uniqueIcon setObject:CreateStatusBarItem(uniqueName, name, onLeft) forKey:ONIconNameKey];

			[statusBarItems setObject:uniqueIcon forKey:uniqueName];
		}
		// else
		// {
		// 	Log(@"OpenNotifier NULL App A %d - %@ - %@ - %@", apps.count, [trackedNotifications objectForKey:identifier], identifier, [NSDate date]);
		// }
	}
}

static void ProcessSystemIcon(NSString* identifier, int shouldShow, NSString* alt)
{
	if (!preferences.enabled) return;

	ONApplication* app;
	if (!(app = [preferences getApplication:identifier])) return;

	BOOL isCountIcon = NO;

	for (NSString* name in app.icons.allKeys)
	{
		NSString *altName = [NSString stringWithFormat:@"%@%@", name, alt];
		if (![currentIconSetList.allKeys containsObject:altName])
		{
			alt = @"";
		}
		if (![currentIconSetList.allKeys containsObject:name]) continue; // icon doesn't exist

		ONApplicationIcon* icon = [app.icons objectForKey:name];
		bool onLeft;
		switch (icon.alignment)
		{
			case ONIconAlignmentLeft: onLeft = true; break;
			case ONIconAlignmentRight: onLeft = false; break;
			default: onLeft = preferences.iconsOnLeft; break;
		}

		// avoid colliding with another icon with the same name	and alignment
		NSString* uniqueName = [NSString stringWithFormat:@"%@~%d", name, onLeft];

		if ([name hasPrefix:@"Count_"])
		{
			NSString* tmpName = [NSString stringWithFormat:@"Count%d%@", 1, [name substringFromIndex:5]];
			NSString *path = @"/System/Library/Frameworks/UIKit.framework/libmoorecon";
			if (![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@@2x.png", path, tmpName]]
				&& ![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@_Color@2x.png", path, tmpName]]) {
				path = @"/System/Library/Frameworks/UIKit.framework";
			}

			isCountIcon = true;
			if (shouldShow > 99)
			{
				tmpName = [NSString stringWithFormat:@"Count%d%@", 100, [name substringFromIndex:5]];
			}
			else if (shouldShow > 0)
			{
				tmpName = [NSString stringWithFormat:@"Count%d%@", shouldShow, [name substringFromIndex:5]];
			}
			else
			{
				// Needed for an odd situtation where count is sometimes not > 0
				tmpName = [NSString stringWithFormat:@"Count%d%@", 1, [name substringFromIndex:5]];
			}

			if (![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@@2x.png", path, tmpName]]
				&& ![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@_Color@2x.png", path, tmpName]]) {
				tmpName = [NSString stringWithFormat:@"Count%d%@", 100, [name substringFromIndex:5]];
			}

			if (![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@@2x.png", path, tmpName]]
				&& ![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"%@/Black_ON_%@_Color@2x.png", path, tmpName]]) {
				name = [NSString stringWithFormat:@"Count%d%@", 10, [name substringFromIndex:5]];
			} else {
				name = tmpName;
			}
		}

		// applications may be sharing name and alignment so lets
		// track it properly before we readd or remove it
		NSMutableDictionary* uniqueIcon = [statusBarItems objectForKey:uniqueName];
		if (!uniqueIcon) uniqueIcon = [NSMutableDictionary dictionary];

		NSMutableArray* apps = [uniqueIcon objectForKey:ONApplicationsKey];
		if (!apps)
		{
			apps = [NSMutableArray array];
		}

		if (!shouldShow && [apps count] > 0)
		{
			[apps removeObject:identifier];
			if (apps.count == 0) [statusBarItems removeObjectForKey:uniqueName];
		}
		else if (shouldShow)
		{
			[apps addObject:identifier];
			[uniqueIcon setObject:apps forKey:ONApplicationsKey];

			if (![uniqueIcon.allKeys containsObject:ONIconNameKey] || isCountIcon)
				[uniqueIcon setObject:CreateStatusBarItem(uniqueName, name, onLeft) forKey:ONIconNameKey];

			((LSStatusBarItem *)[uniqueIcon objectForKey:ONIconNameKey]).imageName = [NSString stringWithFormat:@"ON_%@%@", name, alt];

			[statusBarItems setObject:uniqueIcon forKey:uniqueName];
		}
	}
}

static void ReloadSettings()
{
	if (!preferences) preferences = ONPreferences.sharedInstance;
	else [preferences reload];
}

static bool isSilent()
{
	bool muted = false;
	if (%c(SBMediaController) && [%c(SBMediaController) instancesRespondToSelector:@selector(isRingerMuted)])
	{
		muted = [[%c(SBMediaController) sharedInstance] isRingerMuted];
	}
	else
	{
		// I'm not sure if this is needed or not but leaving it here just in case
		// it needs to be backwards compatible
		uint64_t state;
		int token;
		notify_register_check("com.apple.springboard.ringerstate", &token);
		notify_get_state(token, &state);
		notify_cancel(token);
		muted = (!state);
	}

	return muted;
}

static void UpdateVibrateIcon()
{
	bool vibrate = false;
	if (preferences.vibrateModeEnabled && preferences.enabled)
	{
		CFPreferencesAppSynchronize(CFSTR("com.apple.springboard"));
		NSDictionary *newPrefs = [(id)CFPreferencesCopyMultiple(CFPreferencesCopyKeyList (CFSTR("com.apple.springboard"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost), CFSTR("com.apple.springboard"), kCFPreferencesCurrentUser, kCFPreferencesAnyHost) autorelease];
		NSMutableDictionary *dict = [[NSDictionary alloc] initWithDictionary:newPrefs];

		if (dict)
		{
			vibrate = false;
			if (isSilent()) {
				if ([[dict valueForKey:@"silent-vibrate"] boolValue])
				{
					vibrate = true;
				}
			}
			else if ([[dict valueForKey:@"ring-vibrate"] boolValue])
			{
				vibrate = true;
			}

			[dict release];
		}
	}

	ProcessSystemIcon(@"Vibrate Mode Icon", (vibrate == !preferences.vibrateModeInverted) && preferences.vibrateModeEnabled, @"");
}

static void VibrateModeSettingsChanged()
{
	ReloadSettings();
	UpdateVibrateIcon();
}

static void UpdateSilentIcon()
{
	ProcessSystemIcon(@"Silent Mode Icon", (isSilent() == !preferences.silentModeInverted) && preferences.silentModeEnabled, @"");

	if (preferences.vibrateModeEnabled) UpdateVibrateIcon();
}

static void SilentModeSettingsChanged()
{
	ReloadSettings();
	UpdateSilentIcon();
}

static void UpdateTetherIcon()
{
	BOOL isTethered = NO;

	if (preferences.tetherModeEnabled && preferences.enabled)
	{
		SBTelephonyManager *tm = [%c(SBTelephonyManager) sharedTelephonyManager];
		if (tm)
		{
			int i = tm.numberOfNetworkTetheredDevices;
			isTethered = tm.isNetworkTethering;
			if (isTethered)
			{
				changeTether = true;
				if ([tm respondsToSelector:@selector(_setIsNetworkTethering:withNumberOfDevices:)]) {
					[tm _setIsNetworkTethering:NO withNumberOfDevices:0];
					[tm _setIsNetworkTethering:YES withNumberOfDevices:i];
				}
				changeTether = false;
			}
		}
	}
	else
	{
		SBStatusBarStateAggregator *sbsa = [%c(SBStatusBarStateAggregator) sharedInstance];
		if (sbsa) [sbsa _updateTetheringState];
	}

	ProcessSystemIcon(@"Tether Icon", isTethered && preferences.tetherModeEnabled, @"");
}

static void TetherModeSettingsChanged()
{
	ReloadSettings();
	UpdateTetherIcon();
}

// static void UpdateAirplaneIcon()
// {
// 	if (airplaneIconItem)
// 	{
// 		[airplaneIconItem release];
// 		airplaneIconItem = nil;
// 	}
//
// 	if (preferences.airplaneModeEnabled)
// 	{
// 		SBTelephonyManager *tm = [%c(SBTelephonyManager) sharedTelephonyManager];
// 		if (tm && tm.isInAirplaneMode)
// 		{
// 			airplaneIconItem = [CreateStatusBarItem(ONAirplaneKey, ONAirplaneKey, preferences.airplaneIconOnLeft) retain];
// 		}
// 	}
// }

static void UpdateAirPlayIcon()
{
	NSString *iconName;
	iconName = @"UIStatusBarIndicatorItemView:AirPlay (Right)";

	ProcessSystemIcon(@"AirPlay Icon", preferences.airPlayModeEnabled && isAirPlay == 1, @"");
	if (preferences.airPlayModeEnabled && preferences.enabled && isAirPlay == 1)
	{
		SetSystemIcon(iconName, false);
	}
	else
	{
		SetSystemIcon(iconName, isAirPlay, true); //reset to whatever iOS wants
	}
}

static void UpdateAlarmIcon()
{
	NSString *iconName;
	iconName = @"UIStatusBarIndicatorItemView:Alarm (Right)";

	ProcessSystemIcon(@"Alarm Icon", preferences.alarmModeEnabled && (isAlarm == !preferences.alarmModeInverted), @"");
	if (preferences.alarmModeEnabled && isAlarm && preferences.enabled)
	{
		SetSystemIcon(iconName, false);
	}
	else
	{
		SetSystemIcon(iconName, isAlarm);
	}
}

static void UpdateBluetoothIcon()
{
	NSString *iconName;
	iconName = @"UIStatusBarBluetoothItemView (Right)";

	BluetoothManager *bm = [%c(BluetoothManager) sharedInstance];
	isBluetooth = bm && bm.enabled;
	if (preferences.bluetoothModeEnabled && preferences.enabled)
	{
		SetSystemIcon(iconName, false);
	}
	else
	{
		SetSystemIcon(iconName, isBluetooth);
	}

	ProcessSystemIcon(@"Bluetooth Icon", preferences.bluetoothModeEnabled && isBluetooth && (bm.connected || preferences.bluetoothAlwaysEnabled), bm.connected ? @"_ENBD" : @"");
}

static void UpdateLowPowerIcon()
{
	ProcessSystemIcon(@"Low Power Icon", preferences.lowPowerModeEnabled && [[%c(SpringBoard) sharedApplication] isBatterySaverModeActive], @"");
}

static void UpdatePhoneMicMutedIcon()
{
	ProcessSystemIcon(@"Phone Mic Muted Icon", preferences.phoneMicMutedModeEnabled && isPhoneMicMuted, @"");
}

static void UpdateQuietIcon()
{
	NSString *iconName;
	iconName = @"UIStatusBarQuietModeItemView:QuietMode (Right)";

	ProcessSystemIcon(@"Do Not Disturb Icon", preferences.quietModeEnabled && (isQuiet == !preferences.quietModeInverted), @"");
	if (preferences.quietModeEnabled && isQuiet && preferences.enabled)
	{
		SetSystemIcon(iconName, false);
	}
	else
	{
		SetSystemIcon(iconName, isQuiet);
	}
}

static void UpdateRotationLockIcon()
{
	NSString *iconName;
	iconName = @"UIStatusBarIndicatorItemView:RotationLock (Right)";

	SBOrientationLockManager *bm = [%c(SBOrientationLockManager) sharedInstance];
	if ([bm respondsToSelector:@selector(isUserLocked)])
	{
		isRotation = bm && bm.isUserLocked;
	} else {
		isRotation = bm && bm.isLocked;
	}

	ProcessSystemIcon(@"Rotation Lock Icon", (isRotation == !preferences.rotationLockModeInverted) && preferences.rotationLockModeEnabled, @"");
	if (preferences.rotationLockModeEnabled && preferences.enabled)
	{
		SetSystemIcon(iconName, false);
	}
	else
	{
		SetSystemIcon(iconName, isRotation);
	}
}

static void UpdateVPNIcon()
{
	NSString *iconName;
	iconName = @"UIStatusBarIndicatorItemView:VPN (Left)";

	SBTelephonyManager *tm = [%c(SBTelephonyManager) sharedTelephonyManager];
	isVPN = tm && tm.isUsingVPNConnection;
	ProcessSystemIcon(@"VPN Icon", isVPN && preferences.vPNModeEnabled, @"");
	if (preferences.vPNModeEnabled && preferences.enabled)
	{
		SetSystemIcon(iconName, false);
	}
	else
	{
		SetSystemIcon(iconName, isVPN);
	}
}

static void UpdateWatchIcon()
{
	BOOL isConnected = NO;

	BCBatteryDeviceController *deviceController = [%c(BCBatteryDeviceController) sharedInstance];
	if (deviceController) {
		for (BCBatteryDevice *device in [deviceController connectedDevices]) {
			if ([[device name] isEqualToString:@"Watch"]) {
				isConnected = YES;
				break;
			}
		}
	}

	ProcessSystemIcon(@"Watch Icon", preferences.watchModeEnabled && isConnected, @"");
}

static void UpdateWiFiCallingIcon()
{
	ProcessSystemIcon(@"WiFi Calling Icon", preferences.wiFiCallingModeEnabled && isWiFiCallingActive, @"");
}

static void UpdateNotificationCenterIcon()
{
	NSString *sectionID = @"Notification Center Icon";
	int showBadge = [trackedNotificationCount objectForKey:sectionID] ? [[trackedNotificationCount objectForKey:sectionID] intValue] : 0;
	showBadge = preferences.enabled && preferences.notificationCenterModeEnabled && showBadge > 0 ? showBadge : 0;
	ProcessSystemIcon(sectionID, showBadge, @"");
}

static int isAirPlayActive()
{
	if (!preferences || !preferences.enabled || !preferences.airPlayModeEnabled)
	{
		return 2;
	}

	if ([[%c(SBMediaController) sharedInstance] isScreenSharing])
		return 1;
	if (!preferences.airPlayAlwaysEnabled)
		return 0;

	if (![%c(AVAudioSession) respondsToSelector:@selector(sharedInstance)]) return NO;
	if ([%c(AVAudioSession) sharedInstance])
	{
		if (![[%c(AVAudioSession) sharedInstance] respondsToSelector:@selector(currentRoute)]) return NO;
		AVAudioSessionRouteDescription *route = [[%c(AVAudioSession) sharedInstance] currentRoute];
		if (route == nil) {
			return 0;
		}

		if (![route respondsToSelector:@selector(outputs)]) return NO;
		for (AVAudioSessionPortDescription *desc in [route outputs])
		{
			if ([desc respondsToSelector:@selector(portType)])
			{
				if ([[desc portType] isEqualToString:@"AirPlay"]) //AVAudioSessionPortAirPlay
				{
					return 1;
				}
			}
		}
	}

	return 0;
}

static void AirPlayModeSettingsChanged()
{
	ReloadSettings();
	isAirPlay = isAirPlayActive();
	UpdateAirPlayIcon();
}

static void AlarmModeSettingsChanged()
{
	ReloadSettings();
	UpdateAlarmIcon();
}

static void BluetoothModeSettingsChanged()
{
	ReloadSettings();
	UpdateBluetoothIcon();
}

static void LowPowerModeSettingsChanged()
{
	ReloadSettings();
	UpdateLowPowerIcon();
}

static void PhoneMicMutedModeSettingsChanged()
{
	ReloadSettings();
	UpdatePhoneMicMutedIcon();
}

static void QuietModeSettingsChanged()
{
	ReloadSettings();
	UpdateQuietIcon();
}

static void RotationLockModeSettingsChanged()
{
	ReloadSettings();
	UpdateRotationLockIcon();
}

static void VPNModeSettingsChanged()
{
	ReloadSettings();
	UpdateVPNIcon();
}

static void WatchModeSettingsChanged()
{
	ReloadSettings();
	UpdateWatchIcon();
}

static void WiFiCallingModeSettingsChanged()
{
	ReloadSettings();
	UpdateWiFiCallingIcon();
}

static void NotificationCenterModeSettingsChanged()
{
	ReloadSettings();
	UpdateNotificationCenterIcon();
}

static void HideMailSettingsChanged()
{
	ReloadSettings();

	SBApplicationController* sbac = %c(SBApplicationController);
	if (sbac != NULL)
	{
		SBApplication *mailApp;
		mailApp = [[sbac sharedInstance] applicationWithBundleIdentifier:@"com.apple.mobilemail"];
		if (mailApp != NULL)
		{
			SBApplicationIcon *mailAppIcon = [[%c(SBApplicationIcon) alloc] initWithApplication:mailApp];
			if (mailAppIcon != NULL)
			{
				[mailAppIcon setBadge:mailBadge];
			}
		}
	}
}

static void IconSettingsChanged()
{
	ReloadSettings();

	[statusBarItems removeAllObjects];

	isAirPlay = isAirPlayActive();

	if (!preferences.enabled)
	{
		// isAirPlay = isAirPlayActive();
		SetSystemIcon(@"UIStatusBarBluetoothItemView (Right)", isBluetooth);
		SetSystemIcon(@"UIStatusBarIndicatorItemView:Alarm (Right)", isAlarm);
		SetSystemIcon(@"UIStatusBarIndicatorItemView:AirPlay (Right)", isAirPlay, true); //reset
		SetSystemIcon(@"UIStatusBarQuietModeItemView:QuietMode (Right)", isQuiet);
		SetSystemIcon(@"UIStatusBarIndicatorItemView:RotationLock (Right)", isRotation);
		SetSystemIcon(@"UIStatusBarIndicatorItemView:VPN (Left)", isVPN);
		return;
	}

	UpdateSilentIcon();
	UpdateVibrateIcon();
	UpdateTetherIcon();
	UpdateAirPlayIcon();
//	UpdateAirplaneIcon();
	UpdateAlarmIcon();
	UpdateBluetoothIcon();
	UpdateLowPowerIcon();
	UpdatePhoneMicMutedIcon();
	UpdateQuietIcon();
	UpdateRotationLockIcon();
	UpdateVPNIcon();
	UpdateWatchIcon();
	UpdateWiFiCallingIcon();

	[trackedBadges.allKeys enumerateObjectsUsingBlock: ^(id key, NSUInteger index, BOOL* stop){
		ProcessApplicationIcon(key);
	}];

	[trackedNotifications.allKeys enumerateObjectsUsingBlock: ^(id key, NSUInteger index, BOOL* stop){
		if ([key isEqualToString:@"Notification Center Icon"]) {
			UpdateNotificationCenterIcon();
		} else {
			ProcessApplicationIcon(key, 1);
		}
	}];

	for (BluetoothDevice* device in [[%c(BluetoothManager) sharedInstance] connectedDevices]) {
		NSString *identifier = [NSString stringWithFormat:@"ONBluetooth-%@", device.name];
		ProcessSystemIcon(identifier, YES, @"");
	}
}

static void InitBadges()
{
	if ([%c(SBIconViewMap) respondsToSelector:@selector(homescreenMap)]) {
		for (NSString *identifier in [[[%c(SBIconViewMap) homescreenMap] iconModel] visibleIconIdentifiers]) {
			SBIcon *icon;
			icon = (SBIcon *)[[[%c(SBIconViewMap) homescreenMap] iconModel] applicationIconForBundleIdentifier:identifier];
			if (icon && [icon badgeNumberOrString] && ([[icon badgeNumberOrString] intValue] > 0)) {
				[trackedBadges setObject:NSBool(YES) forKey:identifier];
				[trackedBadgeCount setObject:[icon badgeNumberOrString] forKey:identifier];
				ProcessApplicationIcon(identifier);
			}
		}
	} else if (%c(SBIconController)) {
		SBIconController *iconCtrl = [%c(SBIconController) sharedInstance];
		if ([iconCtrl respondsToSelector:@selector(homescreenIconViewMap)]) {
			SBIconModel *iconModel = (SBIconModel *)[[iconCtrl homescreenIconViewMap] iconModel];
			for (NSString *identifier in [iconModel visibleIconIdentifiers]) {
				SBIcon *icon = (SBIcon *)[iconModel applicationIconForBundleIdentifier:identifier];
				if (icon && [icon badgeNumberOrString] && ([[icon badgeNumberOrString] intValue] > 0)) {
					[trackedBadges setObject:NSBool(YES) forKey:identifier];
					[trackedBadgeCount setObject:[icon badgeNumberOrString] forKey:identifier];
					ProcessApplicationIcon(identifier);
				}
			}
		}
	}

	if (bulletinNotificationSource) {
		NCNotificationDispatcher *notificationDispatcher = bulletinNotificationSource.dispatcher;
		NCNotificationStore *notificationStore = notificationDispatcher.notificationStore;

		for (NSString *sectionID in notificationStore.notificationSections.allKeys) {
			NCNotificationSection *notificationSection = [notificationStore.notificationSections objectForKey:sectionID];
			if (!notificationSection) continue;
			long count = (long)notificationSection.notificationsCount;
			bool showBadge = count > 0;
			[trackedNotifications setObject:[NSNumber numberWithBool:showBadge] sectionID:sectionID];
			[trackedNotificationCount setObject:[NSNumber numberWithInteger:count] forKey:sectionID];
			ProcessApplicationIcon(sectionID, 1);
		}
	}

	// iOS10_Temp
	// else {
	// 	SBNotificationCenterController *nc = (SBNotificationCenterController *)[%c(SBNotificationCenterController) sharedInstance];
	// 	if (nc)	{
	// 		SBBulletinObserverViewController *observer = nil;
	// 		SBNotificationCenterLayoutViewController *layoutViewController(MSHookIvar<SBNotificationCenterLayoutViewController *>(nc.viewController, "_layoutViewController"));
	// 		if (layoutViewController) {
	// 			observer = (SBBulletinObserverViewController *)layoutViewController.notificationsViewController;
	// 		}
	// 		id section;
	// 		if ((section = [observer firstSection]) != nil) {
	// 			id section = [observer firstSection];
	// 			while (section) {
	// 				bool showBadge = [observer _numberOfBulletinsInSection:section] > 0;
	// 				[trackedNotifications setObject:[NSNumber numberWithBool:showBadge] forKey:section];
	// 				[trackedNotificationCount setObject:[NSNumber numberWithInteger:[observer _numberOfBulletinsInSection:section]] forKey:section];
	// 				ProcessApplicationIcon(section, 1);
	// 				section = [observer sectionAfterSection:section];
	// 			}
	// 		}
	// 	}
	// }
}
#pragma mark #endregion

%group All
%hook BluetoothManager
- (void)_connectedStatusChanged
{
	%orig;

	if (preferences && preferences.enabled) {
		for (BluetoothDevice* device in [[%c(BluetoothManager) sharedInstance] pairedDevices]) {
			NSString *identifier = [NSString stringWithFormat:@"ONBluetooth-%@", device.name];
			ProcessSystemIcon(identifier, device.connected, @"");
		}
	}
}
%end

#pragma mark #region [ SpringBoard ]
%hook SpringBoard

%new - (void)AVAudioRouteChanged:(NSNotification *)notification
{
	static int lastState = -1;
	if (!preferences || !preferences.airPlayModeEnabled || !preferences.enabled)
		return;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		isAirPlay = isAirPlayActive();
		if (lastState != isAirPlay) {
			lastState = isAirPlay;
			UpdateAirPlayIcon();
		}
	});
}

%new - (void)ONBatteryDeviceControllerConnectedDevicesDidChange
{
	if (!preferences || !preferences.watchModeEnabled || !preferences.enabled)
		return;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		UpdateWatchIcon();
	});
}

-(id)init
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	// ReloadSettings();
	NSMutableArray* imageNames = [NSMutableArray arrayWithArray:[[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:@"/System/Library/Frameworks/UIKit.framework/libmoorecon" error:nil]
	];
	[imageNames addObjectsFromArray:[NSMutableArray arrayWithArray:[[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:@"/System/Library/Frameworks/UIKit.framework/" error:nil]
	]];

	NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:IconRegexPattern
		options:NSRegularExpressionCaseInsensitive error:nil];

	for (NSString* name in imageNames)
	{
		NSTextCheckingResult* match = [regex firstMatchInString:name options:0 range:NSMakeRange(0, name.length)];
		if (!match) continue;
		name = [name substringWithRange:[match rangeAtIndex:1]];
		[currentIconSetList setObject:[NSMutableSet setWithCapacity:1] forKey:name];
	}

	[pool drain];
	return %orig;
}

-(void)applicationDidFinishLaunching:(id)application
{
	%orig;
	lastProcessDateNC = [[NSDate date] retain];
	UpdateSilentIcon();
	UpdateVibrateIcon();
	UpdateTetherIcon();
//	UpdateAirplaneIcon();
	UpdateBluetoothIcon();
	UpdateLowPowerIcon();
	UpdatePhoneMicMutedIcon();
	UpdateWatchIcon();
	UpdateWiFiCallingIcon();

	isAirPlay = isAirPlayActive();
	if (isAirPlay == 1 && preferences.enabled)
	{
		UpdateAirPlayIcon();
	}

	AddObserver((CFStringRef)IconSettingsChangedNotification, IconSettingsChanged);
	AddObserver((CFStringRef)SilentModeChangedNotification, SilentModeSettingsChanged);
	AddObserver((CFStringRef)VibrateModeChangedNotification, VibrateModeSettingsChanged);
	AddObserver((CFStringRef)TetherModeChangedNotification, TetherModeSettingsChanged);

//	AddObserver((CFStringRef)AirplaneModeChangedNotification, AirplaneModeSettingsChanged);
	AddObserver((CFStringRef)AirPlayModeChangedNotification, AirPlayModeSettingsChanged);
	AddObserver((CFStringRef)AlarmModeChangedNotification, AlarmModeSettingsChanged);
	AddObserver((CFStringRef)BluetoothModeChangedNotification, BluetoothModeSettingsChanged);
	AddObserver((CFStringRef)LowPowerModeChangedNotification, LowPowerModeSettingsChanged);
	AddObserver((CFStringRef)PhoneMicMutedModeChangedNotification, PhoneMicMutedModeSettingsChanged);
	AddObserver((CFStringRef)QuietModeChangedNotification, QuietModeSettingsChanged);
	AddObserver((CFStringRef)RotationLockModeChangedNotification, RotationLockModeSettingsChanged);
	AddObserver((CFStringRef)VPNModeChangedNotification, VPNModeSettingsChanged);
	AddObserver((CFStringRef)WatchModeChangedNotification, WatchModeSettingsChanged);
	AddObserver((CFStringRef)WiFiCallingModeChangedNotification, WiFiCallingModeSettingsChanged);
	AddObserver((CFStringRef)NotificationCenterModeChangedNotification, NotificationCenterModeSettingsChanged);

	AddObserver((CFStringRef)HideMailChangedNotification, HideMailSettingsChanged);

	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(center, NULL, (CFNotificationCallback)&UpdateVibrateIcon, CFSTR("com.apple.springboard.ring-vibrate.changed"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	CFNotificationCenterAddObserver(center, NULL, (CFNotificationCallback)&UpdateVibrateIcon, CFSTR("com.apple.springboard.silent-vibrate.changed"), NULL, CFNotificationSuspensionBehaviorCoalesce);

	[%c(AVAudioSession) sharedInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AVAudioRouteChanged:) name:@"AVAudioSessionRouteChangeNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ONBatteryDeviceControllerConnectedDevicesDidChange) name:@"BCBatteryDeviceControllerConnectedDevicesDidChange" object:nil];

	// #ifdef DEBUGPREFS
	// dispatch_queue_t queue = dispatch_get_main_queue();
	// dispatch_async(queue,
	// ^{
	// 	SBAwayController* c = [%c(SBAwayController) sharedAwayController];
	// 	[c attemptUnlock];
	// 	[c unlockWithSound:false];
	// 	[[%c(SBUserAgent) sharedUserAgent] openURL:[NSURL URLWithString:@"prefs:root=OpenNotifier"] allowUnlock:true animated:true];
	// 	dispatch_release(queue);
	// });
	// #endif

	InitBadges();

	isSpringBoardLoaded = YES;
}

-(void)setBatterySaverModeActive:(BOOL)arg1
{
	%orig;
	UpdateLowPowerIcon();
}
%end
#pragma mark #endregion

#pragma mark #region [ SBMediaController ]
%hook SBMediaController
-(void)setRingerMuted:(bool)change
{
	%orig;
	UpdateSilentIcon();
}
%end
#pragma mark #endregion

#pragma mark #region [ SBTelephonyManager ]
%hook SBTelephonyManager
-(void)setIsInAirplaneMode:(BOOL)isInAirplaneMode
{
	// isAirplane = arg1;
	%orig;
	// UpdateAirplaneIcon();

	if (preferences && preferences.enabled && isInAirplaneMode) {
		NSArray *bluetoothDevices = [preferences getBluetoothIdentifers];
		for (NSString *identifier in bluetoothDevices) {
			ProcessSystemIcon(identifier, NO, @"");
		}
	}
}
%end
#pragma mark #endregion

#pragma mark #region [ SBStatusBarStateAggregator ]
%hook SBStatusBarStateAggregator
-(void)_updateTetheringState
{
	if (preferences.tetherModeEnabled && preferences.enabled)
	{
		SBTelephonyManager *tm = [%c(SBTelephonyManager) sharedTelephonyManager];
		if (tm && tm.isNetworkTethering)
		{
			return;
		}
	}
	%orig;
}

// -(void)_updateAirplaneMode
// {
// 	if (preferences.airplaneModeEnabled)
// 	{
// 		UpdateAirplaneIcon();
// 		return;
// 	}
// 	%orig;
// }

-(void)_updateAirplayItem
{
	if (preferences.airPlayModeEnabled && preferences.enabled)
	{
		return;
	}

	%orig;
}

-(void)setAlarmEnabled:(BOOL)arg1
{
	isAlarm = arg1;
	%orig;
}

-(void)_updateAlarmItem
{
	if (preferences.alarmModeEnabled && preferences.enabled)
	{
		UpdateAlarmIcon();
		return;
	}
	%orig;
}

-(void)_updateBluetoothItem
{
	if (preferences.bluetoothModeEnabled && preferences.enabled)
	{
		UpdateBluetoothIcon();
		return;
	}
	%orig;
}

-(void)_updateQuietModeItem
{
	if (preferences.quietModeEnabled && preferences.enabled)
	{
		return;
	}
	%orig;
}

-(void)_updateRotationLockItem
{
	if (preferences.rotationLockModeEnabled && preferences.enabled)
	{
		UpdateRotationLockIcon();
		return;
	}
	%orig;
}

-(void)_updateVPNItem
{
	if (preferences.vPNModeEnabled && preferences.enabled)
	{
		UpdateVPNIcon();
		return;
	}
	%orig;
}
%end
#pragma mark #endregion

#pragma mark #region [ SBApplication ]
%hook SBApplication
-(void)setBadge:(id)badge
{
	id badgeCopy = badge;
	bool showBadge = !(badge == NULL || badge == nil || [badge isEqual:@""] || [badge isEqual:@"0"] || [badge isEqual:[NSNumber numberWithInt:0]] || ([badge intValue] <= 0));
	if ([self.bundleIdentifier isEqualToString:@"com.apple.mobilemail"]) {
		mailBadge = badge;
		if (preferences.enabled && preferences.hideMail)
		{
			badge = nil;
		}
	}
	%orig(badge);

	Log(@"SBApplication setBadge - identifier = %@ - %d, badge = %@", self.bundleIdentifier, [badge intValue], badge);

	[trackedBadges setObject:NSBool(showBadge) forKey:self.bundleIdentifier];
	[trackedBadgeCount setObject:showBadge ? badgeCopy : @"0" forKey:self.bundleIdentifier];
	if (preferences.enabled)
	{
		ProcessApplicationIcon(self.bundleIdentifier);
	}
}
%end
#pragma mark #endregion

#pragma mark #region [ BBServer ]
%hook BBServer
- (void)publishBulletin:(BBBulletin*)bulletin destinations:(NSUInteger)arg2 alwaysToLockScreen:(BOOL)arg3
{
	%orig;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		if (![bulletin isKindOfClass:%c(BBBulletin)]) {
			return;
		}

		NSString *section = bulletin.sectionID;
		NSArray *bulletins = [self allBulletinIDsForSectionID:section];
		bool showBadge = bulletins.count > 0;
		[trackedNotifications setObject:[NSNumber numberWithBool:showBadge] forKey:section];
		[trackedNotificationCount setObject:[NSNumber numberWithInteger:bulletins.count] forKey:section];
		// if (preferences.enabled) ProcessApplicationIcon(section, 1); iOS10_Temp
	});
}

/* Doesn't seem to fire on iOS10_Temp
-(void)_removeBulletin:(BBBulletin*)bulletin shouldSync:(BOOL)arg2
{
	%orig;

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		BBSectionInfo *sectionInfo = [bulletinNotificationSource _sectionInfoForBulletin:bulletin];

		NSString *sectionID = sectionInfo.sectionID;
		NCNotificationDispatcher *notificationDispatcher = bulletinNotificationSource.dispatcher;
		NCNotificationStore *notificationStore = notificationDispatcher.notificationStore;
		NCNotificationSection *notificationSection = [notificationStore.notificationSections objectForKey:sectionID];
		long count = 0;
		if (notificationSection) {
			count = (long)notificationSection.notificationsCount;
			// count = (long)notificationSection.coalescedNotifications.count;
		}
		bool showBadge = count > 0;
		[trackedNotifications setObject:[NSNumber numberWithBool:showBadge] forKey:sectionID];
		[trackedNotificationCount setObject:[NSNumber numberWithInteger:count] forKey:sectionID];
		if (preferences.enabled)
		{
			NSTimeInterval timeDiff = [lastProcessDateNC timeIntervalSinceDate:[NSDate date]];
			float processInterval = 0;
			if (timeDiff > -0.5) {
				processInterval = timeDiff + 0.5;
			}
			[lastProcessDateNC release];
			lastProcessDateNC = [[NSDate dateWithTimeInterval:processInterval sinceDate:[NSDate date]] retain];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, processInterval * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) { iOS10_Temp
				ProcessApplicationIcon(sectionID, 1);
			});
		}
	});
}*/
%end
#pragma mark #endregion
%end //group All

%group Group_InCallService
%hook TUCall
- (BOOL)setMuted:(BOOL)arg1
{
	BOOL ret = %orig;
	if (preferences && preferences.enabled && preferences.phoneMicMutedModeEnabled) {
		isPhoneMicMuted = arg1;
		UpdatePhoneMicMutedIcon();
	}

	return ret;
}
%end

%hook TUAudioSystemController
- (BOOL)setUplinkMuted:(BOOL)arg1
{
	BOOL ret = %orig;
	if (preferences && preferences.enabled && preferences.phoneMicMutedModeEnabled) {
		isPhoneMicMuted = arg1;
		UpdatePhoneMicMutedIcon();
	}

	return ret;
}
%end
%end

%group iOS10
%hook NCNotificationSectionListViewController
%new
- (void)ONUpdateNotificationCenterIcon
{
	int count = 0;
	if ([self hasContent]) {
		id sectionList = [self sectionList]; // sectionList = NCNotificationChronologicalList

		// iOS10_Temp - Way too slow and doesn't return an accurate count of visible items in the NC (returns some invisible items)
		// NSString *sectionID = notificationRequest.sectionIdentifier;
		// for (NCNotificationRequest *request in [sectionList allNotificationRequests]) {
		// 	if ([request.sectionIdentifier isEqualToString:sectionID]) {
		// 		count++;
		// 	}
		// }
		//
		// int showBadge = preferences.notificationCenterModeEnabled && count > 0 ? count : 0;
		// [trackedNotifications setObject:[NSNumber numberWithBool:showBadge] forKey:sectionID];
		// [trackedNotificationCount setObject:[NSNumber numberWithInteger:count] forKey:sectionID];
		// if (preferences.enabled)
		// {
		// 	NSTimeInterval timeDiff = [lastProcessDateNC timeIntervalSinceDate:[NSDate date]];
		// 	float processInterval = 0;
		// 	if (timeDiff > -0.5) {
		// 		processInterval = timeDiff + 0.5;
		// 	}
		// 	[lastProcessDateNC release];
		// 	lastProcessDateNC = [[NSDate dateWithTimeInterval:processInterval sinceDate:[NSDate date]] retain];
		// 	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, processInterval * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		// 		ProcessApplicationIcon(sectionID, 1);
		// 	});
		// }
		//
		// count = 0;
		for (int i = 0; i < [sectionList sectionCount]; i++) {
			count += [sectionList rowCountForSectionIndex:i];
		}
	}

	NSString *sectionID = @"Notification Center Icon";
	int showBadge = preferences.notificationCenterModeEnabled && count > 0 ? count : 0;
	[trackedNotifications setObject:[NSNumber numberWithBool:showBadge] forKey:sectionID];
	[trackedNotificationCount setObject:[NSNumber numberWithInteger:count] forKey:sectionID];
	if (preferences.enabled) {
		NSTimeInterval timeDiff = [lastProcessDateNC timeIntervalSinceDate:[NSDate date]];
		float processInterval = 0;
		if (timeDiff > -0.5) {
			processInterval = timeDiff + 0.5;
		}
		[lastProcessDateNC release];
		lastProcessDateNC = [[NSDate dateWithTimeInterval:processInterval sinceDate:[NSDate date]] retain];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, processInterval * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
			ProcessSystemIcon(sectionID, showBadge, @"");
		});
	}
}

- (BOOL)insertNotificationRequest:(NCNotificationRequest *)notificationRequest forCoalescedNotification:(id)arg2
{
	BOOL ret = %orig;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(ONUpdateNotificationCenterIcon) object:nil];
	[self performSelector:@selector(ONUpdateNotificationCenterIcon) withObject:nil afterDelay:2];

	return ret;
}

- (void)removeNotificationRequest:(NCNotificationRequest *)notificationRequest forCoalescedNotification:(id)arg2
{
	%orig;

	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(ONUpdateNotificationCenterIcon) object:nil];
	[self performSelector:@selector(ONUpdateNotificationCenterIcon) withObject:nil afterDelay:2];
}
%end

%hook NCBulletinNotificationSource
- (id)initWithDispatcher:(id)arg1
{
	bulletinNotificationSource = %orig;
	return bulletinNotificationSource;
}
%end

%hook CCUIDoNotDisturbSetting
-(void)_setDNDEnabled:(BOOL)arg1 updateServer:(BOOL)arg2 source:(unsigned long)arg3
{
	isQuiet = arg1;
	%orig;
	if (preferences.quietModeEnabled && preferences.enabled)
	{
		UpdateQuietIcon();
	}
}
%end
%end // iOS10

%group iOS8_10
#pragma mark #region [ SBTelephonyManager_iOS8 ]
%hook SBTelephonyManager
-(void)_setIsNetworkTethering:(BOOL)arg1 withNumberOfDevices:(int)arg2
{
	%orig;
	if (!changeTether)
	{
		UpdateTetherIcon();
	}
}
%end

%hook TUCallCapabilitiesState
-(void)setWiFiCallingCurrentlyAvailable:(BOOL)arg1
{
	isWiFiCallingActive = arg1;
	%orig;
	if (isSpringBoardLoaded && preferences.wiFiCallingModeEnabled && preferences.enabled) {
		// dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
			UpdateWiFiCallingIcon();
		// });
	}
}
%end

#pragma mark #endregion
%end // group iOS8

%ctor
{
	@autoreleasepool {
		statusBarItems = [[NSMutableDictionary alloc] init];
		currentIconSetList = [[NSMutableDictionary alloc] init];
		trackedBadges = [[NSMutableDictionary alloc] init];
		trackedBadgeCount = [[NSMutableDictionary alloc] init];
		trackedNotifications = [[NSMutableDictionary alloc] init];
		trackedNotificationCount = [[NSMutableDictionary alloc] init];
		if (!preferences) preferences = ONPreferences.sharedInstance;

		ReloadSettings();
		%init(All);
		%init(Group_InCallService);
		%init(iOS10);
		%init(iOS8_10);
	}
}
