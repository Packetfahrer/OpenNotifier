#import "Tweak.h"
#import "Preferences.h"

#pragma mark #region [ ONApplicationIcon ]
@implementation ONApplicationIcon
+(id)createInstance { return [[ONApplicationIcon alloc] init]; }
+(id)createInstanceWithDictionary:(NSMutableDictionary*)aDictionary { return [[ONApplicationIcon alloc] initWithDictionary:aDictionary]; }

-(id)init
{
	if (!(self = [super init])) return nil;
	_dictionary = [[NSMutableDictionary alloc] init];
	return self;
}

-(id)initWithDictionary:(NSMutableDictionary*)aDictionary
{
	if (![self init]) return nil;
	_dictionary = [aDictionary retain];
	return self;
}

-(void)dealloc
{
	[_dictionary release];
	[super dealloc];
}

-(ONIconAlignment)alignment
{
	return [_dictionary.allKeys containsObject:ONIconAlignmentKey]
		? (ONIconAlignment)[[_dictionary objectForKey:ONIconAlignmentKey] intValue]
		: ONIconAlignmentDefault;
}

-(void)setAlignment:(ONIconAlignment)value
{
	[_dictionary setObject:[NSNumber numberWithUnsignedInt:value] forKey:ONIconAlignmentKey];
}

-(NSMutableDictionary*)toDictionary { return _dictionary; }

@end
#pragma mark #endregion

#pragma mark #region [ ONApplication ]
@implementation ONApplication
@synthesize icons;

+(id)createInstance
{
	return [[ONApplication alloc] init];
}

-(id)init
{
	if (!(self = [super init])) return nil;
	self.icons = [NSMutableDictionary dictionary];
	self.useBadges = 2;
	self.useNotifications = 2;
	return self;
}

-(void)dealloc
{
	[self.icons release];
	[super dealloc];
}

-(NSMutableDictionary*)toDictionary
{
	NSMutableDictionary* value = [NSMutableDictionary dictionary];
	if (self.useBadges < 2)
	{
		[value setObject:[NSNumber numberWithBool:(self.useBadges == 1)] forKey:ONUseBadgesKey];
	}

	if (self.useNotifications < 2)
	{
		[value setObject:[NSNumber numberWithBool:(self.useNotifications == 1)] forKey:ONUseNotificationsKey];
	}

	if (self.icons.allKeys.count > 0)
	{
		NSMutableDictionary* iconDict = [NSMutableDictionary dictionary];
		for (NSString* name in self.icons.allKeys)
		{
			ONApplicationIcon* icon = [self.icons objectForKey:name];
			if (icon) [iconDict setObject:[icon toDictionary] forKey:name];
		}
		[value setObject:iconDict forKey:ONIconsKey];
	}

	return value;
}

-(void)addUseBadges:(BOOL)useBadges
{
	self.useBadges = useBadges ? 1 : 0;
}

-(void)addUseNotifications:(BOOL)useNotifications
{
	self.useNotifications = useNotifications ? 1 : 0;
}

-(id)addIcon:(NSString*)iconName
{
	[self.icons setObject:[ONApplicationIcon createInstance] forKey:iconName];
	return [self.icons objectForKey:iconName];
}

-(void)removeIcon:(NSString*)iconName
{
	[self.icons removeObjectForKey:iconName];
}

-(bool)containsIcon:(NSString*)iconName
{
	return [self.icons.allKeys containsObject:iconName];
}

@end
#pragma mark #endregion

#pragma mark #region [ ONPreferences ]
static ONPreferences* _instance;
@implementation ONPreferences

+(id)sharedInstance
{
	return (_instance = [[[ONPreferences alloc] init] retain]);
}

-(id)init
{
	if (_instance) { [self release]; return _instance; }
	if (!(self = [super init])) return nil;
	[self reload];
	return (_instance = self);
}

-(void)dealloc
{
	[_data release];
	[super dealloc];
}

-(int)schemaVersion
{
	return [_data.allKeys containsObject:ONSchemaVersionKey] ? [[_data objectForKey:ONSchemaVersionKey] intValue] : 0;
}

