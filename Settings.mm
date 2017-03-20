#import "Settings.h"
#import "Preferences.h"
#import <UIKit/UIKit.h>
#import <UIKit/UISearchBar2.h>


#pragma mark #region [ Preferences Keys ]
// #if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_3_2
extern NSString* PSCellClassKey; // cellClass
extern NSString* PSIDKey; // id
extern NSString* PSIsRadioGroupKey; // isRadioGroup
extern NSString* PSRadioGroupCheckedSpecifierKey; // radioGroupCheckedSpecifier
extern NSString* PSDefaultValueKey; // default
extern NSString* PSValueKey; // value
extern NSString* PSKeyNameKey; // value
// #endif

NSString* const ONAlignmentKey = @"alignment";

#pragma mark #endregion

#pragma mark #region [ Variables & Constants ]
NSString* const iconPath = @"/System/Library/Frameworks/UIKit.framework";
static ONPreferences* preferences;
static NSMutableDictionary* cachedIcons;
static UIImage* defaultIcon;
static NSMutableArray* statusIcons;
#pragma mark #endregion

#pragma mark #region [ ALLinkCell ]
@interface ALLinkCell : ALValueCell
@end

@implementation ALLinkCell
-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) return nil;
	self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return self;
}
@end
#pragma mark #endregion

// █████████████████████████████████████████████████████████████████████████████
// █████████████████████████████████████████████████████████████████████████████
// ██
#pragma mark #region [ONIconCell]
@interface ONIconCell : PSTableCell
@end

@implementation ONIconCell

-(UIImage*)getIconNamed:(NSString*)name
{
	UIImage* icon = [cachedIcons objectForKey:name];
	if (icon) return icon; // icon already cached so let's return it

	icon = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/Silver_ON_%@.png", iconPath, name]];
	if (!icon) icon = defaultIcon;

	float maxWidth = 20.0f;
	float maxHeight = 20.0f;

	CGSize size = CGSizeMake(maxWidth, maxHeight);
	CGFloat scale = 1.0f;

	// the scale logic below was taken from
	// http://developer.appcelerator.com/question/133826/detecting-new-ipad-3-dpi-and-retina
	if ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)])
	{
		if ([UIScreen mainScreen].scale > 1.0f) scale = [[UIScreen mainScreen] scale];
		UIGraphicsBeginImageContextWithOptions(size, false, scale);
	}
	else UIGraphicsBeginImageContext(size);

	// Resize image to status bar size and center it
	// make sure the icon fits within the bounds
	CGFloat width = MIN(icon.size.width, maxWidth);
	CGFloat height = MIN(icon.size.height, maxHeight);

	CGFloat left = MAX((maxWidth-width)/2, 0);
	left = left > (maxWidth/2) ? maxWidth-(maxWidth/2) : left;

	CGFloat top = MAX((maxHeight-height)/2, 0);
	top = top > (maxHeight/2) ? maxHeight-(maxHeight/2) : top;

	[icon drawInRect:CGRectMake(left, top, width, height)];
	icon = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	[cachedIcons setObject:icon forKey:name];

	return icon;
}

-(id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)identifier specifier:(PSSpecifier*)specifier;
{
	if (!(self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier specifier:specifier])) return nil;

	NSString* name = [specifier propertyForKey:PSIDKey];

	ONApplication* app = [preferences getApplication:[specifier propertyForKey:ONAppIdentifierKey]];

	bool enabled = app && [app.icons.allKeys containsObject:name];
	if (enabled)
	{
		NSMutableString* details = [NSMutableString stringWithString:@"Enabled"];
		ONApplicationIcon* icon = [app.icons objectForKey:name];
		if (icon)
		{
			switch (icon.alignment)
			{
				case ONIconAlignmentLeft: [details appendString:@" | Force Left"]; break;
				case ONIconAlignmentRight: [details appendString:@" | Force Right"]; break;
			}
		}

		((UITableViewCell *)self).detailTextLabel.text = details;
	}
	return self;
}
@end
#pragma mark #endregion

// █████████████████████████████████████████████████████████████████████████████
// █████████████████████████████████████████████████████████████████████████████
// ██
#pragma mark #region [ OpenNotifierSettingsRootController ]
@implementation OpenNotifierSettingsRootController
-(id)init
{
	if (!(self = [super init])) return nil;
	preferences = ONPreferences.sharedInstance;
	return self;
}

