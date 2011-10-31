#import <SpringBoard5/SpringBoard.h>
#import "LSStatusBarItem.h"

static NSDictionary* openNotifierPrefs;
static NSMutableDictionary* statusBarItems = [[NSMutableDictionary alloc] init];
static NSMutableDictionary* currentIconSetList = [[NSMutableDictionary alloc] init];

%hook SpringBoard
-(id)init
{
	openNotifierPrefs = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.n00neimp0rtant.opennotifier.plist"];
	NSMutableArray* imageNames = [NSMutableArray arrayWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/System/Library/Frameworks/UIKit.framework/" error:nil]];
	NSMutableSet* filteredNames = [NSMutableSet set];
	for(NSString* name in imageNames)
	{
		if([name hasPrefix:@"Silver_ON_"] || [name hasPrefix:@"Black_ON_"])
		{
			NSMutableString* temp = [NSMutableString stringWithString:name];
			[temp replaceOccurrencesOfString:@"Silver_ON_" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [temp length])];
			[temp replaceOccurrencesOfString:@"Black_ON_" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [temp length])];
			[temp replaceOccurrencesOfString:@".png" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [temp length])];
			[temp replaceOccurrencesOfString:@"@2x" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [temp length])];
			[filteredNames addObject:[NSString stringWithString:temp]];
		}
	}
	for(NSString* name in filteredNames)
	{
		[currentIconSetList setObject:[NSMutableSet setWithCapacity:1] forKey:name];
	}
	return %orig;
}
%end

%hook SBApplicationIcon
-(void)setBadge:(id)badge
{
	%orig;
	NSArray* iconList = [[openNotifierPrefs objectForKey:@"apps"] objectForKey:[self leafIdentifier]];
	if(badge == 0 || badge == nil || [badge isEqual:@"0"] || [badge isEqual:[NSNumber numberWithInt:0]])
	{
		for(NSString* name in iconList)
		{
			[[currentIconSetList objectForKey:name] removeObject:[self leafIdentifier]];
			if([[currentIconSetList objectForKey:name] count] == 0)
				[statusBarItems removeObjectForKey:name];
		}
	}
	else
	{
		for(NSString* name in iconList)
		{
			LSStatusBarItem* statusBarItem = [[[objc_getClass("LSStatusBarItem") alloc] initWithIdentifier:[NSString stringWithFormat:@"opennotifier.%@", name] alignment:StatusBarAlignmentLeft] autorelease];;
			[statusBarItem setImageName:[NSString stringWithFormat:@"ON_%@", name]];
			[statusBarItems setObject:statusBarItem forKey:name];
			
			[[currentIconSetList objectForKey:name] addObject:[self leafIdentifier]];
		}
	}
}
%end