#import <Foundation/NSDistributedNotificationCenter.h>
#import <Preferences/Preferences.h>

#import "Tweak.h"

static NSString *_plistfile = @"/var/mobile/Library/Preferences/net.tateu.opennotifier.plist";

@interface PSViewController (OpenNotifier)
-(UINavigationController*)navigationController;
-(void)viewWillAppear:(BOOL)animated;
-(void) viewDidLoad;
-(void) viewWillDisappear:(BOOL)animated;
-(void) setView:(id)view;
-(void) setTitle:(NSString*)title;
- (void)viewDidDisappear:(BOOL)animated;
@end

@interface ONProfileController: PSViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UILongPressGestureRecognizerDelegate, UIDocumentInteractionControllerDelegate> {
	NSMutableDictionary *_settings;
	NSMutableArray *profiles;
	UITableView *_tableView;
	UIDocumentInteractionController *documentController;
}
@end

@implementation ONProfileController
-(id)init
{
	if (!(self = [super init])) return nil;

	[self reloadSortOrder];
	CGRect bounds = [[UIScreen mainScreen] bounds];

	_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height) style:UITableViewStylePlain]; //UITableViewStyleGrouped //UITableViewStylePlain
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[_tableView setDataSource:self];
	[_tableView setDelegate:self];
	[_tableView setEditing:NO];
	[_tableView setAllowsSelection:YES];
	[_tableView setAllowsMultipleSelection:NO];
	[_tableView setAllowsSelectionDuringEditing:NO];
	[_tableView setAllowsMultipleSelectionDuringEditing:NO];

	[[objc_getClass("_UITableViewHeaderFooterViewLabel") appearanceWhenContainedIn:[ONProfileController class], nil] setTextColor:[UIColor redColor]];

	return self;
}

-(void)dealloc
{
	if (_settings) {
		[_settings release];
		_settings = nil;
	}

	if (profiles) {
		[profiles release];
		profiles = nil;
	}

	[_tableView release];
	[super dealloc];
}

-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
	CGPoint p = [gestureRecognizer locationInView:_tableView];

	NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:p];
	if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
		NSString *sourceName = nil;
		NSString *sourceFile = nil;
		if (indexPath.section == 0 && indexPath.row == 0) {
			sourceName = @"net.tateu.opennotifier.plist";
		} else if (indexPath.section == 1) {
			UITableViewCell *cell = [_tableView cellForRowAtIndexPath:indexPath];
			sourceName = [NSString stringWithFormat:@"net.tateu.opennotifier_%@.plist", cell.textLabel.text];
		}

		if (!sourceName) {
			return;
		}

		sourceFile = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@", sourceName];

		NSURL *tempUrl = [NSURL fileURLWithPath:sourceFile];

		documentController = [UIDocumentInteractionController interactionControllerWithURL:tempUrl];

		documentController.delegate = self;
		BOOL success = [documentController presentOptionsMenuFromRect:self.view.bounds inView:self.view animated:YES];
		if (!success) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"ERROR" message:@"Cannot Open File: There are no Apps installed on your device that can open this file." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles: nil];
			[alert show];
			[alert release];
		}
	}
}

-(void)viewDidLoad
{
	((UIViewController *)self).title = @"Profiles";
	[self setView:_tableView];

	UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
	gesture.minimumPressDuration = 1.0;
	gesture.delegate = self;
	[_tableView addGestureRecognizer:gesture];
	[gesture release];

	NSString *message = @"• Tap on the Current profile to save it.\n• Tap on an Available profile to load it.\n• Tap and hold on a profile to share it (send via email, Copy to DropBox, etc.).\n\n• Save to DropBox does not work. You have to use Open In DropBox. This appears to be an iOS/DropBox issue with the plist file extenstion.";

	NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:message];
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	[paragraphStyle setParagraphSpacing:1.5];
	[paragraphStyle setParagraphSpacingBefore:0];
	[paragraphStyle setHeadIndent:11.f]; // Set the indent for given bullet character and size font

	NSTextTab *tab = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft location:15 options:nil];
	[paragraphStyle setTabStops:@[tab]];
	[paragraphStyle setDefaultTabInterval:15];
	[tab release];

	[attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor darkGrayColor] range:NSMakeRange(0, message.length)];
	[attributedString addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:13] range:NSMakeRange(0, message.length)];
	[attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, message.length)];

	UITextView *_footerView = [[[UITextView alloc] initWithFrame:CGRectMake(0, 0, _tableView.frame.size.width, 44)] autorelease];
	[_footerView setEditable:NO];
	_footerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_footerView.clipsToBounds = YES;
	_footerView.textAlignment = NSTextAlignmentLeft;
	[_footerView setBackgroundColor:[UIColor colorWithRed:240.0/255.0 green:240.0/255.0 blue:240.0/255.0 alpha:1.0]];
	[_footerView setAttributedText:attributedString];

	CGSize size = [_footerView sizeThatFits:CGSizeMake(_tableView.frame.size.width, FLT_MAX)];
	_footerView.frame = CGRectMake(0, 12, _tableView.frame.size.width, size.height + 0);
	_footerView.scrollEnabled = NO;

	UIView *sectionFooterView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, _tableView.frame.size.width, size.height + 24)] autorelease];
	sectionFooterView.backgroundColor = [UIColor clearColor]; //[UIColor colorWithRed:240.0/255.0 green:240.0/255.0 blue:240.0/255.0 alpha:1.0];
	sectionFooterView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	UIView *borderView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, _tableView.frame.size.width, size.height + 24)] autorelease];
	borderView.backgroundColor = [UIColor colorWithRed:240.0/255.0 green:240.0/255.0 blue:240.0/255.0 alpha:1.0];
	borderView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	[sectionFooterView addSubview:borderView];
	[sectionFooterView addSubview:_footerView];
	sectionFooterView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	_tableView.tableFooterView = sectionFooterView;

	[paragraphStyle release];
	[attributedString release];

	[super viewDidLoad];
}