-(void)dealloc
{
	if (cachedIcons) { [cachedIcons release]; cachedIcons = nil; }
	if (statusIcons) { [statusIcons release]; statusIcons = nil; }
	if (defaultIcon) { [defaultIcon release]; defaultIcon = nil; }
	if (preferences) { [preferences release]; preferences = nil; }
	[super dealloc];
}

-(id)specifiers
{
	return _specifiers ? _specifiers : (_specifiers = [[self loadSpecifiersFromPlistName:@"OpenNotifierSettings" target:self] retain]);
}

-(id)readPreferenceValue:(PSSpecifier*)specifier
{
	NSString* key = [specifier propertyForKey:PSIDKey];

	if ([key isEqualToString:ONEnabledKey]) return NSBool(preferences.enabled);
	if ([key isEqualToString:ONGlobalUseBadgesKey]) return NSBool(preferences.globalUseBadges);
	if ([key isEqualToString:ONGlobalUseNotificationsKey]) return NSBool(preferences.globalUseNotifications);
	if ([key isEqualToString:ONIconsLeftKey]) return NSBool(preferences.iconsOnLeft);
	if ([key isEqualToString:ONHideMailKey]) return NSBool(preferences.hideMail);
	if ([key isEqualToString:ONSilentModeEnabledKey]) return NSBool(preferences.silentModeEnabled);
	if ([key isEqualToString:ONSilentModeInvertedKey]) return NSBool(preferences.silentModeInverted);
	if ([key isEqualToString:ONSilentIconLeftKey]) return NSBool(preferences.silentIconOnLeft);
	if ([key isEqualToString:ONVibrateModeEnabledKey]) return NSBool(preferences.vibrateModeEnabled);
	if ([key isEqualToString:ONVibrateModeInvertedKey]) return NSBool(preferences.vibrateModeInverted);
	if ([key isEqualToString:ONVibrateIconLeftKey]) return NSBool(preferences.vibrateIconOnLeft);
	if ([key isEqualToString:ONTetherModeEnabledKey]) return NSBool(preferences.tetherModeEnabled);
	if ([key isEqualToString:ONTetherIconLeftKey]) return NSBool(preferences.tetherIconOnLeft);
//	if ([key isEqualToString:ONAirplaneModeEnabledKey]) return NSBool(preferences.airplaneModeEnabled);
//	if ([key isEqualToString:ONAirplaneIconLeftKey]) return NSBool(preferences.airplaneIconOnLeft);
	if ([key isEqualToString:ONAirPlayModeEnabledKey]) return NSBool(preferences.airPlayModeEnabled);
	if ([key isEqualToString:ONAirPlayAlwaysEnabledKey]) return NSBool(preferences.airPlayAlwaysEnabled);
	if ([key isEqualToString:ONAirPlayIconLeftKey]) return NSBool(preferences.airPlayIconOnLeft);
	if ([key isEqualToString:ONAlarmModeEnabledKey]) return NSBool(preferences.alarmModeEnabled);
	if ([key isEqualToString:ONAlarmModeInvertedKey]) return NSBool(preferences.alarmModeInverted);
	if ([key isEqualToString:ONAlarmIconLeftKey]) return NSBool(preferences.alarmIconOnLeft);
	if ([key isEqualToString:ONBluetoothModeEnabledKey]) return NSBool(preferences.bluetoothModeEnabled);
	if ([key isEqualToString:ONBluetoothAlwaysEnabledKey]) return NSBool(preferences.bluetoothAlwaysEnabled);
	if ([key isEqualToString:ONBluetoothIconLeftKey]) return NSBool(preferences.bluetoothIconOnLeft);
	if ([key isEqualToString:ONQuietModeEnabledKey]) return NSBool(preferences.quietModeEnabled);
	if ([key isEqualToString:ONQuietModeInvertedKey]) return NSBool(preferences.quietModeInverted);
	if ([key isEqualToString:ONQuietIconLeftKey]) return NSBool(preferences.quietIconOnLeft);
	if ([key isEqualToString:ONRotationLockModeEnabledKey]) return NSBool(preferences.rotationLockModeEnabled);
	if ([key isEqualToString:ONRotationLockModeInvertedKey]) return NSBool(preferences.rotationLockModeInverted);
	if ([key isEqualToString:ONRotationLockIconLeftKey]) return NSBool(preferences.rotationLockIconOnLeft);
	if ([key isEqualToString:ONVPNModeEnabledKey]) return NSBool(preferences.vPNModeEnabled);
	if ([key isEqualToString:ONVPNIconLeftKey]) return NSBool(preferences.vPNIconOnLeft);

	return nil;
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier
{
	NSString* key = [specifier propertyForKey:PSIDKey];

	if ([key isEqualToString:ONEnabledKey]) preferences.enabled = [value boolValue];
	if ([key isEqualToString:ONGlobalUseBadgesKey]) preferences.globalUseBadges = [value boolValue];
	if ([key isEqualToString:ONGlobalUseNotificationsKey]) preferences.globalUseNotifications = [value boolValue];
	if ([key isEqualToString:ONIconsLeftKey]) preferences.iconsOnLeft = [value boolValue];
	if ([key isEqualToString:ONHideMailKey]) preferences.hideMail = [value boolValue];
	if ([key isEqualToString:ONSilentModeEnabledKey]) preferences.silentModeEnabled = [value boolValue];
	if ([key isEqualToString:ONSilentModeInvertedKey]) preferences.silentModeInverted = [value boolValue];
	if ([key isEqualToString:ONSilentIconLeftKey]) preferences.silentIconOnLeft = [value boolValue];
	if ([key isEqualToString:ONVibrateModeEnabledKey]) preferences.vibrateModeEnabled = [value boolValue];
	if ([key isEqualToString:ONVibrateModeInvertedKey]) preferences.vibrateModeInverted = [value boolValue];
	if ([key isEqualToString:ONVibrateIconLeftKey]) preferences.vibrateIconOnLeft = [value boolValue];
	if ([key isEqualToString:ONTetherModeEnabledKey]) preferences.tetherModeEnabled = [value boolValue];
	if ([key isEqualToString:ONTetherIconLeftKey]) preferences.tetherIconOnLeft = [value boolValue];
//	if ([key isEqualToString:ONAirplaneModeEnabledKey]) preferences.airplaneModeEnabled = [value boolValue];
//	if ([key isEqualToString:ONAirplaneIconLeftKey]) preferences.airplaneIconOnLeft = [value boolValue];
	if ([key isEqualToString:ONAirPlayModeEnabledKey]) preferences.airPlayModeEnabled = [value boolValue];
	if ([key isEqualToString:ONAirPlayAlwaysEnabledKey]) preferences.airPlayAlwaysEnabled = [value boolValue];
	if ([key isEqualToString:ONAirPlayIconLeftKey]) preferences.airPlayIconOnLeft = [value boolValue];
	if ([key isEqualToString:ONAlarmModeEnabledKey]) preferences.alarmModeEnabled = [value boolValue];
	if ([key isEqualToString:ONAlarmModeInvertedKey]) preferences.alarmModeInverted = [value boolValue];
	if ([key isEqualToString:ONAlarmIconLeftKey]) preferences.alarmIconOnLeft = [value boolValue];
	if ([key isEqualToString:ONBluetoothModeEnabledKey]) preferences.bluetoothModeEnabled = [value boolValue];
	if ([key isEqualToString:ONBluetoothAlwaysEnabledKey]) preferences.bluetoothAlwaysEnabled = [value boolValue];
	if ([key isEqualToString:ONBluetoothIconLeftKey]) preferences.bluetoothIconOnLeft = [value boolValue];
	if ([key isEqualToString:ONQuietModeEnabledKey]) preferences.quietModeEnabled = [value boolValue];
	if ([key isEqualToString:ONQuietModeInvertedKey]) preferences.quietModeInverted = [value boolValue];
	if ([key isEqualToString:ONQuietIconLeftKey]) preferences.quietIconOnLeft = [value boolValue];
	if ([key isEqualToString:ONRotationLockModeEnabledKey]) preferences.rotationLockModeEnabled = [value boolValue];
	if ([key isEqualToString:ONRotationLockModeInvertedKey]) preferences.rotationLockModeInverted = [value boolValue];
	if ([key isEqualToString:ONRotationLockIconLeftKey]) preferences.rotationLockIconOnLeft = [value boolValue];
	if ([key isEqualToString:ONVPNModeEnabledKey]) preferences.vPNModeEnabled = [value boolValue];
	if ([key isEqualToString:ONVPNIconLeftKey]) preferences.vPNIconOnLeft = [value boolValue];
}

@end
#pragma mark #endregion

// █████████████████████████████████████████████████████████████████████████████
// █████████████████████████████████████████████████████████████████████████████
// ██
#pragma mark #region [ OpenNotifierAppsController ]
@implementation OpenNotifierAppsController

#pragma mark #region [ Controller ]
-(void)updateDataSource:(NSString*)searchText
{
	NSNumber *iconSize = [NSNumber numberWithUnsignedInteger:ALApplicationIconSizeSmall];

	NSString* excludeList = @
	"and not displayName in {"
		"'DataActivation', "
		"'DemoApp', "
		"'DDActionsService', "
		"'FacebookAccountMigrationDialog', "
		"'FieldTest', "
		"'iAd', "
		"'iAdOptOut', "
		"'iOS Diagnostics', "
		"'iPodOut', "
		"'kbd', "
		"'MailCompositionService', "
		"'MessagesViewService', "
		"'quicklookd', "
		"'Setup', "
		"'ShoeboxUIService', "
		"'SocialUIService', "
		"'TrustMe', "
		"'WebSheet', "
		"'WebViewService'"
	"} "
	"and not bundleIdentifier in {"
		"'com.apple.ios.StoreKitUIService', "
		"'com.apple.gamecenter.GameCenterUIService'"
	"} ";

	NSString* enabledList = @"";
	for (NSString* identifer in preferences.applications.allKeys)
	{
		ONApplication* app = [preferences getApplication:identifer];
		if (app && [[app.icons allKeys] count])
		{
			enabledList = [enabledList stringByAppendingString:[NSString stringWithFormat:@"'%@',", identifer]];
		}
	}
	enabledList = [enabledList stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
	NSString* filter = (searchText && searchText.length > 0)
					 ? [NSString stringWithFormat:@"displayName beginsWith[cd] '%@' %@", searchText, excludeList]
					 : nil;

	if (filter)
	{
		_dataSource.sectionDescriptors = [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"ALLinkCell", ALSectionDescriptorCellClassNameKey,
				iconSize, ALSectionDescriptorIconSizeKey,
				NSTrue, ALSectionDescriptorSuppressHiddenAppsKey,
				filter, ALSectionDescriptorPredicateKey
			, nil]
		, nil];
	}
	else
	{
		_dataSource.sectionDescriptors = [NSArray arrayWithObjects:
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"Enabled Applications", ALSectionDescriptorTitleKey,
				@"ALLinkCell", ALSectionDescriptorCellClassNameKey,
				iconSize, ALSectionDescriptorIconSizeKey,
				(id)kCFBooleanTrue, ALSectionDescriptorSuppressHiddenAppsKey,
				[NSString stringWithFormat:@"bundleIdentifier in {%@}", enabledList],
				ALSectionDescriptorPredicateKey
			, nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"System Applications", ALSectionDescriptorTitleKey,
				@"ALLinkCell", ALSectionDescriptorCellClassNameKey,
				iconSize, ALSectionDescriptorIconSizeKey,
				(id)kCFBooleanTrue, ALSectionDescriptorSuppressHiddenAppsKey,
				[NSString stringWithFormat:@"path like '/Applications*' and bundleIdentifier matches 'com.apple.*' %@ and not bundleIdentifier in {%@}", excludeList, enabledList],
				ALSectionDescriptorPredicateKey
			, nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"Cydia Applications", ALSectionDescriptorTitleKey,
				@"ALLinkCell", ALSectionDescriptorCellClassNameKey,
				iconSize, ALSectionDescriptorIconSizeKey,
				(id)kCFBooleanTrue, ALSectionDescriptorSuppressHiddenAppsKey,
				[NSString stringWithFormat:@"path like '/Applications*' and not bundleIdentifier matches 'com.apple.*' %@ and not bundleIdentifier in {%@}", excludeList, enabledList],
				ALSectionDescriptorPredicateKey
			, nil],
			[NSDictionary dictionaryWithObjectsAndKeys:
				@"User Applications", ALSectionDescriptorTitleKey,
				@"ALLinkCell", ALSectionDescriptorCellClassNameKey,
				iconSize, ALSectionDescriptorIconSizeKey,
				(id)kCFBooleanTrue, ALSectionDescriptorSuppressHiddenAppsKey,
				[NSString stringWithFormat:@"path contains[cd] 'var/mobile' %@ and not bundleIdentifier in {%@}", excludeList, enabledList],
				ALSectionDescriptorPredicateKey
			, nil]
		, nil];
	}
	[_tableView reloadData];
}

