
#import <UIKit/UIKit.h>


@interface ClientListViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource>

@property(nonatomic, weak)IBOutlet UITableView *myTableView;
@property(nonatomic, copy)NSArray *resultsArray;

@end