-(void) viewWillAppear:(BOOL) animated
{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.25) * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		[self reloadSortOrder];
		[_tableView reloadData];
	});

	[super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0) {
		return @"CURRENT";
	}
	if (section == 1) {
		return @"AVAILABLE";
	}

	return @"Unknown";
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSInteger count = 0;
	if (section == 0) {
		count = 1;
	} else if (section == 1) {
		count = [profiles count];
	}

	return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ONProfileCell"];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ONProfileCell"];
	}

	if (indexPath.section == 0) {
		if ([_settings objectForKey:@"profileName"]) {
			if ([[_settings objectForKey:@"profileSaved"] boolValue]) {
				cell.textLabel.text = [_settings objectForKey:@"profileName"];
			} else {
				cell.textLabel.text = [NSString stringWithFormat:@"%@ (Unsaved)", [_settings objectForKey:@"profileName"]];
			}
		} else {
			cell.textLabel.text = @"Unsaved";
		}

		cell.detailTextLabel.text = [NSString stringWithFormat:@"Last Saved: %@", [_settings objectForKey:@"lastModified"] ?: @""];
	} else {
		NSDictionary *data = [profiles objectAtIndex:indexPath.row];
		cell.textLabel.text = [data objectForKey:@"profileName"];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"Last Saved: %@", [data objectForKey:@"lastModified"]];
	}

	cell.textLabel.textColor = [UIColor blackColor];
	cell.detailTextLabel.textColor = [UIColor grayColor];

	return cell;
}

////////////////////////////////////////
//
-(UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleDelete; //UITableViewCellEditingStyleDelete UITableViewCellEditingStyleNone
}
-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

