#import "PhotoViewController.h"
#import "ImageScrollView.h"
#import <MessageUI/MessageUI.h>

/*
 In order to use the MFMailComposeViewController, which is what lets you attach a picture to an
 email, you need to link the MessageUI.framework. which is imported above. Here's how to do this:
 1) Click the SamplePhotoProject target.
 2) Click the Summary tab.
 3) Scroll down to Linked Frameworks and Libraries.
 4) Click the + button.
 5) Scroll down to "MessageUI.framework", select it, and click Add.
 */

//even though I don't use the UINavigationControllerDelegate's methods, you need it here along with the
//UIImagePickerControllerDelegate or you get a warning on the setDelegate:self code when the image picker is displayed.
@interface PhotoViewController () <UIScrollViewDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MFMailComposeViewControllerDelegate>

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index;

- (CGRect)frameForPagingScrollView;
- (CGRect)frameForPageAtIndex:(NSUInteger)index;
- (CGSize)contentSizeForPagingScrollView;

- (void)tilePages;
- (ImageScrollView *)dequeueRecycledPage;
-(void)handleTap;
-(void)addPhoto;

@property(nonatomic, copy) NSArray *imgPaths;
@property(nonatomic, copy) NSString *popupAction;

//I have 2 toolbars for the upper part--one with the delete/action/add, and one with just add
//I switch them depending on how many pics I have.
@property (nonatomic, weak) UIBarButtonItem *addBtn;

@end

@implementation PhotoViewController
{
    UIScrollView *pagingScrollView;
    
    NSMutableSet *recycledPages;
    NSMutableSet *visiblePages;
    
    // these values are stored off before we start rotation so we adjust our content offset appropriately during rotation
    int firstVisiblePageIndexBeforeRotation;
    CGFloat percentScrolledIntoFirstVisiblePage;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //create dir for this client record.
    NSString *picPath = [self cobbleFullPathToPicDir:self.clientRec.clientid];
    
	NSFileManager *fileManager = [NSFileManager defaultManager];
    
	BOOL exists = [fileManager fileExistsAtPath:picPath];
	if(exists == NO)
	{
        [fileManager createDirectoryAtPath:picPath withIntermediateDirectories:YES attributes:nil error:nil];
        
        //REMOVE THIS CODE IF YOU DON'T WANT ANY PICTURES IN THE CLIENT DIRECTORY TO START WITH.
        //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        UIImage *img;
        
        for (int i=1;i<4;i++)
        {
            img = [UIImage imageNamed:[NSString stringWithFormat:@"%d.jpg",i]];
            
            //cobble the path
            //the "06d" says to make an integer of 6 characters, padded with zeroes at the left.
            NSString *picPath = [self cobbleFullPathToPicDir:self.clientRec.clientid];
            picPath = [picPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%06d",i]];
            picPath = [picPath stringByAppendingString:@".jpg"];
            
            [UIImageJPEGRepresentation(img, 0.4) writeToFile:picPath atomically:YES];
        }
        //%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    }

    self.imgPaths=[self getImagePaths];
    
    //you need this so the UIScrollView knows to underlap the status bar.
    self.wantsFullScreenLayout=YES;
    
    //hide the tab bar since I don't need it on this screen.
    self.tabBarController.tabBar.hidden=YES;
    
    //make the outer paging scroll view
    [self makeOuterScrollview];
    
    //set their style
    self.navigationController.navigationBar.translucent=YES;
    self.navigationController.navigationBar.barStyle=UIBarStyleBlackTranslucent;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent];
    
    //hide them at first.
    [self.navigationController setNavigationBarHidden:YES animated:NO];   
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];

    [self createUpperRightToolbar];
}

-(void)createUpperRightToolbar
{
    // create a toolbar to have two buttons in the right
    UIToolbar* tools = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 133, 44.01)];
    
    tools.barStyle=UIBarStyleBlackTranslucent;
    
    // create the array to hold the buttons, which then gets added to the toolbar
    NSMutableArray* buttons = [[NSMutableArray alloc] initWithCapacity:5];
    
    // create a button
    UIBarButtonItem* bi = [[UIBarButtonItem alloc]
                           initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deletePhoto)];
    bi.style = UIBarButtonItemStyleBordered;
    [buttons addObject:bi];
    
    // create a spacer
    bi = [[UIBarButtonItem alloc]
          initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    [buttons addObject:bi];
    
    // create button
    bi = [[UIBarButtonItem alloc]
          initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(doPhotoAction)];
    bi.style = UIBarButtonItemStyleBordered;
    [buttons addObject:bi];
    
    // create a spacer
    bi = [[UIBarButtonItem alloc]
          initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    [buttons addObject:bi];
    
    // create button
    bi = [[UIBarButtonItem alloc]
          initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addPhoto)];
    bi.style = UIBarButtonItemStyleBordered;
    [buttons addObject:bi];
    self.addBtn = bi;
    
    // stick the buttons in the toolbar
    [tools setItems:buttons animated:NO];
    
    // and put the toolbar in the nav bar
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:tools];
}

