#import <objc/runtime.h>
#import "SpringBoard7/BluetoothManager.h"
#import "Preferences.h"
#import "Settings.h"

@interface PSViewController (OpenNotifier)
-(UINavigationController*)navigationController;
-(void)viewWillAppear:(BOOL)animated;
-(void) viewDidLoad;
-(void) viewWillDisappear:(BOOL)animated;
-(void) setView:(id)view;
-(void) setTitle:(NSString*)title;
- (void)viewDidDisappear:(BOOL)animated;
@end

@interface ONBluetoothController: PSViewController <UITableViewDelegate, UITableViewDataSource> {
	UITableView *_tableView;
	ONPreferences* _preferences;
	NSMutableArray *_enabledDevices;
	NSMutableArray *_disabledDevices;
}
@end

@implementation ONBluetoothController
-(id)init
{
	if (!(self = [super init])) return nil;
	_preferences = ONPreferences.sharedInstance;

	CGRect bounds = [[UIScreen mainScreen] bounds];
	_enabledDevices = [[NSMutableArray alloc] init];
	_disabledDevices = [[NSMutableArray alloc] init];

	_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height) style:UITableViewStylePlain]; //UITableViewStyleGrouped //UITableViewStylePlain
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[_tableView setDataSource:self];
	[_tableView setDelegate:self];
	[_tableView setEditing:NO];
	[_tableView setAllowsSelection:YES];
	[_tableView setAllowsMultipleSelection:NO];
	[_tableView setAllowsSelectionDuringEditing:NO];
	[_tableView setAllowsMultipleSelectionDuringEditing:NO];

	[[objc_getClass("_UITableViewHeaderFooterViewLabel") appearanceWhenContainedIn:[ONBluetoothController class], nil] setTextColor:[UIColor redColor]];

	return self;
}

-(void)dealloc
{
	[_enabledDevices release];
	[_disabledDevices release];
    [_tableView release];
    [super dealloc];
}

-(void)reloadSortOrder
{
	NSSet *pairedDevices = [[objc_getClass("BluetoothManager") sharedInstance] pairedDevices];
	[_enabledDevices removeAllObjects];
	[_disabledDevices removeAllObjects];
	for (BluetoothDevice *device in pairedDevices) {
		NSString *identifier = [NSString stringWithFormat:@"ONBluetooth-%@", device.name];
		ONApplication* app = [_preferences getApplication:identifier];
		if (app && [[app.icons allKeys] count]) {
			[_enabledDevices addObject:device];
		} else {
			[_disabledDevices addObject:device];
		}
	}

	if (_enabledDevices.count) {
		[_enabledDevices sortUsingComparator: ^(BluetoothDevice* a, BluetoothDevice* b) {
			return [a.name caseInsensitiveCompare:b.name];
		}];
	}

	if (_disabledDevices.count) {
		[_disabledDevices sortUsingComparator: ^(BluetoothDevice* a, BluetoothDevice* b) {
			return [a.name caseInsensitiveCompare:b.name];
		}];
	}
}

-(void)viewDidLoad
{
	((UIViewController *)self).title = @"Bluetooth Devices";
	[self setView:_tableView];

	[super viewDidLoad];

	[self reloadSortOrder];
	[_tableView reloadData];
}

-(void) viewWillAppear:(BOOL) animated
{
	if (!_preferences) _preferences = ONPreferences.sharedInstance;
	else [_preferences reload];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.25) * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) { //1.0
		[self reloadSortOrder];
		[_tableView reloadData];
	});

	[super viewWillAppear:animated];
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0) {
		return @"ENABLED DEVICES";
	}

	return @"AVAILABLE DEVICES";
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0) {
		return _enabledDevices.count;
	}

	return _disabledDevices.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ONBluetoothCell"];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"ONBluetoothCell"];
	}

	NSMutableArray *devices = indexPath.section == 0 ? _enabledDevices : _disabledDevices;
	if (indexPath.row < devices.count) {
		BluetoothDevice *device = [devices objectAtIndex:indexPath.row];
		if (device) {
			cell.textLabel.text = device.name;
			if (device.connected) {
				cell.detailTextLabel.text = @"Connected";
			}
		}
	}

	cell.textLabel.textColor = [UIColor blackColor];
	cell.detailTextLabel.textColor = [UIColor grayColor];

	return cell;
}

-(void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
	UITableViewCell* cell = [tableView cellForRowAtIndexPath:indexPath];

	// Need to mimic what PSListController does when it handles didSelectRowAtIndexPath
	// otherwise the child controller won't load
	OpenNotifierIconsController* controller = [[[OpenNotifierIconsController alloc]
												initWithAppName:cell.textLabel.text
												identifier:[[NSString stringWithFormat:@"ONBluetooth-%@", cell.textLabel.text] retain]
												type:2
												] autorelease];

	controller.rootController = self.rootController;
	controller.parentController = self;

	[self pushController:controller];
	[tableView deselectRowAtIndexPath:indexPath animated:true];
}
@end