-(void)loadAppsVersion00
{
	if (![_data.allKeys containsObject:ONApplicationsKey]) return;

	NSDictionary* appData = [_data objectForKey:ONApplicationsKey];
	for (NSString* identifer in appData.allKeys)
	{
		ONApplication* app = [ONApplication createInstance];
		NSArray* icons = [appData objectForKey:identifer];
		for (NSString* iconName in icons)
		{
			[app.icons setObject:[ONApplicationIcon createInstance] forKey:iconName];
		}

		[_applications setObject:app forKey:identifer];
	}
}

-(void)loadAppsVersion01
{
	if (![_data.allKeys containsObject:ONApplicationsKey]) return;

	NSDictionary* appData = [_data objectForKey:ONApplicationsKey];
	for (NSString* identifer in appData.allKeys)
	{
		if (![[appData objectForKey:identifer] isKindOfClass:[NSDictionary class]]) continue; //Fix crash if an old AppsVersion00 icon is still in the plist file

		ONApplication* app = [ONApplication createInstance];
		app.useBadges = [[appData objectForKey:identifer] objectForKey:ONUseBadgesKey] == nil ? 2 : ([[[appData objectForKey:identifer] objectForKey:ONUseBadgesKey] boolValue] ? 1 : 0);
		app.useNotifications = [[appData objectForKey:identifer] objectForKey:ONUseNotificationsKey] == nil ? 2 : ([[[appData objectForKey:identifer] objectForKey:ONUseNotificationsKey] boolValue] ? 1 : 0);
		NSMutableDictionary* icons = [[appData objectForKey:identifer] objectForKey:ONIconsKey];
		for (NSString* iconName in icons.allKeys)
		{
			[app.icons setObject:[ONApplicationIcon createInstanceWithDictionary:[icons objectForKey:iconName]] forKey:iconName];
		}
		[_applications setObject:app forKey:identifer];
	}
}

-(NSMutableDictionary*)applications
{
	if (_applications) return _applications;
	_applications = [[NSMutableDictionary alloc] init];

	switch (self.schemaVersion)
	{
		case 0: [self loadAppsVersion00]; break;
		default: [self loadAppsVersion01]; break;
	}

	return _applications;
}

-(ONApplication*)getApplication:(NSString*)identifer
{
	return [self.applications objectForKey:identifer];
}

-(NSArray*)getBluetoothIdentifers
{
	NSArray *keys = [self.applications allKeys];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF beginsWith[c] 'ONBluetooth-'"];
	return [keys filteredArrayUsingPredicate:predicate];
}

-(void)setApplication:(ONApplication*)application named:(NSString*)identifer
{
	[self.applications setObject:application forKey:identifer];
}

-(void)removeApplication:(NSString*)identifer
{
	[self.applications removeObjectForKey:identifer];
}

-(void)addUseBadges:(BOOL)useBadges forApplication:(NSString*)identifer
{
	ONApplication* app = [self getApplication:identifer];
	if (!app && !(app = [ONApplication createInstance]))
	{
		Log("Failed to get or create ONApplication");
		return;
	}
	[app addUseBadges:useBadges];
	[self setApplication:app named:identifer];
}

-(void)addUseNotifications:(BOOL)useNotifications forApplication:(NSString*)identifer
{
	ONApplication* app = [self getApplication:identifer];
	if (!app && !(app = [ONApplication createInstance]))
	{
		Log("Failed to get or create ONApplication");
		return;
	}
	[app addUseNotifications:useNotifications];
	[self setApplication:app named:identifer];
}

-(id)addIcon:(NSString*)iconName forApplication:(NSString*)identifer
{
	ONApplication* app = [self getApplication:identifer];
	if (!app && !(app = [ONApplication createInstance]))
	{
		Log("Failed to get or create ONApplication");
		return nil;
	}
	[app addIcon:iconName];
	[self setApplication:app named:identifer];
	return [app.icons objectForKey:iconName];
}

-(void)removeIcon:(NSString*)iconName fromApplication:(NSString*)identifer;
{
	ONApplication* app = [self getApplication:identifer];
	if (!app) return;
	[app removeIcon:iconName];
	if (app.icons.allKeys.count == 0) [self removeApplication:identifer];
}

