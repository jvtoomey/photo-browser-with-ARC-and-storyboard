#import <UIKit/UIKit.h>
#import "Client.h"

@class ImageScrollView;

@interface PhotoViewController : UIViewController

-(NSString*) cobbleFullPathToPicDir:(NSString*)clientID;

@property(nonatomic, copy) Client *clientRec;



@end