-(void)makeOuterScrollview
{
    CGRect pagingScrollViewFrame = [self frameForPagingScrollView];
    pagingScrollView = [[UIScrollView alloc] initWithFrame:pagingScrollViewFrame];
    pagingScrollView.pagingEnabled = YES;
    pagingScrollView.backgroundColor = [UIColor blackColor];
    pagingScrollView.showsVerticalScrollIndicator = NO;
    pagingScrollView.showsHorizontalScrollIndicator = NO;
    pagingScrollView.contentSize = [self contentSizeForPagingScrollView];
    pagingScrollView.delegate = self;
    [self.view addSubview:pagingScrollView];
    
    // Step 2: prepare to tile content
    recycledPages = [[NSMutableSet alloc] init];
    visiblePages  = [[NSMutableSet alloc] init];
    [self tilePages];
    
    //add a tap recognizer
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    singleTap.enabled=YES;
    singleTap.cancelsTouchesInView=NO;
    [pagingScrollView addGestureRecognizer:singleTap];
}

-(void)doPhotoAction
{
    [self setPopupAction:@"Action"];
    
    UIActionSheet *popupQuery = [[UIActionSheet alloc]
                                 initWithTitle:@"These pictures are stored separately from the Camera Roll."
                                 delegate:self
                                 cancelButtonTitle:@"Cancel"
                                 destructiveButtonTitle:nil
                                 otherButtonTitles:@"Save to Camera Roll", @"Email Picture", nil];
    popupQuery.actionSheetStyle = UIActionSheetStyleDefault;
    [popupQuery showInView:[UIApplication sharedApplication].keyWindow];
}

-(void)deletePhoto
{
    [self setPopupAction:@"Delete"];
    
    UIActionSheet *popupQuery = [[UIActionSheet alloc]
                  initWithTitle:@"These pictures are stored separately from the Camera Roll."
                  delegate:self
                  cancelButtonTitle:@"Cancel"
                  destructiveButtonTitle:@"Delete Photo"
                  otherButtonTitles:nil];
    popupQuery.actionSheetStyle = UIActionSheetStyleDefault;
    [popupQuery showInView:[UIApplication sharedApplication].keyWindow];
}

