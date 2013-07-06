
#import "AppDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //Create the base directory where the pictures will be stored.
    NSString *picPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        
    NSString *imgDir=[picPath stringByAppendingPathComponent:@"ClientPics"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
        
    BOOL exists = [fileManager fileExistsAtPath:imgDir];
    if(exists == NO)
    {
        [fileManager createDirectoryAtPath:imgDir withIntermediateDirectories:NO attributes:nil error:nil];
    }
        
    return YES;
}

@end
