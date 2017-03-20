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

#define UIKitVersionNumber_iOS_7_0 847.200000
#define UIKitVersionNumber_iOS_7_1_1 847.260000
#define UIKitVersionNumber_iOS_7_1_2 847.270000

@interface SBBulletinObserverViewController : UIViewController
- (id)firstSection;
-(unsigned int)_numberOfVisibleSections;
-(unsigned int)_numberOfBulletinsInSection:(id)arg1;
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
- (void)publishBulletin:(id)arg1 destinations:(unsigned long long)arg2 alwaysToLockScreen:(_Bool)arg3;
- (id)_allBulletinsForSectionID:(id)arg1;

- (id)allBulletinIDsForSectionID:(id)arg1;
- (id)noticesBulletinIDsForSectionID:(id)arg1;
- (id)bulletinIDsForSectionID:(id)arg1 inFeed:(unsigned long long)arg2;
@end


#pragma mark #region [ Private Variables ]
static ONPreferences* preferences;
static NSMutableDictionary* statusBarItems = [[NSMutableDictionary alloc] init];
static NSMutableDictionary* currentIconSetList = [[NSMutableDictionary alloc] init];
static NSMutableDictionary* trackedBadges = [[NSMutableDictionary alloc] init];
static NSMutableDictionary* trackedBadgeCount = [[NSMutableDictionary alloc] init];
static NSMutableDictionary* trackedNotifications = [[NSMutableDictionary alloc] init];
static NSMutableDictionary* trackedNotificationCount = [[NSMutableDictionary alloc] init];
//static BOOL isAirplane = false;
static int isAirPlay = 0;
static BOOL isAlarm = false;
static BOOL isBluetooth = false;
static BOOL isQuiet = false;
static BOOL isRotation = false;
static BOOL isVPN = false;
static BOOL changeTether = false;
static id mailBadge = nil;