-(void)addPhoto
{
    [self setPopupAction:@"AddPhoto"];
    
    UIActionSheet *popupQuery = [[UIActionSheet alloc]
                  initWithTitle:@"These pictures are stored separately from the Camera Roll."
                  delegate:self
                  cancelButtonTitle:@"Cancel"
                  destructiveButtonTitle:nil
                  otherButtonTitles:@"Take Photo", @"Choose Existing", nil];
    popupQuery.actionSheetStyle = UIActionSheetStyleDefault;
    
    [popupQuery showInView:[UIApplication sharedApplication].keyWindow];
       
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //this code is if they want to delete the client record.
    if ([self.popupAction isEqualToString:@"Delete"])
    {
        //button 0 is the delete button, 1 is the cancel button.
        if (buttonIndex != 0)
        {
            return;
        }
        
        //delete the pic.
        int i;
        for (i=0;i<self.imgPaths.count;i++)
        {
            //find out which pic we're viewing
            if ([self isDisplayingPageForIndex:i])
            {
                //delete the actual file.
                NSString *picToDelete = [self.imgPaths objectAtIndex:i];
                NSFileManager *fileManager = [NSFileManager defaultManager];
                [fileManager removeItemAtPath:picToDelete error:nil];
            }
        }

        //rename the files and reload the array
        [self renameAllFiles];
        self.imgPaths=[self getImagePaths];
        pagingScrollView=nil;
        [self makeOuterScrollview];
        [self tilePages];
        
        
        if (self.imgPaths.count == 0)
        {
            //swap out to the minimal toolbar if I don't have any pics left to show.
            self.navigationItem.rightBarButtonItem = self.addBtn;
        }
        else
        {
            [self createUpperRightToolbar];
        }
    }
    
    //this code handles the picture button, which combines taking a new pic, choosing an existing one, or deleting the one that's there.
    else if ([self.popupAction isEqualToString:@"AddPhoto"])
    {
        switch (buttonIndex)
        {
            case 0: //Take picture
                [self takeNewPicture];

                break;
                
            case 1: //Choose Existing
                [self chooseExistingPicture];

                break;
                
            case 2: //Cancel
                //don't need to do anything.
                break;
                
            default:
                NSLog(@"ERROR in Switch!");
                break;
        }
    }
    
    //this code handles the picture button, which combines taking a new pic, choosing an existing one, or deleting the one that's there.
    else if ([self.popupAction isEqualToString:@"Action"])
    {
        //use this code
        //http://stackoverflow.com/questions/5739332/iphone-modal-dialog-like-native-take-picture-choose-existing
        
        switch (buttonIndex)
        {
            //you need the braces for each case statement or you get the error "switch case is in protected scope"
            case 0:
            {
                //save to photo roll
                //You can't just say "setImage:[UIImage imageFromPath:myPicPath.fullPath]". It never shows the
                //picture. You have to save it to NSData and show it that way.
                ; // for some reason if you declare a variable at the top of a switch statement, you get an error. This semicolon cures it.
                UIImage *image;
                for (int i=0;i<self.imgPaths.count;i++)
                {
                    //find out which pic we're viewing
                    if ([self isDisplayingPageForIndex:i])
                    {
                        //get the file data that will be saved to the camera roll.
                        NSData *data = [NSData dataWithContentsOfFile:[self.imgPaths objectAtIndex:i]];
                        
                        image = [UIImage imageWithData:data];
                        break;
                    }
                }
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
                
                
                break;
            }
                
            case 1:
            {
                //email photo
                if ([MFMailComposeViewController canSendMail])
                {
                    UIImage *image;
                    NSString *path;
                    for (int i=0;i<self.imgPaths.count;i++)
                    {
                        //find out which pic we're viewing
                        if ([self isDisplayingPageForIndex:i])
                        {
                            //get the file data that will be saved to the camera roll.
                            path=[self.imgPaths objectAtIndex:i];
                            NSData *data = [NSData dataWithContentsOfFile:path];
                            
                            image = [UIImage imageWithData:data];
                            break;
                        }
                    }

                    MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
                    mailer.mailComposeDelegate = self;
                    NSData *imageData = UIImageJPEGRepresentation(image, 0.1);
                    [mailer addAttachmentData:imageData mimeType:@"image/jpg" fileName:path];
                    [self presentModalViewController:mailer animated:YES];
                }
                else
                {
                    NSLog(@"Cannot send");
                }
                
                break;
            }
            case 2:
            {
                //Cancel
                //don't need to do anything.
                break;
            }
            default:
            {
                NSLog(@"ERROR in Switch!");
                break;
            }
        }
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    [self dismissModalViewControllerAnimated:YES];
}

-(void)takeNewPicture
{    
    @try
    {
        UIImagePickerController *mediaPicker = [[UIImagePickerController alloc] init];
        [mediaPicker setDelegate:self];
        mediaPicker.allowsEditing = NO;
        
        //One thing that might surprise you is that the UIImagePickerController is always portrait. It turns out this is true
        //in Apple's apps too, though, like if you're attaching a picture to a text message or email;
        //it's one of those things that you never really pay attention to until you're writing an app
        //and notice an odd behavior, so you try to find an option to change it, but it turns out there isn't one, it's just the
        //standard behavior.
        mediaPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentModalViewController:mediaPicker animated:YES];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Camera not available");
    }
}