-(ONApplicationIcon*)getIcon:(NSString*)iconName forApplication:(NSString*)identifer
{
	ONApplication* app = [self getApplication:identifer];
	if (!app) return nil;
	return [app.icons objectForKey:iconName];
}

-(bool)iconsOnLeft
{
	return [_data.allKeys containsObject:ONIconsLeftKey] ? [[_data objectForKey:ONIconsLeftKey] boolValue] : false;
}

-(void)setIconsOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONIconsLeftKey];
	[self save];
}

-(bool)enabled
{
	return [_data.allKeys containsObject:ONEnabledKey] ? [[_data objectForKey:ONEnabledKey] boolValue] : true;
}

-(void)setEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONEnabledKey];
	[self save];
}

-(bool)globalUseBadges
{
	return [_data.allKeys containsObject:ONGlobalUseBadgesKey] ? [[_data objectForKey:ONGlobalUseBadgesKey] boolValue] : false;
}

-(void)setGlobalUseBadges:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONGlobalUseBadgesKey];
	[self save];
}

-(bool)globalUseNotifications
{
	return [_data.allKeys containsObject:ONGlobalUseNotificationsKey] ? [[_data objectForKey:ONGlobalUseNotificationsKey] boolValue] : false;
}

-(void)setGlobalUseNotifications:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONGlobalUseNotificationsKey];
	[self save];
}

-(bool)hideMail
{
	return [_data.allKeys containsObject:ONHideMailKey] ? [[_data objectForKey:ONHideMailKey] boolValue] : false;
}

-(void)setHideMail:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONHideMailKey];
	[self saveWithNotification:HideMailChangedNotification];
}

-(void)reload
{
	if (_applications) { [_applications release]; _applications = nil; }
	if (_data) [_data release];
	_data = [[NSMutableDictionary alloc] initWithContentsOfFile:ONPreferencesFile];
	if (!_data)
	{
		// Check for official version plist file
		_data = [[NSMutableDictionary alloc] initWithContentsOfFile:ONPreferencesFileOrg];
		if (_data)
		{
			[self saveWithNotification:IconSettingsChangedNotification];
		}
	}
	if (!_data) _data = [[NSMutableDictionary alloc] init]; // new setup
}

-(void)saveWithNotification:(NSString*)notification
{
	[_data removeObjectForKey:@"pseudobadges"];

	// Convert the objects back to a writeable dictionary
	// to avoid having to use NSKeyArchiver
	NSMutableDictionary* apps = [NSMutableDictionary dictionary];
	for (NSString* identifer in self.applications.allKeys)
	{
		[apps setObject:[[self getApplication:identifer] toDictionary] forKey:identifer];
	}
	[_data setObject:apps forKey:ONApplicationsKey];

	[_data setObject:[NSNumber numberWithUnsignedInt:ONSchemaVersion] forKey:ONSchemaVersionKey];

	[_data setObject:@(NO) forKey:@"profileSaved"];
	if (![_data writeToFile:ONPreferencesFile atomically:true])
	{
		Log("Failed to save settings");
		return;
	}

	PostNotification((CFStringRef)notification);
}

-(void)save
{
	[self saveWithNotification:IconSettingsChangedNotification];
}

-(bool)silentModeEnabled
{
	return [_data.allKeys containsObject:ONSilentModeEnabledKey] ? [[_data objectForKey:ONSilentModeEnabledKey] boolValue] : false;
}

-(void)setSilentModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONSilentModeEnabledKey];
	[self saveWithNotification:SilentModeChangedNotification];
}

-(bool)silentModeInverted
{
	return [_data.allKeys containsObject:ONSilentModeInvertedKey] ? [[_data objectForKey:ONSilentModeInvertedKey] boolValue] : false;
}

-(void)setSilentModeInverted:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONSilentModeInvertedKey];
	[self saveWithNotification:SilentModeChangedNotification];
}