-(BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

-(BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}
//
////////////////////////////////////////

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		if (indexPath.section == 0) {
			UIAlertView *alert = [[UIAlertView alloc] init];
			[alert setTitle:@"Are you sure you want to reset your current profile?"];
			[alert setMessage:@"If your current profile is Unsaved, it will be lost!!!"];
			[alert setTag:5652];
			[alert setDelegate:self];
			[alert addButtonWithTitle:@"Cancel"];
			[alert addButtonWithTitle:@"Reset"];
			alert.cancelButtonIndex = 0;

			[alert show];
			[alert release];
		} else {
			UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

			NSString *sourceFile = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/net.tateu.opennotifier_%@.plist", cell.textLabel.text];
			NSError *error = nil;
			BOOL success = [[NSFileManager defaultManager] removeItemAtPath:sourceFile error:&error];
			if (success) {
				[self reloadSortOrder];
			} else {
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error, Could not delete profile" message:[error description] delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
		}
	}

	[_tableView reloadData];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if ([alertView tag] == 5651 && buttonIndex == 1) {
		// Overwrite existing profile
		NSString *profileName = alertView.accessibilityValue;
		NSString *destination = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/net.tateu.opennotifier_%@.plist", profileName];
		[_settings setObject:profileName forKey:@"profileName"];
		[_settings setObject:@(YES) forKey:@"profileSaved"];
		NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
		[formatter setDateStyle:NSDateFormatterShortStyle];
		[formatter setTimeStyle:NSDateFormatterMediumStyle]; // NSDateFormatterShortStyle NSDateFormatterMediumStyle
		[_settings setObject:[formatter stringFromDate:[NSDate date]] forKey:@"lastModified"];
		[formatter release];
		[_settings writeToFile:destination atomically:YES];
		[_settings writeToFile:_plistfile atomically:YES];

		[self reloadSortOrder];
		[_tableView reloadData];
	} if ([alertView tag] == 5652 && buttonIndex == 1) {
		// Reset Current Profile
		if (_settings) {
			[_settings release];
			_settings = nil;
		}
		_settings = [[[NSMutableDictionary alloc] init] retain];
		[_settings writeToFile:_plistfile atomically:YES];
		PostNotification((CFStringRef)IconSettingsChangedNotification);

		[self reloadSortOrder];
		[_tableView reloadData];
	} else if ([alertView tag] == 5653 && buttonIndex == 1) {
		// Save
		NSString *profileName = [alertView textFieldAtIndex:0].text;
		NSString *destinationFile = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/net.tateu.opennotifier_%@.plist", profileName];

		if (!profileName || [profileName isEqualToString:@""]) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error, You cannot save a profile with no name" message:nil delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
			[alert show];
			[alert release];
			return;
		}

		if ([NSFileManager.defaultManager fileExistsAtPath:destinationFile]) {
			UIAlertView *alert = [[UIAlertView alloc] init];
			[alert setTitle:@"That profile exists!"];
			[alert setMessage:@"Would you like to overwrite it?"];
			[alert setTag:5651];
			[alert setDelegate:self];
			[alert addButtonWithTitle:@"No"];
			[alert addButtonWithTitle:@"Yes"];
			alert.cancelButtonIndex = 0;

			[alert setAccessibilityValue:profileName];
			[alert show];
			[alert release];
		} else {
			[_settings setObject:profileName forKey:@"profileName"];
			[_settings setObject:@(YES) forKey:@"profileSaved"];
			NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			[formatter setDateStyle:NSDateFormatterShortStyle];
			[formatter setTimeStyle:NSDateFormatterMediumStyle]; // NSDateFormatterShortStyle NSDateFormatterMediumStyle
			[_settings setObject:[formatter stringFromDate:[NSDate date]] forKey:@"lastModified"];
			[_settings writeToFile:destinationFile atomically:YES];
			[_settings writeToFile:_plistfile atomically:YES];

			[self reloadSortOrder];
			[_tableView reloadData];
		}
	} else if ([alertView tag] == 5654 && buttonIndex == 1) {
		// Load
		NSString *destination = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/net.tateu.opennotifier_%@.plist", alertView.accessibilityValue];
		if (_settings) {
			[_settings release];
			_settings = nil;
		}
		_settings = [NSMutableDictionary dictionaryWithContentsOfFile:destination];

		if (!_settings) {
			_settings = [NSMutableDictionary dictionaryWithContentsOfFile:_plistfile] ?: [NSMutableDictionary dictionary];
			[_settings retain];
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error, Could not load profile" message:nil delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
			[alert show];
			[alert release];
		} else {
			[_settings retain];
			[_settings writeToFile:_plistfile atomically:YES];

			PostNotification((CFStringRef)IconSettingsChangedNotification);
			[self reloadSortOrder];
			[_tableView reloadData];
		}
	}
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	if (indexPath.section == 0 && indexPath.row == 0) {
		// Save
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Save" message:@"Please enter a Profile Name" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
		[alert textFieldAtIndex:0].delegate = self;
		if ([_settings objectForKey:@"profileName"]) {
			[alert textFieldAtIndex:0].text = [_settings objectForKey:@"profileName"];
		}
		[alert setTag:5653];
		[alert show];
		[alert release];
	} else if (indexPath.section == 1) {
		UIAlertView *alert = [[UIAlertView alloc] init];
		[alert setTitle:@"Are you sure you want to load the selected profile?"];
		[alert setMessage:@"If your current profile is Unsaved, it will be lost!!!"];
		[alert setTag:5654];
		[alert setDelegate:self];
		[alert addButtonWithTitle:@"Cancel"];
		[alert addButtonWithTitle:@"Yes"];
		alert.cancelButtonIndex = 0;

		UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
		[alert setAccessibilityValue:cell.textLabel.text];
		[alert show];
		[alert release];
	}

	[tableView deselectRowAtIndexPath:indexPath animated:true];
}

-(void)reloadSortOrder
{
	if (_settings) {
		[_settings release];
		_settings = nil;
	}

	_settings = [NSMutableDictionary dictionaryWithContentsOfFile:_plistfile] ?: [NSMutableDictionary dictionary];
	[_settings retain];

	if (profiles) {
		[profiles release];
		profiles = nil;
	}
	profiles = [[NSMutableArray alloc] init];
	NSString *preferenceDirectory = @"/var/mobile/Library/Preferences/";

	NSError *error = nil;
	NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:preferenceDirectory error:&error];

	NSString *match = @"net.tateu.opennotifier_*.plist";
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF like %@", match];
	for (NSString *fileName in [directoryContents filteredArrayUsingPredicate:predicate]) {
		NSString *plistFile = [preferenceDirectory stringByAppendingString:fileName];
		NSDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:plistFile];

		// (strlen(net.tateu.tweakname) + 1) = 20 and (strlen(net.tateu.tweakname.plist) + 1) = 26, NSMakeRange(20, [fileName length] - 26)];
		NSString *profileName = [fileName substringWithRange:NSMakeRange(23, [fileName length] - 29)];
		NSString *lastModified = (settings && [settings objectForKey:@"lastModified"]) ? [settings objectForKey:@"lastModified"] : @"";
		NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:profileName, @"profileName", lastModified, @"lastModified", nil];
		[profiles addObject:data];
	}
}
@end