-(void)chooseExistingPicture
{   
    @try
    {
        UIImagePickerController *mediaPicker = [[UIImagePickerController alloc] init];
        [mediaPicker setDelegate:self];
        mediaPicker.allowsEditing = NO;
        mediaPicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentModalViewController:mediaPicker animated:YES];
    }
    @catch (NSException *exception)
    {
        NSLog(@"Camera Roll not available");
    }
     
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissModalViewControllerAnimated:YES];
    
    UIImage *selectedImage = (UIImage*) [info valueForKey:UIImagePickerControllerEditedImage];

    if (selectedImage == nil)
    {
        selectedImage = (UIImage*) [info valueForKey:UIImagePickerControllerOriginalImage];
    }
    
    // Write image to JPG
    //how many pics do we currently have? Add 1 to that, and that's my pic name.
    int NewPicNum = self.imgPaths.count + 1;
    
    NSString *picPath = [self cobbleFullPathToPicDir:self.clientRec.clientid];
    picPath = [picPath stringByAppendingString:[NSString stringWithFormat:@"%06d",NewPicNum]];
    picPath = [picPath stringByAppendingString:@".jpg"];
    
    NSString *newPicPath = picPath;

    //Good discussion of UIImagePickerController:
    //http://stackoverflow.com/questions/1282830/uiimagepickercontroller-uiimage-memory-and-more

    [UIImageJPEGRepresentation(selectedImage, 0.1f) writeToFile:newPicPath atomically:NO];
    
    self.imgPaths=[self getImagePaths];
    pagingScrollView=nil;
    [self makeOuterScrollview];
    [self tilePages];
    [self createUpperRightToolbar];

}

-(void)renameAllFiles
{
    NSArray *arr = [self getImagePaths];

    //rename them.
    for (int i=1; i<arr.count+1;i++)
    {
        NSString *oldPath = [arr objectAtIndex:i-1];
        
        NSString *picPath = [self cobbleFullPathToPicDir:self.clientRec.clientid];
        picPath = [picPath stringByAppendingString:[NSString stringWithFormat:@"%06d",i]];
        picPath = [picPath stringByAppendingString:@".jpg"];
        
        NSString *newPath = picPath;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        [fileManager moveItemAtPath:oldPath toPath:newPath error:nil];
    }        
}

-(NSArray*)getImagePaths
{
    NSString *picPath = [self cobbleFullPathToPicDir:self.clientRec.clientid];

    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:picPath error:nil];
    
    //filter the array for jpg only (right now it will include the ".DS_STORE" file)
    //There's another Stack Overflow topic 5851164 that says to use contentsOfDirectoryAtURL because
    //that lets you skip hidden files, but I couldn't get it to work. One weird thing is that you have to pass the path
    //as a URL instead of a string.
    
    //found this tip at stackoverflow 5169222.
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF like %@", @"*.jpg"];
    files = [files filteredArrayUsingPredicate:pred];

    //add the items to the array from the dir.
    NSMutableArray *arr = [[NSMutableArray alloc] init];    
    
    for (NSString *filename in files)
    {
        NSMutableString *newFileName = [[NSMutableString alloc] init];
        [newFileName appendString:picPath];
        [newFileName appendString:filename];
        
        [arr addObject:newFileName];
    }
    [self setImgPaths:arr];
    
    //sort them.
    NSArray *sortedArr=[arr sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

    return sortedArr;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissModalViewControllerAnimated:YES];
}

-(void)handleTap
{
    //hide the delete and action button if there aren't any photos to work with.
    if (self.imgPaths.count == 0)
    {
        self.navigationItem.rightBarButtonItem = self.addBtn;

    }
    else
    {
        [self createUpperRightToolbar];
    }
    
    UINavigationBar *navBar = self.navigationController.navigationBar;
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    float animationDuration;
    if(statusBarFrame.size.height > 20)
    {
        //animate the show faster than the hide.
        animationDuration = 0.2;
    } else
    {
        animationDuration = 0.3;
    }
    
    //if they're currently showing, then hide them.
    if (![UIApplication sharedApplication].statusBarHidden)
    {
        // Change to fullscreen mode
        // Hide status bar and navigation bar
        [[UIApplication sharedApplication] setStatusBarHidden:YES
                                                withAnimation:UIStatusBarAnimationSlide];
        [UIView animateWithDuration:animationDuration animations:^
        {
            navBar.frame = CGRectMake(navBar.frame.origin.x,
                                      -navBar.frame.size.height,
                                      navBar.frame.size.width,
                                      navBar.frame.size.height);

            
        } completion:^(BOOL finished)
        {
            [self.navigationController setNavigationBarHidden:YES animated:NO];
        }];
        
    }
    //otherwise, show them.
    else
    {
        // Change to regular mode
        // Show status bar and navigation bar
        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                                withAnimation:UIStatusBarAnimationSlide];
        [UIView animateWithDuration:animationDuration animations:^
        {
            navBar.frame = CGRectMake(navBar.frame.origin.x,
                                      statusBarFrame.size.height,
                                      navBar.frame.size.width,
                                      navBar.frame.size.height);
            
        } completion:^(BOOL finished)
        {
            [self.navigationController setNavigationBarHidden:NO animated:NO];
        }];
        
    }    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    pagingScrollView = nil;
    recycledPages = nil;
    visiblePages = nil;
}