-(bool)silentIconOnLeft
{
	return [_data.allKeys containsObject:ONSilentIconLeftKey] ? [[_data objectForKey:ONSilentIconLeftKey] boolValue]: false;
}

-(void)setSilentIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONSilentIconLeftKey];
	[self saveWithNotification:SilentModeChangedNotification];
}

-(bool)vibrateModeEnabled
{
	return [_data.allKeys containsObject:ONVibrateModeEnabledKey] ? [[_data objectForKey:ONVibrateModeEnabledKey] boolValue] : false;
}

-(void)setVibrateModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONVibrateModeEnabledKey];
	[self saveWithNotification:VibrateModeChangedNotification];
}

-(bool)vibrateModeInverted
{
	return [_data.allKeys containsObject:ONVibrateModeInvertedKey] ? [[_data objectForKey:ONVibrateModeInvertedKey] boolValue] : false;
}

-(void)setVibrateModeInverted:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONVibrateModeInvertedKey];
	[self saveWithNotification:VibrateModeChangedNotification];
}

-(bool)vibrateIconOnLeft
{
	return [_data.allKeys containsObject:ONVibrateIconLeftKey] ? [[_data objectForKey:ONVibrateIconLeftKey] boolValue]: false;
}

-(void)setVibrateIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONVibrateIconLeftKey];
	[self saveWithNotification:VibrateModeChangedNotification];
}

-(bool)tetherModeEnabled
{
	return [_data.allKeys containsObject:ONTetherModeEnabledKey] ? [[_data objectForKey:ONTetherModeEnabledKey] boolValue] : false;
}

-(void)setTetherModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONTetherModeEnabledKey];
	[self saveWithNotification:TetherModeChangedNotification];
}

-(bool)tetherIconOnLeft
{
	return [_data.allKeys containsObject:ONTetherIconLeftKey] ? [[_data objectForKey:ONTetherIconLeftKey] boolValue]: false;
}

-(void)setTetherIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONTetherIconLeftKey];
	[self saveWithNotification:TetherModeChangedNotification];
}

// -(bool)airplaneModeEnabled
// {
// 	return [_data.allKeys containsObject:ONAirplaneModeEnabledKey] ? [[_data objectForKey:ONAirplaneModeEnabledKey] boolValue] : false;
// }
//
// -(void)setAirplaneModeEnabled:(bool)value
// {
// 	[_data setObject:NSBool(value) forKey:ONAirplaneModeEnabledKey];
// 	[self saveWithNotification:AirplaneModeChangedNotification];
// }
//
// -(bool)airplaneIconOnLeft
// {
// 	return [_data.allKeys containsObject:ONAirplaneIconLeftKey] ? [[_data objectForKey:ONAirplaneIconLeftKey] boolValue]: false;
// }
//
// -(void)setAirplaneIconOnLeft:(bool)value
// {
// 	[_data setObject:NSBool(value) forKey:ONAirplaneIconLeftKey];
// 	[self saveWithNotification:AirplaneModeChangedNotification];
// }

-(bool)airPlayModeEnabled
{
	return [_data.allKeys containsObject:ONAirPlayModeEnabledKey] ? [[_data objectForKey:ONAirPlayModeEnabledKey] boolValue] : false;
}

-(void)setAirPlayModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONAirPlayModeEnabledKey];
	[self saveWithNotification:AirPlayModeChangedNotification];
}

-(bool)airPlayAlwaysEnabled
{
	return [_data.allKeys containsObject:ONAirPlayAlwaysEnabledKey] ? [[_data objectForKey:ONAirPlayAlwaysEnabledKey] boolValue] : true;
}

-(void)setAirPlayAlwaysEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONAirPlayAlwaysEnabledKey];
	[self saveWithNotification:AirPlayModeChangedNotification];
}

-(bool)airPlayIconOnLeft
{
	return [_data.allKeys containsObject:ONAirPlayIconLeftKey] ? [[_data objectForKey:ONAirPlayIconLeftKey] boolValue]: false;
}

-(void)setAirPlayIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONAirPlayIconLeftKey];
	[self saveWithNotification:AirPlayModeChangedNotification];
}

