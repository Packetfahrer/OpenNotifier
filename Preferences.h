#define ONSchemaVersion 1

enum
{
	ONIconAlignmentDefault = 0,
	ONIconAlignmentLeft = 1,
	ONIconAlignmentRight = 2
};
typedef NSUInteger ONIconAlignment;

@interface ONApplicationIcon : NSObject
{
	NSMutableDictionary* _dictionary;
}
@property(assign, nonatomic) ONIconAlignment alignment;
-(NSMutableDictionary*)toDictionary;
@end

@interface ONApplication : NSObject
{
	NSMutableDictionary* _dictionary;
}
@property(retain, nonatomic) NSMutableDictionary* icons;
@property(nonatomic) int useBadges;
@property(nonatomic) int useNotifications;
-(NSMutableDictionary*)toDictionary;
-(bool)containsIcon:(NSString*)iconName;
@end

@interface ONPreferences : NSObject
{
	NSMutableDictionary* _data;
	NSMutableDictionary* _applications;
}
@property(readonly, nonatomic) NSMutableDictionary* applications;
@property(assign) bool enabled;
@property(assign) bool globalUseBadges;
@property(assign) bool globalUseNotifications;
@property(assign) bool iconsOnLeft;
@property(assign) bool silentModeEnabled;
@property(assign) bool silentModeInverted;
@property(assign) bool silentIconOnLeft;
@property(assign) bool vibrateModeEnabled;
@property(assign) bool vibrateModeInverted;
@property(assign) bool vibrateIconOnLeft;
@property(assign) bool tetherModeEnabled;
@property(assign) bool tetherIconOnLeft;
//@property(assign) bool airplaneModeEnabled;
//@property(assign) bool airplaneIconOnLeft;
@property(assign) bool airPlayModeEnabled;
@property(assign) bool airPlayAlwaysEnabled;
@property(assign) bool airPlayIconOnLeft;
@property(assign) bool alarmModeEnabled;
@property(assign) bool alarmModeInverted;
@property(assign) bool alarmIconOnLeft;
@property(assign) bool bluetoothModeEnabled;
@property(assign) bool bluetoothAlwaysEnabled;
@property(assign) bool bluetoothIconOnLeft;
@property(assign) bool lowPowerModeEnabled;
@property(assign) bool lowPowerIconOnLeft;
@property(assign) bool phoneMicMutedModeEnabled;
@property(assign) bool phoneMicMutedIconOnLeft;
@property(assign) bool quietModeEnabled;
@property(assign) bool quietModeInverted;
@property(assign) bool quietIconOnLeft;
@property(assign) bool rotationLockModeEnabled;
@property(assign) bool rotationLockModeInverted;
@property(assign) bool rotationLockIconOnLeft;
@property(assign) bool vPNModeEnabled;
@property(assign) bool vPNIconOnLeft;
@property(assign) bool watchModeEnabled;
@property(assign) bool watchIconOnLeft;
@property(assign) bool wiFiCallingModeEnabled;
@property(assign) bool wiFiCallingIconOnLeft;
@property(assign) bool notificationCenterModeEnabled;
@property(assign) bool notificationCenterIconOnLeft;
@property(assign) bool hideMail;

+(id)sharedInstance;

-(ONApplication*)getApplication:(NSString*)identifer;
-(NSArray*)getBluetoothIdentifers;
-(void)removeApplication:(NSString*)identifer;

-(void)addUseBadges:(BOOL)useBadges forApplication:(NSString*)identifer;
-(void)addUseNotifications:(BOOL)useNotifications forApplication:(NSString*)identifer;
-(id)addIcon:(NSString*)iconName forApplication:(NSString*)identifer;
-(void)removeIcon:(NSString*)iconName fromApplication:(NSString*)identifer;
-(ONApplicationIcon*)getIcon:(NSString*)iconName forApplication:(NSString*)identifer;

-(void)reload;
-(void)save;

@end