-(id)init
{
	if (!(self = [super init])) return nil;

	CGRect bounds = [[UIScreen mainScreen] bounds];

	_dataSource = [[ALApplicationTableDataSource alloc] init];
	_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height) style:UITableViewStyleGrouped];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.delegate = self;
	_tableView.dataSource = _dataSource;
	_dataSource.tableView = _tableView;
	[self updateDataSource:nil];

	// Search Bar
	_searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
	_searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	if ([_searchBar respondsToSelector:@selector(setUsesEmbeddedAppearance:)])
		[_searchBar setUsesEmbeddedAppearance:true];
	_searchBar.delegate = self;

	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(keyboardWillShowWithNotification:) name:UIKeyboardWillShowNotification object:nil];
	[nc addObserver:self selector:@selector(keyboardWillHideWithNotification:) name:UIKeyboardWillHideNotification object:nil];

	return self;
}

-(void)viewDidLoad
{
	((UIViewController *)self).title = @"Applications";

	UIEdgeInsets insets = UIEdgeInsetsMake(44.0f, 0, 0, 0);
	_tableView.contentInset = insets;
	_tableView.contentOffset = CGPointMake(0, 12.0f);
	insets.top = 0;
	_tableView.scrollIndicatorInsets = insets;
	_searchBar.frame = CGRectMake(0, -44.0f, _tableView.bounds.size.width, 44.0f);

	[_tableView addSubview:_searchBar];
	[self.view addSubview:_tableView];
	[super viewDidLoad];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[_searchBar resignFirstResponder];
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	_searchBar.delegate = nil;
	_tableView.delegate = nil;
	[_searchBar release];
	[_dataSource release]; // tableview will be released by dataSource
	[super dealloc];
}