-(bool)alarmModeEnabled
{
	return [_data.allKeys containsObject:ONAlarmModeEnabledKey] ? [[_data objectForKey:ONAlarmModeEnabledKey] boolValue] : false;
}

-(void)setAlarmModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONAlarmModeEnabledKey];
	[self saveWithNotification:AlarmModeChangedNotification];
}

-(bool)alarmModeInverted
{
	return [_data.allKeys containsObject:ONAlarmModeInvertedKey] ? [[_data objectForKey:ONAlarmModeInvertedKey] boolValue] : false;
}

-(void)setAlarmModeInverted:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONAlarmModeInvertedKey];
	[self saveWithNotification:AlarmModeChangedNotification];
}

-(bool)alarmIconOnLeft
{
	return [_data.allKeys containsObject:ONAlarmIconLeftKey] ? [[_data objectForKey:ONAlarmIconLeftKey] boolValue]: false;
}

-(void)setAlarmIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONAlarmIconLeftKey];
	[self saveWithNotification:AlarmModeChangedNotification];
}

-(bool)bluetoothModeEnabled
{
	return [_data.allKeys containsObject:ONBluetoothModeEnabledKey] ? [[_data objectForKey:ONBluetoothModeEnabledKey] boolValue] : false;
}

-(void)setBluetoothModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONBluetoothModeEnabledKey];
	[self saveWithNotification:BluetoothModeChangedNotification];
}

-(bool)bluetoothAlwaysEnabled
{
	return [_data.allKeys containsObject:ONBluetoothAlwaysEnabledKey] ? [[_data objectForKey:ONBluetoothAlwaysEnabledKey] boolValue] : true;
}

-(void)setBluetoothAlwaysEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONBluetoothAlwaysEnabledKey];
	[self saveWithNotification:BluetoothModeChangedNotification];
}

-(bool)bluetoothIconOnLeft
{
	return [_data.allKeys containsObject:ONBluetoothIconLeftKey] ? [[_data objectForKey:ONBluetoothIconLeftKey] boolValue]: false;
}

-(void)setBluetoothIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONBluetoothIconLeftKey];
	[self saveWithNotification:BluetoothModeChangedNotification];
}

-(bool)lowPowerModeEnabled
{
	return [_data.allKeys containsObject:ONLowPowerModeEnabledKey] ? [[_data objectForKey:ONLowPowerModeEnabledKey] boolValue] : false;
}

-(void)setLowPowerModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONLowPowerModeEnabledKey];
	[self saveWithNotification:LowPowerModeChangedNotification];
}

-(bool)lowPowerIconOnLeft
{
	return [_data.allKeys containsObject:ONLowPowerIconLeftKey] ? [[_data objectForKey:ONLowPowerIconLeftKey] boolValue]: false;
}

-(void)setLowPowerIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONLowPowerIconLeftKey];
	[self saveWithNotification:LowPowerModeChangedNotification];
}

-(bool)phoneMicMutedModeEnabled
{
	return [_data.allKeys containsObject:ONPhoneMicMutedModeEnabledKey] ? [[_data objectForKey:ONPhoneMicMutedModeEnabledKey] boolValue] : false;
}

-(void)setPhoneMicMutedModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONPhoneMicMutedModeEnabledKey];
	[self saveWithNotification:PhoneMicMutedModeChangedNotification];
}

-(bool)phoneMicMutedIconOnLeft
{
	return [_data.allKeys containsObject:ONPhoneMicMutedIconLeftKey] ? [[_data objectForKey:ONPhoneMicMutedIconLeftKey] boolValue]: false;
}

-(void)setPhoneMicMutedIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONPhoneMicMutedIconLeftKey];
	[self saveWithNotification:PhoneMicMutedModeChangedNotification];
}

-(bool)quietModeEnabled
{
	return [_data.allKeys containsObject:ONQuietModeEnabledKey] ? [[_data objectForKey:ONQuietModeEnabledKey] boolValue] : false;
}

-(void)setQuietModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONQuietModeEnabledKey];
	[self saveWithNotification:QuietModeChangedNotification];
}

