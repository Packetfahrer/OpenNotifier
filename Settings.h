#import "Tweak.h"
#import "Preferences.h"
#import <Preferences/Preferences.h>
#import <AppList/AppList.h>

@interface OpenNotifierSettingsRootController: PSListController
@end

@interface OpenNotifierAppsController : PSViewController <UITableViewDelegate, UISearchBarDelegate>
{
	UITableView* _tableView;
	ALApplicationTableDataSource* _dataSource;
	UISearchBar* _searchBar;
}
@end

@interface OpenNotifierIconsController : PSListController
{
	NSString* _appName;
	NSString* _identifier;
	ONApplication* _application;
	int _iconType;
}
-(id)initWithAppName:(NSString*)appName identifier:(NSString*)identifier type:(int)iconType; //0 = app, 1 = icon
@end

@interface OpenNotifierIconSettingsController : PSListController
@end

@interface SystemIconsController: PSViewController <UITableViewDelegate, UITableViewDataSource> {
	NSMutableArray *_systemIcons;
	UITableView *_logoTable;
}
@property(nonatomic, retain) NSMutableArray *_systemIcons;
@end