-(void)keyboardWillShowWithNotification:(NSNotification*)notification
{
	[UIView beginAnimations:nil context:nil];
	NSDictionary* userInfo = notification.userInfo;
	[UIView setAnimationDuration:[[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
	[UIView setAnimationCurve:(UIViewAnimationCurve)[[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue]];
	CGRect keyboardFrame = CGRectZero;
	[[userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardFrame];
	UIEdgeInsets insets = UIEdgeInsetsMake(110.0f, 0, keyboardFrame.size.height, 0);
	_tableView.contentInset = insets;
	insets.top = 0;
	_tableView.scrollIndicatorInsets = insets;
	[UIView commitAnimations];
}

- (void)keyboardWillHideWithNotification:(NSNotification *)notification
{
	[UIView beginAnimations:nil context:nil];
	NSDictionary* userInfo = notification.userInfo;
	[UIView setAnimationDuration:[[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
	[UIView setAnimationCurve:(UIViewAnimationCurve)[[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue]];
	UIEdgeInsets insets = UIEdgeInsetsMake(110.0f, 0, 0, 0);
	_tableView.contentInset = insets;
	insets.top = 0.0f;
	_tableView.scrollIndicatorInsets = insets;
	[UIView commitAnimations];
}
#pragma mark #endregion [ Controller ]

#pragma mark #region [ UISearchBar ]

-(void)searchBarTextDidBeginEditing:(UISearchBar*)searchBar
{
	[_searchBar setShowsCancelButton:true animated:true];
}

-(void)searchBarTextDidEndEditing:(UISearchBar*)searchBar
{
	[_searchBar setShowsCancelButton:false animated:true];
}

-(void)searchBarSearchButtonClicked:(UISearchBar*)searchBar
{
	[_searchBar resignFirstResponder];
}

-(void)searchBarCancelButtonClicked:(UISearchBar*)searchBar
{
	_searchBar.text = nil;
	[self updateDataSource:nil];
	[_searchBar resignFirstResponder];
	_tableView.contentOffset = CGPointMake(0, -44.0f);
}

-(void)searchBar:(UISearchBar*)searchBar textDidChange:(NSString*)searchText
{
	[self updateDataSource:searchText];
}

#pragma mark #endregion [ UISearchBar ]

#pragma mark #region [ UITableViewDelegate ]
-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];

	// Need to mimic what PSListController does when it handles didSelectRowAtIndexPath
	// otherwise the child controller won't load
	OpenNotifierIconsController* controller = [[[OpenNotifierIconsController alloc]
		initWithAppName:cell.textLabel.text
		identifier:[_dataSource displayIdentifierForIndexPath:indexPath]
		type:0
		] autorelease];

	controller.rootController = self.rootController;
	controller.parentController = self;

	[self pushController:controller];
	[tableView deselectRowAtIndexPath:indexPath animated:true];
}
#pragma mark #endregion [ UITableViewDelegate ]

@end
#pragma mark #endregion [ OpenNotifierAppsController ]

// █████████████████████████████████████████████████████████████████████████████
// █████████████████████████████████████████████████████████████████████████████
// ██
#pragma mark #region [ OpenNotifierIconsController ]
@implementation OpenNotifierIconsController

#pragma mark #region [ Controller ]
-(id)initWithAppName:(NSString*)appName identifier:(NSString*)identifier type:(int)iconType
{
	_appName = appName;
	_identifier = identifier;
	_iconType = iconType;
	return [self init];
}

-(id)init
{
	if ((self = [super init]) == nil) return nil;

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	if (!defaultIcon) defaultIcon = [[[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeSmall forDisplayIdentifier:@"com.apple.WebSheet"] retain];
	if (!cachedIcons) cachedIcons = [[NSMutableDictionary alloc] init];
	if (!statusIcons)
	{
		statusIcons = [[NSMutableArray alloc] init];
		NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:SilverIconRegexPattern
			options:NSRegularExpressionCaseInsensitive error:nil];

		for (NSString* path in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:iconPath error:nil])
		{
			NSTextCheckingResult* match = [regex firstMatchInString:path options:0 range:NSMakeRange(0, path.length)];
			if (!match) continue;
			NSString* name = [path substringWithRange:[match rangeAtIndex:1]];
			if (![statusIcons containsObject:name]) [statusIcons addObject:name];
		}
	}

	_application = [preferences.applications objectForKey:_identifier];

	if (statusIcons)
	{
		[statusIcons sortUsingComparator: ^(NSString* a, NSString* b) {
			bool e1 = _application && [_application.icons.allKeys containsObject:a];
			bool e2 = _application && [_application.icons.allKeys containsObject:b];

			NSString* aa = a;
			NSString* bb = b;

			if ([aa hasPrefix:@"Count_"]) {
				aa = [a substringFromIndex:6];
			}
			if ([bb hasPrefix:@"Count_"]) {
				bb = [b substringFromIndex:6];
			}

			if (e1 && e2) {
				return [aa caseInsensitiveCompare:bb];
			} else if (e1) {
				return (NSComparisonResult)NSOrderedAscending;
			} else if (e2) {
				return (NSComparisonResult)NSOrderedDescending;
			}
			return [aa caseInsensitiveCompare:bb];
		}];
	}

	[pool drain];
	return self;
}

-(void)viewDidLoad
{
	[super viewDidLoad];
	[self setTitle:_appName];
}

#pragma mark #endregion

#pragma mark #region [ UITableViewDatasource ]


-(id)readPreferenceValue:(PSSpecifier*)specifier
{
	NSString* key = specifier.identifier;
	ONApplication* app = [preferences getApplication:[specifier propertyForKey:ONAppIdentifierKey]];

	return NSBool(app && app.useNotifications == 1);
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier
{
	NSString* key = specifier.identifier;
	NSString* identifier = [specifier propertyForKey:ONAppIdentifierKey];
	[preferences addUseNotifications:[value boolValue] forApplication:identifier];
	[self reloadSpecifiers];
	[preferences save];
}

-(id)specifiers
{
	if (_specifiers) return _specifiers;

	_specifiers = [[NSMutableArray alloc] init];

	if (_iconType == 0) {
		PSSpecifier* useNotifications = [PSSpecifier preferenceSpecifierNamed:@"Use Notification Center" target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
																detail:nil cell:PSSwitchCell edit:nil];
		[useNotifications setProperty:ONUseNotificationsKey forKey:PSIDKey];
		[useNotifications setProperty:_identifier forKey:ONAppIdentifierKey];
		[_specifiers addObject:useNotifications];
	}

	for (id name in _application.icons) {
		if (![statusIcons containsObject:name])
		{
			NSString* nameCount = name;
			if ([name hasPrefix:@"Count_"])
			{
				nameCount = [name substringFromIndex:6];
			}
			PSSpecifier* specifier = [PSSpecifier preferenceSpecifierNamed:nameCount target:self set:nil get:nil
																	detail:[OpenNotifierIconSettingsController class] cell:PSLinkListCell edit:nil];

			[specifier setProperty:name forKey:PSIDKey];
			[specifier setProperty:[ONIconCell class] forKey:PSCellClassKey];
			[specifier setProperty:_identifier forKey:ONAppIdentifierKey];

			[_specifiers addObject:specifier];
		}
	}

	for (NSString* name in statusIcons)
	{
		NSString* nameCount = name;
		if ([name hasPrefix:@"Count_"])
		{
			nameCount = [name substringFromIndex:6];
		}
		PSSpecifier* specifier = [PSSpecifier preferenceSpecifierNamed:nameCount target:self set:nil get:nil
			detail:[OpenNotifierIconSettingsController class] cell:PSLinkListCell edit:nil];

		[specifier setProperty:name forKey:PSIDKey];
		[specifier setProperty:[ONIconCell class] forKey:PSCellClassKey];
		[specifier setProperty:_identifier forKey:ONAppIdentifierKey];

		[_specifiers addObject:specifier];
	}

	return _specifiers;
}

-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	/* iOS 6 no longer supports setIcon on PSTableCell so logic was moved here to fix it */
	ONIconCell* cell = (ONIconCell*)[super tableView:tableView cellForRowAtIndexPath:indexPath];
	if ([indexPath indexAtPosition:1] > 0 || _iconType != 0) {
		((UITableViewCell *)cell).imageView.image = [cell getIconNamed:[((PSTableCell *)cell).specifier propertyForKey:PSIDKey]];
	}

	return (UITableViewCell *)cell;
}

#pragma mark #endregion


@end
#pragma mark #endregion

// █████████████████████████████████████████████████████████████████████████████
// █████████████████████████████████████████████████████████████████████████████
// ██
#pragma mark #region [ OpenNotifierIconSettingsController ]
@implementation OpenNotifierIconSettingsController

-(id)readPreferenceValue:(PSSpecifier*)specifier
{
	NSString* key = specifier.identifier;
	ONApplication* app = [preferences getApplication:[self.specifier propertyForKey:ONAppIdentifierKey]];
	if ([key isEqualToString:ONEnabledKey])
	{
		return NSBool(app && [app containsIcon:[self.specifier propertyForKey:PSIDKey]]);
	}
	else if ([key isEqualToString:ONIconAlignmentKey])
	{
		ONApplicationIcon* icon = [app.icons objectForKey:[self.specifier propertyForKey:PSIDKey]];
		ONIconAlignment alignment = icon ? icon.alignment : ONIconAlignmentDefault;
		return [NSNumber numberWithUnsignedInteger:alignment];
	}

	return nil;
}

-(void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier
{
	NSString* key = specifier.identifier;
	NSString* identifier = [self.specifier propertyForKey:ONAppIdentifierKey];
	NSString* iconName = [self.specifier propertyForKey:PSIDKey];

	if ([key isEqualToString:ONEnabledKey])
	{
		if (![value boolValue]) [preferences removeIcon:iconName fromApplication:identifier];
		else [preferences addIcon:iconName forApplication:identifier];
		[self reloadSpecifiers];
	}
	else if ([key isEqualToString:ONIconAlignmentKey])
	{
		ONApplicationIcon* icon = [preferences getIcon:iconName forApplication:identifier];
		if (icon) icon.alignment = [value intValue];
	}

	[preferences save];
	[(PSListController*)self.parentController reloadSpecifier:self.specifier animated:false];
}

-(void)processIconAlignmentGroup:(bool)enabled
{
	// Alignment Radio Group
	if (enabled)
	{
		PSSpecifier* groupSpecifier = [PSSpecifier groupSpecifierWithName:@"Alignment"];
		[groupSpecifier setProperty:ONIconAlignmentKey forKey:PSKeyNameKey];
		[groupSpecifier setProperty:NSTrue forKey:PSIsRadioGroupKey];
		[_specifiers addObject:groupSpecifier];

		NSNumber* alignment = [self readPreferenceValue:groupSpecifier];

		for (uint i = 0; i < 3; i++)
		{
			NSString* title;
			switch (i)
			{
				case 1: title = @"Force Left"; break;
				case 2: title = @"Force Right"; break;
				default: title = @"Default"; break;
			}

			PSSpecifier* specifier = [PSSpecifier preferenceSpecifierNamed:title target:self set:nil get:nil detail:nil cell:PSListItemCell edit:nil];
			[specifier setProperty:ONIconAlignmentKey forKey:PSKeyNameKey];

			NSNumber* value = [NSNumber numberWithUnsignedInteger:i];
			[specifier setProperty:value forKey:PSValueKey];

			if ([value isEqual:alignment]) [groupSpecifier setProperty:specifier forKey:PSRadioGroupCheckedSpecifierKey];

			[_specifiers addObject:specifier];
		}
	}
}

-(id)specifiers
{
	if (_specifiers) return _specifiers;

	ONApplication* app = [preferences getApplication:[self.specifier propertyForKey:ONAppIdentifierKey]];
	_specifiers = [[NSMutableArray alloc] init];

	PSSpecifier* specifier;

	// Enabled Switch
	specifier = [PSSpecifier preferenceSpecifierNamed:@"Enabled" target:self
		set:@selector(setPreferenceValue:specifier:)
		get:@selector(readPreferenceValue:)
		detail:nil cell:PSSwitchCell edit:nil
	];
	[specifier setProperty:ONEnabledKey forKey:PSIDKey];
	[_specifiers addObject:specifier];

	bool enabled = app && [app containsIcon:[self.specifier propertyForKey:PSIDKey]];
	[self processIconAlignmentGroup:enabled];

	return _specifiers;
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];

	PSListController *cell = (PSListController *)self;
	NSUInteger i = (NSUInteger)[cell indexForIndexPath:indexPath];
	PSSpecifier* specifier = [self specifierAtIndex:i];
	if (specifier && [[specifier propertyForKey:PSKeyNameKey] isEqualToString:ONIconAlignmentKey])
	{
		[self setPreferenceValue:[specifier propertyForKey:PSValueKey] specifier:[self specifierForID:ONIconAlignmentKey]];
	}
}

@end
#pragma mark #endregion


@implementation SystemIconsController
@synthesize _systemIcons;

-(NSString*)title
{
	return @"System Icons";
}

-(UIView*)view
{
	return _logoTable;
}

+(void)load
{
	NSAutoreleasePool *pool([[NSAutoreleasePool alloc] init]);
	[pool release];
}

-(id)initForContentSize:(CGSize)size
{
	if ((self = [super init]) != nil)
	{
		if (!self._systemIcons)
		{
			self._systemIcons = [NSMutableArray arrayWithObjects:@"AirPlay Icon", @"Alarm Icon", @"Bluetooth Icon", @"Do Not Disturb Icon", @"Rotation Lock Icon", @"Silent Mode Icon", @"Tether Icon", @"Vibrate Mode Icon", @"VPN Icon", nil];
		}

		_logoTable = [[UITableView alloc] initWithFrame: (CGRect){{0,0}, size} style:UITableViewStyleGrouped];
		[_logoTable setDataSource:self];
		[_logoTable setDelegate:self];
		if ([self respondsToSelector:@selector(setView:)])
		{
			[self setView:_logoTable];
		}

	}
	return self;
}

-(void)reloadSpecifiers
{
	[_logoTable reloadData];
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return @"System Icons";
}

-(void)viewWillAppear:(BOOL)animated
{
	[_logoTable reloadData];
}

-(void)viewDidUnload
{
	[super viewDidUnload];
}

-(void)dealloc
{
	[super dealloc];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self._systemIcons.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{

	static NSString *CellIdentifier = [self._systemIcons objectAtIndex:indexPath.row];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	if (cell == nil)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	}
	cell.textLabel.text = [self._systemIcons objectAtIndex:indexPath.row];

	return cell;
}

-(NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	return nil;
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];

	// Need to mimic what PSListController does when it handles didSelectRowAtIndexPath
	// otherwise the child controller won't load
	OpenNotifierIconsController* controller = [[[OpenNotifierIconsController alloc]
												initWithAppName:cell.textLabel.text
												identifier:cell.textLabel.text
												type:1
												] autorelease];

	controller.rootController = self.rootController;
	controller.parentController = self;

	[self pushController:controller];
	[tableView deselectRowAtIndexPath:indexPath animated:true];
}
@end