-(bool)quietModeInverted
{
	return [_data.allKeys containsObject:ONQuietModeInvertedKey] ? [[_data objectForKey:ONQuietModeInvertedKey] boolValue] : false;
}

-(void)setQuietModeInverted:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONQuietModeInvertedKey];
	[self saveWithNotification:QuietModeChangedNotification];
}

-(bool)quietIconOnLeft
{
	return [_data.allKeys containsObject:ONQuietIconLeftKey] ? [[_data objectForKey:ONQuietIconLeftKey] boolValue]: false;
}

-(void)setQuietIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONQuietIconLeftKey];
	[self saveWithNotification:QuietModeChangedNotification];
}

-(bool)rotationLockModeEnabled
{
	return [_data.allKeys containsObject:ONRotationLockModeEnabledKey] ? [[_data objectForKey:ONRotationLockModeEnabledKey] boolValue] : false;
}

-(void)setRotationLockModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONRotationLockModeEnabledKey];
	[self saveWithNotification:RotationLockModeChangedNotification];
}

-(bool)rotationLockModeInverted
{
	return [_data.allKeys containsObject:ONRotationLockModeInvertedKey] ? [[_data objectForKey:ONRotationLockModeInvertedKey] boolValue] : false;
}

-(void)setRotationLockModeInverted:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONRotationLockModeInvertedKey];
	[self saveWithNotification:RotationLockModeChangedNotification];
}

-(bool)rotationLockIconOnLeft
{
	return [_data.allKeys containsObject:ONRotationLockIconLeftKey] ? [[_data objectForKey:ONRotationLockIconLeftKey] boolValue]: false;
}

-(void)setRotationLockIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONRotationLockIconLeftKey];
	[self saveWithNotification:RotationLockModeChangedNotification];
}

-(bool)vPNModeEnabled
{
	return [_data.allKeys containsObject:ONVPNModeEnabledKey] ? [[_data objectForKey:ONVPNModeEnabledKey] boolValue] : false;
}

-(void)setVPNModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONVPNModeEnabledKey];
	[self saveWithNotification:VPNModeChangedNotification];
}

-(bool)vPNIconOnLeft
{
	return [_data.allKeys containsObject:ONVPNIconLeftKey] ? [[_data objectForKey:ONVPNIconLeftKey] boolValue]: false;
}

-(void)setVPNIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONVPNIconLeftKey];
	[self saveWithNotification:VPNModeChangedNotification];
}

-(bool)watchModeEnabled
{
	return [_data.allKeys containsObject:ONWatchModeEnabledKey] ? [[_data objectForKey:ONWatchModeEnabledKey] boolValue] : false;
}

-(void)setWatchModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONWatchModeEnabledKey];
	[self saveWithNotification:WatchModeChangedNotification];
}

-(bool)watchIconOnLeft
{
	return [_data.allKeys containsObject:ONWatchIconLeftKey] ? [[_data objectForKey:ONWatchIconLeftKey] boolValue]: false;
}

-(void)setWatchIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONWatchIconLeftKey];
	[self saveWithNotification:WatchModeChangedNotification];
}

-(bool)wiFiCallingModeEnabled
{
	return [_data.allKeys containsObject:ONWiFiCallingModeEnabledKey] ? [[_data objectForKey:ONWiFiCallingModeEnabledKey] boolValue] : false;
}

-(void)setWiFiCallingModeEnabled:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONWiFiCallingModeEnabledKey];
	[self saveWithNotification:WiFiCallingModeChangedNotification];
}

-(bool)wiFiCallingIconOnLeft
{
	return [_data.allKeys containsObject:ONWiFiCallingIconLeftKey] ? [[_data objectForKey:ONWiFiCallingIconLeftKey] boolValue]: false;
}

-(void)setWiFiCallingIconOnLeft:(bool)value
{
	[_data setObject:NSBool(value) forKey:ONWiFiCallingIconLeftKey];
	[self saveWithNotification:WiFiCallingModeChangedNotification];
}
@end
#pragma mark #endregion