static NSDate *lastProcessDateNC = nil;
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
	for (int i = 0; i < 33; i++)
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
	if (type == 0 && app.useNotifications == 1 && !preferences.globalUseBadges) return;
	if (type == 1 && app.useNotifications != 1 && !preferences.globalUseNotifications) return;

	BOOL shouldShow = YES;
	int count = 0;
	int countBadges = 0;
	int countNotifications = 0;
	if (app.useNotifications != 1 || preferences.globalUseBadges) {
		countBadges = [[trackedBadgeCount objectForKey:identifier] intValue];
	}
	if (app.useNotifications == 1 || preferences.globalUseNotifications) {
		countNotifications = [[trackedNotificationCount objectForKey:identifier] intValue];
	}
	Log(@"ProcessApplicationIcon (%D) %d, %d -- %@", type, countBadges, countNotifications, identifier);

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
			NSString* tmpName;
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
				tmpName = [NSString stringWithFormat:@"Count%d%@", 1, [name substringFromIndex:5]];
			}

			if (![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"/System/Library/Frameworks/UIKit.framework/Black_ON_%@.png", tmpName]]
				&& ![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"/System/Library/Frameworks/UIKit.framework/Black_ON_%@@2x.png", tmpName]]) {
				tmpName = [NSString stringWithFormat:@"Count%d%@", 100, [name substringFromIndex:5]];
			}

			if (![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"/System/Library/Frameworks/UIKit.framework/Black_ON_%@.png", tmpName]]
				&& ![NSFileManager.defaultManager fileExistsAtPath:[NSString stringWithFormat:@"/System/Library/Frameworks/UIKit.framework/Black_ON_%@@2x.png", tmpName]]) {
				name = [NSString stringWithFormat:@"Count%d%@", 10, [name substringFromIndex:5]];
			} else {
				name = tmpName;
			}

			if (shouldShow)
			{
				// Remove icon so it can be readded with a different count value
				[statusBarItems removeObjectForKey:uniqueName];
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

static void ProcessSystemIcon(NSString* identifier, bool shouldShow, NSString* alt)
{
	if (!preferences.enabled) return;

	ONApplication* app;
	if (!(app = [preferences getApplication:identifier])) return;

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
			name = [NSString stringWithFormat:@"Count%d%@", 1, [name substringFromIndex:5]];
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

			if (![uniqueIcon.allKeys containsObject:ONIconNameKey])
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
				if ([tm respondsToSelector:@selector(setIsNetworkTethering)]) {
					[tm setIsNetworkTethering:NO withNumberOfDevices:0];
					[tm setIsNetworkTethering:YES withNumberOfDevices:i];
				} else if ([tm respondsToSelector:@selector(_setIsNetworkTethering)]) {
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

//static void UpdateAirplaneIcon()
//{
//	if (airplaneIconItem)
//	{
//		[airplaneIconItem release];
//		airplaneIconItem = nil;
//	}
//
//	if (preferences.airplaneModeEnabled)
//	{
//		SBTelephonyManager *tm = [%c(SBTelephonyManager) sharedTelephonyManager];
//		if (tm && tm.isInAirplaneMode)
//		{
//			airplaneIconItem = [CreateStatusBarItem(ONAirplaneKey, ONAirplaneKey, preferences.airplaneIconOnLeft) retain];
//		}
//	}
//}

static void UpdateAirPlayIcon()
{
	ProcessSystemIcon(@"AirPlay Icon", preferences.airPlayModeEnabled && isAirPlay == 1, @"");
	if (preferences.airPlayModeEnabled && preferences.enabled && isAirPlay == 1)
	{
		SetSystemIcon(@"Indicator:AirPlay (Right)", false);
	}
	else
	{
		SetSystemIcon(@"Indicator:AirPlay (Right)", isAirPlay, true); //reset to whatever iOS wants
	}
}

static void UpdateAlarmIcon()
{
	ProcessSystemIcon(@"Alarm Icon", preferences.alarmModeEnabled && (isAlarm == !preferences.alarmModeInverted), @"");
	if (preferences.alarmModeEnabled && isAlarm && preferences.enabled)
	{
		SetSystemIcon(@"Indicator:Alarm (Right)", false);
	}
	else
	{
		SetSystemIcon(@"Indicator:Alarm (Right)", isAlarm);
	}
}

static void UpdateBluetoothIcon()
{
	BluetoothManager *bm = [%c(BluetoothManager) sharedInstance];
	isBluetooth = bm && bm.enabled;
	if (preferences.bluetoothModeEnabled && preferences.enabled)
	{
		SetSystemIcon(@"Bluetooth (Right)", false);
	}
	else
	{
		SetSystemIcon(@"Bluetooth (Right)", isBluetooth);
	}

	ProcessSystemIcon(@"Bluetooth Icon", preferences.bluetoothModeEnabled && isBluetooth && (bm.connected || preferences.bluetoothAlwaysEnabled), bm.connected ? @"_ENBD" : @"");
}

static void UpdateQuietIcon()
{
	ProcessSystemIcon(@"Do Not Disturb Icon", preferences.quietModeEnabled && (isQuiet == !preferences.quietModeInverted), @"");
	if (preferences.quietModeEnabled && isQuiet && preferences.enabled)
	{
		SetSystemIcon(@"QuietMode:QuietMode (Right)", false);
	}
	else
	{
		SetSystemIcon(@"QuietMode:QuietMode (Right)", isQuiet);
	}
}

static void UpdateRotationLockIcon()
{
	SBOrientationLockManager *bm = [%c(SBOrientationLockManager) sharedInstance];
	isRotation = bm && bm.isLocked;
	ProcessSystemIcon(@"Rotation Lock Icon", (isRotation == !preferences.rotationLockModeInverted) && preferences.rotationLockModeEnabled, @"");
	if (preferences.rotationLockModeEnabled && preferences.enabled)
	{
		SetSystemIcon(@"Indicator:RotationLock (Right)", false);
	}
	else
	{
		SetSystemIcon(@"Indicator:RotationLock (Right)", isRotation);
	}
}

static void UpdateVPNIcon()
{
	SBTelephonyManager *tm = [%c(SBTelephonyManager) sharedTelephonyManager];
	isVPN = tm && tm.isUsingVPNConnection;
	ProcessSystemIcon(@"VPN Icon", isVPN && preferences.vPNModeEnabled, @"");
	if (preferences.vPNModeEnabled && preferences.enabled)
	{
		SetSystemIcon(@"Indicator:VPN (Left/Right)", false);
	}
	else
	{
		SetSystemIcon(@"Indicator:VPN (Left/Right)", isVPN);
	}

}

static int isAirPlayActive()
{
	if (!preferences.enabled || !preferences.airPlayModeEnabled)
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

static void HideMailSettingsChanged()
{
	ReloadSettings();

	SBApplicationController* sbac = %c(SBApplicationController);
	if (sbac != NULL)
	{
		SBApplication *mailApp;
		if (kCFCoreFoundationVersionNumber > UIKitVersionNumber_iOS_7_1_2) {
			mailApp = [[sbac sharedInstance] applicationWithBundleIdentifier:@"com.apple.mobilemail"];
		} else {
			mailApp = [[sbac sharedInstance] applicationWithDisplayIdentifier:@"com.apple.mobilemail"];
		}
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
		SetSystemIcon(@"Bluetooth (Right)", isBluetooth);
		SetSystemIcon(@"Indicator:Alarm (Right)", isAlarm);
		// isAirPlay = isAirPlayActive();
		SetSystemIcon(@"Indicator:AirPlay (Right)", isAirPlay, true); //reset
		SetSystemIcon(@"QuietMode:QuietMode (Right)", isQuiet);
		SetSystemIcon(@"Indicator:RotationLock (Right)", isRotation);
		SetSystemIcon(@"Indicator:VPN (Left/Right)", isVPN);
		return;
	}

	UpdateSilentIcon();
	UpdateVibrateIcon();
	UpdateTetherIcon();
	UpdateAirPlayIcon();
//	UpdateAirplaneIcon();
	UpdateAlarmIcon();
	UpdateBluetoothIcon();
	UpdateQuietIcon();
	UpdateRotationLockIcon();
	UpdateVPNIcon();

	[trackedBadges.allKeys enumerateObjectsUsingBlock: ^(id key, NSUInteger index, BOOL* stop){
		ProcessApplicationIcon(key);
	}];

	[trackedNotifications.allKeys enumerateObjectsUsingBlock: ^(id key, NSUInteger index, BOOL* stop){
		ProcessApplicationIcon(key, 1);
	}];
}

static void InitBadges()
{
	if ([%c(SBIconViewMap) respondsToSelector:@selector(homescreenMap)]) {
		for (NSString *identifier in [[[%c(SBIconViewMap) homescreenMap] iconModel] visibleIconIdentifiers]) {
			SBIcon *icon;
			if (kCFCoreFoundationVersionNumber > UIKitVersionNumber_iOS_7_1_2) {
				icon = (SBIcon *)[[[%c(SBIconViewMap) homescreenMap] iconModel] applicationIconForBundleIdentifier:identifier];
			} else {
				icon = (SBIcon *)[[[%c(SBIconViewMap) homescreenMap] iconModel] applicationIconForDisplayIdentifier:identifier];
			}
			if (icon && [icon badgeNumberOrString] && ([[icon badgeNumberOrString] intValue] > 0)) {
				[trackedBadges setObject:NSBool(YES) forKey:identifier];
				[trackedBadgeCount setObject:[icon badgeNumberOrString] forKey:identifier];
				ProcessApplicationIcon(identifier);
			}
		}
	}

	SBNotificationCenterController *nc = (SBNotificationCenterController *)[%c(SBNotificationCenterController) sharedInstance];
	if (nc)
	{
		SBBulletinObserverViewController *observer = (SBBulletinObserverViewController *)[nc.viewController _allModeViewControllerCreateIfNecessary:YES];
		id section;
		if ((section = [observer firstSection]) != nil)
		{
			id section = [observer firstSection];
			while (section)
			{
				bool showBadge = [observer _numberOfBulletinsInSection:section] > 0;
				[trackedNotifications setObject:[NSNumber numberWithBool:showBadge] forKey:section];
				[trackedNotificationCount setObject:[NSNumber numberWithInteger:[observer _numberOfBulletinsInSection:section]] forKey:section];
				if (preferences.enabled) ProcessApplicationIcon(section, 1);
				section = [observer sectionAfterSection:section];
			}
		}
	}
}
#pragma mark #endregion

%group All
#pragma mark #region [ SpringBoard ]
%hook SpringBoard

%new - (void)AVAudioRouteChanged:(NSNotification*)notification
{
	if (!preferences.airPlayModeEnabled || !preferences.enabled)
		return;

	PostNotification((CFStringRef)AirPlayModeChangedNotification);
}

-(id)init
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	// ReloadSettings();
	NSMutableArray* imageNames = [NSMutableArray arrayWithArray:[[NSFileManager defaultManager]
		contentsOfDirectoryAtPath:@"/System/Library/Frameworks/UIKit.framework/" error:nil]
	];

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
	AddObserver((CFStringRef)QuietModeChangedNotification, QuietModeSettingsChanged);
	AddObserver((CFStringRef)RotationLockModeChangedNotification, RotationLockModeSettingsChanged);
	AddObserver((CFStringRef)VPNModeChangedNotification, VPNModeSettingsChanged);

	AddObserver((CFStringRef)HideMailChangedNotification, HideMailSettingsChanged);

	CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
	CFNotificationCenterAddObserver(center, NULL, (CFNotificationCallback)&UpdateVibrateIcon, CFSTR("com.apple.springboard.ring-vibrate.changed"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	CFNotificationCenterAddObserver(center, NULL, (CFNotificationCallback)&UpdateVibrateIcon, CFSTR("com.apple.springboard.silent-vibrate.changed"), NULL, CFNotificationSuspensionBehaviorCoalesce);

	[%c(AVAudioSession) sharedInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AVAudioRouteChanged:) name:@"AVAudioSessionRouteChangeNotification" object:nil];

	#ifdef DEBUGPREFS
	dispatch_queue_t queue = dispatch_get_main_queue();
	dispatch_async(queue,
	^{
		SBAwayController* c = [%c(SBAwayController) sharedAwayController];
		[c attemptUnlock];
		[c unlockWithSound:false];
		[[%c(SBUserAgent) sharedUserAgent] openURL:[NSURL URLWithString:@"prefs:root=OpenNotifier"] allowUnlock:true animated:true];
		dispatch_release(queue);
	});
	#endif

	InitBadges();
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

#pragma mark #region [ SBSoundPreferences ]
%hook SBSoundPreferences
-(void)userDefaultsDidChanged:(id)arg1
{
	%orig;
	if (preferences.vibrateModeEnabled && preferences.enabled)
	{
		UpdateVibrateIcon();
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

//-(void)_updateAirplaneMode
//{
//	if (preferences.airplaneModeEnabled)
//	{
//		UpdateAirplaneIcon();
//		return;
//	}
//	%orig;
//}

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
//		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, processInterval * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
			ProcessApplicationIcon(self.bundleIdentifier);
//		});
	}
}
%end
#pragma mark #endregion

#pragma mark #region [ BBServer ]
%hook SBBulletinObserverViewController
- (void)removeBulletin:(id)bulletinInfo fromSection:(id)sectionInfo
{
	%orig;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		Log(@"removeBulletin\n%@\n%@\n%@\n%@", bulletinInfo, sectionInfo, [sectionInfo class], [bulletinInfo class]);

		if (kCFCoreFoundationVersionNumber > UIKitVersionNumber_iOS_7_1_2) {
			if (![sectionInfo isKindOfClass:%c(SBNotificationCenterSectionInfo)] || ![bulletinInfo isKindOfClass:%c(SBNotificationsAllModeBulletinInfo)]) {
				return;
			}
		} else {
			if (![sectionInfo isKindOfClass:%c(SBNotificationsSectionInfo)] || ![bulletinInfo isKindOfClass:%c(SBNotificationsAllModeBulletinInfo)]) {
				return;
			}
		}


		NSString *section = [[sectionInfo representedListSection] sectionID];
		int count = [self _numberOfBulletinsInSection:sectionInfo];
		bool showBadge = count > 0;
		[trackedNotifications setObject:[NSNumber numberWithBool:showBadge] forKey:section];
		[trackedNotificationCount setObject:[NSNumber numberWithInteger:count] forKey:section];
		if (preferences.enabled)
		{
			NSTimeInterval timeDiff = [lastProcessDateNC timeIntervalSinceDate:[NSDate date]];
			float processInterval = 0;
			if (timeDiff > -0.5) {
				processInterval = timeDiff + 0.5;
			}
			[lastProcessDateNC release];
			lastProcessDateNC = [[NSDate dateWithTimeInterval:processInterval sinceDate:[NSDate date]] retain];
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, processInterval * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
				ProcessApplicationIcon(section, 1);
			});
		}
	});
}
%end

%hook BBServer
- (void)publishBulletin:(BBBulletin*)bulletin destinations:(unsigned long long)arg2 alwaysToLockScreen:(BOOL)arg3
{
	%orig;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		Log(@"publishBulletin\n%@", bulletin);

		if (![bulletin isKindOfClass:%c(BBBulletin)]) {
			return;
		}

		NSString *section = bulletin.sectionID;
		NSArray *bulletins = [self noticesBulletinIDsForSectionID:section];
		bool showBadge = bulletins.count > 0;
		[trackedNotifications setObject:[NSNumber numberWithBool:showBadge] forKey:section];
		[trackedNotificationCount setObject:[NSNumber numberWithInteger:bulletins.count] forKey:section];
		if (preferences.enabled) ProcessApplicationIcon(section, 1);
	});
}
%end
#pragma mark #endregion
%end //group All

%group iOS7
%hook SBCCSettingsSectionController
-(void)_setDNDEnabled:(BOOL)arg1 updateServer:(BOOL)arg2
{
	isQuiet = arg1;
	%orig;
	if (preferences.quietModeEnabled && preferences.enabled)
	{
		UpdateQuietIcon();
	}
}
%end

#pragma mark #region [ SBTelephonyManager_iOS7 ]
%hook SBTelephonyManager
-(void)setIsNetworkTethering:(BOOL)arg1 withNumberOfDevices:(int)arg2
{
	%orig;
	if (!changeTether)
	{
		UpdateTetherIcon();
	}
}
%end
#pragma mark #endregion
%end

%group iOS8
%hook SBCCDoNotDisturbSetting
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
#pragma mark #endregion
%end

%ctor
{
	@autoreleasepool {
		ReloadSettings();
		%init(All);

		if (kCFCoreFoundationVersionNumber > UIKitVersionNumber_iOS_7_1_2) {
			%init(iOS8);
		} else {
			%init(iOS7);
		}
	}
}