- (void)tilePages
{
    //don't do this if there aren't any images to add.
    if (self.imgPaths.count == 0) return;
    
    // Calculate which pages are visible
    CGRect visibleBounds = pagingScrollView.bounds;
    //this figures out what number the first page is based on the widths
    int firstNeededPageIndex = floorf(CGRectGetMinX(visibleBounds) / CGRectGetWidth(visibleBounds));
    //this figures out the number of the last page.
    int lastNeededPageIndex  = floorf((CGRectGetMaxX(visibleBounds)-1) / CGRectGetWidth(visibleBounds));
    firstNeededPageIndex = MAX(firstNeededPageIndex, 0);
    lastNeededPageIndex  = MIN(lastNeededPageIndex, [self.imgPaths count] - 1);
    
    // Recycle no-longer-visible pages
    for (ImageScrollView *page in visiblePages)
    {
        if (page.index < firstNeededPageIndex || page.index > lastNeededPageIndex)
        {
            [recycledPages addObject:page];
            [page removeFromSuperview];
        }
    }
    [visiblePages minusSet:recycledPages];
    
    // add missing pages
    for (int index = firstNeededPageIndex; index <= lastNeededPageIndex; index++)
    {
        if (![self isDisplayingPageForIndex:index])
        {
            ImageScrollView *page = [self dequeueRecycledPage];
            if (page == nil)
            {
                page = [[ImageScrollView alloc] init];
            }
            
            //configure the page.
            page.index = index;
            page.frame = [self frameForPageAtIndex:index];
            
            UIImage *img = [UIImage imageWithContentsOfFile:[self.imgPaths objectAtIndex:index]];
            [page displayImage:img];
            
            [pagingScrollView addSubview:page];
            [visiblePages addObject:page];
        }
    }
}

- (ImageScrollView *)dequeueRecycledPage
{
    //this method takes a page from the recycled pages and returns it so it can be used again
    
    ImageScrollView *page = [recycledPages anyObject];
    if (page)
    {
        [recycledPages removeObject:page];
    }
    return page;
}

- (BOOL)isDisplayingPageForIndex:(NSUInteger)index
{
    BOOL foundPage = NO;
    for (ImageScrollView *page in visiblePages)
    {
        if (page.index == index)
        {
            foundPage = YES;
            break;
        }
    }
    return foundPage;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self tilePages];
}

#pragma mark - Frame calculations

#define PADDING  10

- (CGRect)frameForPagingScrollView
{
    CGRect frame =  [[UIScreen mainScreen] bounds];
    frame.origin.x -= PADDING;
    frame.size.width += (2 * PADDING);
    return frame;
}

- (CGRect)frameForPageAtIndex:(NSUInteger)index
{
    // We have to use our paging scroll view's bounds, not frame, to calculate the page placement. When the device is in
    // landscape orientation, the frame will still be in portrait because the pagingScrollView is the root view controller's
    // view, so its frame is in window coordinate space, which is never rotated. Its bounds, however, will be in landscape
    // because it has a rotation transform applied.
    CGRect bounds = pagingScrollView.bounds;
    CGRect pageFrame = bounds;
    pageFrame.size.width -= (2 * PADDING);
    pageFrame.origin.x = (bounds.size.width * index) + PADDING;
    return pageFrame;
}

- (CGSize)contentSizeForPagingScrollView
{
    // We have to use the paging scroll view's bounds to calculate the contentSize, for the same reason outlined above.
    
    CGRect bounds = pagingScrollView.bounds;
    return CGSizeMake(bounds.size.width * [self.imgPaths count], bounds.size.height);
}

-(NSString*) cobbleFullPathToPicDir:(NSString*)clientID
{
    //Path is like this: NSDOCUMENTS/ClientPics/CLIENTID/
    NSString *picPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    picPath = [picPath stringByAppendingPathComponent:@"ClientPics"];
    picPath = [picPath stringByAppendingPathComponent:clientID];
    picPath = [picPath stringByAppendingString:@"/"];
    
    return picPath;
}

@end
