
#import "Client.h"

@implementation Client

- (id)copyWithZone:(NSZone *)zone
{
    Client *results = [[Client alloc] init];
    
    results.clientid = self.clientid;
    results.lastn = self.lastn;
    results.firstn = self.firstn;
    
    return results;
}

@end
