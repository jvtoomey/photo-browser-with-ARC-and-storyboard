
#import "ClientListViewController.h"
#import "Client.h"
#import "PhotoViewController.h"

@interface ClientListViewController ()

@end

@implementation ClientListViewController

-(void)viewWillAppear:(BOOL)animated
{
    [self queryDatabase];
    [[self myTableView] reloadData];
}

- (void)queryDatabase
{
    //Add some sample records. In an actual app, you'd read from
    //the sqlite database here.
    
    NSMutableArray *allRecs = [[NSMutableArray alloc] init];
    
    for (int x=1;x<4;x++)
    {
        NSString *clientID = [NSString stringWithFormat:@"%d", x];

        NSMutableString *lastName = [[NSMutableString alloc] init];
        [lastName appendString:@"last"];
        [lastName appendString:clientID];
        
        NSMutableString *firstName = [[NSMutableString alloc] init];
        [firstName appendString:@"first"];
        [firstName appendString:clientID];
        
        Client *rec = [[Client alloc] init];
        [rec setClientid:clientID];
        [rec setLastn:lastName];
        [rec setFirstn:firstName];
        
		[allRecs addObject:rec];
    }
    
    [self setResultsArray:allRecs];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"DisplayPhotosSegue"])
    {
        NSIndexPath *indexPath = self.myTableView.indexPathForSelectedRow;
        
        PhotoViewController *dest = segue.destinationViewController;
        dest.clientRec = [[self resultsArray] objectAtIndex:indexPath.row];
    }
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [[self resultsArray] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView
                             dequeueReusableCellWithIdentifier:@"ClientCell"];
	Client *client = [[self resultsArray] objectAtIndex:indexPath.row];
	
    NSMutableString *fullName = [[NSMutableString alloc] init];
    [fullName appendString:[client lastn]];
    [fullName appendString:@", "];
    [fullName appendString:[client firstn]];

    cell.textLabel.text = fullName;
   
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

@end
