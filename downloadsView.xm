//  downloadsView.xm
//  Displays pending downloads and current files

// (c) 2017 opa334

#import "downloadsView.h"

@interface UIView (Autolayout)
+ (id)autolayoutView;
@end

@implementation UIView (Autolayout)
+ (id)autolayoutView
{
    UIView *view = [self new];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    return view;
}
@end

@implementation downloadsTableViewController

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  switch(section)
  {
    case 0:
    return [self.downloadsAtCurrentPath count];
    break;

    case 1:
    return [filesAtCurrentPath count];
    break;

    default:
    return 0;
    break;
  }
}

- (void)populateDataSources
{
  [super populateDataSources];
  self.downloadsAtCurrentPath = [NSMutableArray new];
  self.downloadsAtCurrentPath = [[downloadManager sharedInstance] getDownloadsForPath:self.currentPath];
}

- (void)viewDidAppear:(BOOL)animated
{
  [downloadManager sharedInstance].downloadTableDelegate = self;
  [super viewDidAppear:animated];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if([self tableView:tableView numberOfRowsInSection:0] > 0)
  {
    switch(section)
    {
      case 0:
      return [localizationManager localizedSPStringForKey:@"PENDING_DOWNLOADS"];
      break;

      case 1:
      return [localizationManager localizedSPStringForKey:@"FILES"];
      break;

      default:
      return nil;
      break;
    }
  }
  else
  {
    return nil;
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  switch(indexPath.section)
  {
    case 0:
    {
      Download* currentDownload = self.downloadsAtCurrentPath[indexPath.row];
      downloadTableViewCell* cell = [self newCellWithDownload:currentDownload];
      cell.imageView.image = [UIImage imageNamed:@"File.png" inBundle:SPBundle compatibleWithTraitCollection:nil];
      cell.textLabel.text = currentDownload.fileName;
      currentDownload.cellDelegate = cell;
      return cell;
      break;
    }

    case 1:
    {
      return (fileTableViewCell*)[super tableView:tableView cellForRowAtIndexPath:indexPath];
      break;
    }

    default:
    return nil;
    break;
  }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if(indexPath.section == 0)
  {
    return 66.0;
  }
  else
  {
    return tableView.rowHeight;
  }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
  if(indexPath.section == 1)
  {
    return [super tableView:tableView canEditRowAtIndexPath:indexPath];
  }
  else
  {
    return NO;
  }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if(indexPath.section != 0)
  {
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
  }
}

- (void)selectedEntryAtURL:(NSURL*)entryURL type:(NSInteger)type atIndexPath:(NSIndexPath*)indexPath
{
  //Type 1: file; type 2: symlink; type 3: directory
  if(type == 1)
  {
    BOOL filzaInstalled = [fileManager fileExistsAtPath:@"/Applications/Filza.app"];
    NSString* fileName = [[entryURL lastPathComponent] stringByRemovingPercentEncoding];

    UIAlertController *openAlert = [UIAlertController alertControllerWithTitle:fileName
          message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    CFStringRef fileExtension = (__bridge CFStringRef)[entryURL pathExtension];
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);

    if(UTTypeConformsTo(fileUTI, kUTTypeMovie) || UTTypeConformsTo(fileUTI, kUTTypeAudio))
    {
      UIAlertAction *playAction = [UIAlertAction actionWithTitle:[localizationManager localizedSPStringForKey:@"PLAY"]
            style:UIAlertActionStyleDefault handler:^(UIAlertAction * action)
            {
              [self startPlayerWithMedia:entryURL];
            }];

      [openAlert addAction:playAction];
    }

    UIAlertAction *openInAction = [UIAlertAction actionWithTitle:[localizationManager localizedSPStringForKey:@"OPEN_IN"]
          style:UIAlertActionStyleDefault handler:^(UIAlertAction * action)
          {
            //Creating temporary link cause we ain't inside sandbox (silly, right?)
            self.tmpSymlinkURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", NSTemporaryDirectory(), entryURL.lastPathComponent]];
            [[NSFileManager defaultManager] linkItemAtURL:entryURL.URLByResolvingSymlinksInPath toURL:self.tmpSymlinkURL error:nil];

            self.didSelectOptionFromDocumentController = NO;

            self.documentController = [UIDocumentInteractionController interactionControllerWithURL:self.tmpSymlinkURL];
            self.documentController.delegate = self;
            [self.documentController presentOpenInMenuFromRect:CGRectZero inView:self.view animated:YES];
          }];

    [openAlert addAction:openInAction];

    if(filzaInstalled)
    {
      UIAlertAction *showInFilzaAction = [UIAlertAction actionWithTitle:[localizationManager localizedSPStringForKey:@"SHOW_IN_FILZA"]
            style:UIAlertActionStyleDefault handler:^(UIAlertAction * action)
            {
              //https://stackoverflow.com/a/32145122
              NSString *FilzaPath = [NSString stringWithFormat:@"%@%@", @"filza://view",[entryURL absoluteString]];
              [[UIApplication sharedApplication] openURL:[NSURL URLWithString:FilzaPath]];
            }];

      [openAlert addAction:showInFilzaAction];
    }

    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:[localizationManager localizedSPStringForKey:@"DELETE_FILE"]
          style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action)
          {
            UIAlertController* confirmationController = [UIAlertController alertControllerWithTitle:[localizationManager localizedSPStringForKey:@"WARNING"]
              message:[[localizationManager localizedSPStringForKey:@"DELETE_FILE_MESSAGE"] stringByReplacingOccurrencesOfString:@"<fn>" withString:fileName] preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[localizationManager localizedSPStringForKey:@"CANCEL"]
              style:UIAlertActionStyleDefault handler:nil];

            [confirmationController addAction:cancelAction];

            UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:[localizationManager localizedSPStringForKey:@"DELETE"]
              style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action)
            {
              dispatch_async(dispatch_get_main_queue(), ^
              {
                [fileManager removeItemAtPath:[entryURL path] error:nil];
                [self reloadDataAndDataSources];
              });
            }];

            [confirmationController addAction:deleteAction];

            confirmationController.preferredAction = cancelAction;

            [self presentViewController:confirmationController animated:YES completion:nil];
          }];

    [openAlert addAction:deleteAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[localizationManager localizedSPStringForKey:@"CANCEL"]
          style:UIAlertActionStyleCancel handler:nil];

    [openAlert addAction:cancelAction];

    //iPad fix
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
    openAlert.popoverPresentationController.sourceView = self.tableView;
    openAlert.popoverPresentationController.sourceRect = CGRectMake(cellRect.size.width / 2.0, cellRect.origin.y + cellRect.size.height / 2, 1.0, 1.0);

    [self presentViewController:openAlert animated:YES completion:nil];
  }
  [super selectedEntryAtURL:entryURL type:type atIndexPath:indexPath];
}

//https://stackoverflow.com/a/35619091

- (void)documentInteractionController:(UIDocumentInteractionController *)controller willBeginSendingToApplication:(NSString *)application
{
  self.didSelectOptionFromDocumentController = YES;
}

- (void)documentInteractionController:(UIDocumentInteractionController *)controller didEndSendingToApplication:(NSString *)application
{
  //Clean up
  [[NSFileManager defaultManager] removeItemAtURL:self.tmpSymlinkURL error:nil];
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)controller
{
  if(self.didSelectOptionFromDocumentController == NO) //Cancelled
  {
    //Clean up
    [[NSFileManager defaultManager] removeItemAtURL:self.tmpSymlinkURL error:nil];
  }
}

- (void)startPlayerWithMedia:(NSURL*)mediaURL
{
  [[AVAudioSession sharedInstance] setActive:YES error:nil];

  //Enable Background Audio
  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];

  AVPlayer* player = [AVPlayer playerWithURL:mediaURL];

  AVPlayerViewController *playerViewController = [AVPlayerViewController new];

  playerViewController.player = player;
  //playerViewController.allowsPictureInPicturePlayback = YES;

  [self presentViewController:playerViewController animated:YES completion:^
  {
    [player play];
  }];
}

- (id)newCellWithDownload:(Download*)download
{
  return [[downloadTableViewCell alloc] initWithDownload:download];
}

@end

@implementation downloadsNavigationController

- (NSURL*)rootPath
{
  if(preferenceManager.customDefaultPathEnabled)
  {
    NSURL* path = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/User%@", preferenceManager.customDefaultPath]];
    BOOL isDir;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[path path] isDirectory:&isDir];
    if(isDir && exists)
    {
      return path;
    }
  }
  return [NSURL fileURLWithPath:@"/User/Downloads/"];
}

- (BOOL)shouldLoadPreviousPathElements
{
  return YES;
}

- (id)newTableViewControllerWithPath:(NSURL*)path
{
  return [[downloadsTableViewController alloc] initWithPath:path];
}

@end


@implementation downloadTableViewCell

- (id)initWithDownload:(Download*)download
{
  self = [super initWithSize:download.fileSize];
  self.downloadDelegate = download;
  self.selectionStyle = UITableViewCellSelectionStyleNone;
  self.progressView = [UIProgressView autolayoutView];
  self.percentProgress = [UILabel autolayoutView];
  self.sizeProgress = [UILabel autolayoutView];
  self.sizeSpeedSeperator = [UILabel autolayoutView];
  self.downloadSpeed = [UILabel autolayoutView];
  [self.contentView addSubview:self.progressView];

  self.percentProgress.textAlignment = NSTextAlignmentCenter;
  self.percentProgress.font = [self.percentProgress.font fontWithSize:8];
  [self.contentView addSubview:self.percentProgress];

  self.sizeSpeedSeperator.textAlignment = NSTextAlignmentCenter;
  self.sizeSpeedSeperator.font = [self.percentProgress.font fontWithSize:8];
  self.sizeSpeedSeperator.text = @"@";
  [self.contentView addSubview:self.sizeSpeedSeperator];

  self.downloadSpeed.textAlignment = NSTextAlignmentLeft;
  self.downloadSpeed.font = [self.downloadSpeed.font fontWithSize:8];
  [self.contentView addSubview:self.downloadSpeed];

  self.sizeProgress.textAlignment = NSTextAlignmentRight;
  self.sizeProgress.font = [self.sizeProgress.font fontWithSize:8];
  [self.contentView addSubview:self.sizeProgress];

  self.pauseResumeButton = [UIButton buttonWithType:UIButtonTypeCustom];
  self.pauseResumeButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.pauseResumeButton.adjustsImageWhenHighlighted = YES;
  [self.pauseResumeButton addTarget:self action:@selector(pauseResumeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
  [self.pauseResumeButton setImage:[UIImage imageNamed:@"PauseButton.png" inBundle:SPBundle compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
  [self.pauseResumeButton setImage:[UIImage imageNamed:@"ResumeButton.png" inBundle:SPBundle compatibleWithTraitCollection:nil] forState:UIControlStateSelected];
  [self.contentView addSubview:self.pauseResumeButton];

  self.stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
  self.stopButton.translatesAutoresizingMaskIntoConstraints = NO;
  self.stopButton.adjustsImageWhenHighlighted = YES;
  [self.stopButton addTarget:self action:@selector(stopButtonPressed) forControlEvents:UIControlEventTouchUpInside];
  [self.stopButton setImage:[UIImage imageNamed:@"StopButton.png" inBundle:SPBundle compatibleWithTraitCollection:nil] forState:UIControlStateNormal];
  [self.contentView addSubview:self.stopButton];

  NSDictionary *metrics = @{@"rightSpace":@43.5, @"smallSpace":@7.5, @"buttonSize":@28.0};
  NSDictionary *views = [NSDictionary dictionaryWithObjectsAndKeys:
                    self.progressView, @"progressView",
                    self.percentProgress, @"percentProgress",
                    self.sizeSpeedSeperator, @"sizeSpeedSeperator",
                    self.sizeProgress, @"sizeProgress",
                    self.downloadSpeed, @"downloadSpeed",
                    self.pauseResumeButton, @"pauseResumeButton",
                    self.stopButton, @"stopButton",
                    nil];

  [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
      @"|-[sizeProgress(downloadSpeed)]-smallSpace-[sizeSpeedSeperator(8)]-smallSpace-[downloadSpeed(sizeProgress)]-rightSpace-|" options:0 metrics:metrics views:views]];

  [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
      @"|-[progressView]-smallSpace-[stopButton(buttonSize)]-|" options:0 metrics:metrics views:views]];

  [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
      @"|-[percentProgress]-rightSpace-|" options:0 metrics:metrics views:views]];

  [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
      @"[pauseResumeButton(buttonSize)]-8-|" options:0 metrics:metrics views:views]];

  [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
      @"V:|-4.0-[pauseResumeButton(buttonSize)]-[stopButton(buttonSize)]-4-|" options:0 metrics:metrics views:views]];

  [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
      @"V:[sizeProgress(8)]-19-|" options:0 metrics:metrics views:views]];

  [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
      @"V:[sizeSpeedSeperator(8)]-3-[progressView(2.5)]-3-[percentProgress(8)]-3-|" options:0 metrics:metrics views:views]];

  [self.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
      @"V:[downloadSpeed(8)]-19-|" options:0 metrics:metrics views:views]];

  if(download.totalBytesWritten > 0)
  {
    [self updateProgress:download.totalBytesWritten totalBytes:download.fileSize bytesPerSecond:0 animated:NO];
  }

  if(download.paused)
  {
    self.pauseResumeButton.selected = YES;
    self.percentProgress.textColor = [UIColor grayColor];
    self.progressView.progressTintColor = [UIColor grayColor];
    self.sizeProgress.textColor = [UIColor grayColor];
    self.sizeSpeedSeperator.textColor = [UIColor grayColor];
    self.downloadSpeed.textColor = [UIColor grayColor];
  }
  else
  {
    self.percentProgress.textColor = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
    self.progressView.progressTintColor = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
    self.sizeProgress.textColor = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
    self.sizeSpeedSeperator.textColor = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
    self.downloadSpeed.textColor = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
  }

  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  dispatch_async(dispatch_get_main_queue(), ^
  {
    self.textLabel.frame = CGRectMake(self.textLabel.frame.origin.x,self.textLabel.frame.origin.y - 11,self.textLabel.frame.size.width - 32.5,self.textLabel.frame.size.height);
    self.imageView.frame = CGRectMake(self.imageView.frame.origin.x,self.imageView.frame.origin.y - 11,self.imageView.frame.size.width,self.imageView.frame.size.height);
    self.pauseResumeButton.imageView.layer.cornerRadius = self.pauseResumeButton.imageView.frame.size.height / 2.0;
    self.stopButton.imageView.layer.cornerRadius = self.stopButton.imageView.frame.size.height / 2.0;
  });
}

- (void)pauseResumeButtonPressed
{
  dispatch_async(dispatch_get_main_queue(),
  ^{
    self.pauseResumeButton.selected = !self.pauseResumeButton.selected;

    if(self.pauseResumeButton.selected)
    {
      [self.downloadDelegate pauseDownload];
      self.percentProgress.textColor = [UIColor grayColor];
      self.progressView.progressTintColor = [UIColor grayColor];
      self.sizeProgress.textColor = [UIColor grayColor];
      self.sizeSpeedSeperator.textColor = [UIColor grayColor];
      self.downloadSpeed.textColor = [UIColor grayColor];
    }
    else
    {
      [self.downloadDelegate resumeDownload];
      self.percentProgress.textColor = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
      self.progressView.progressTintColor = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
      self.sizeProgress.textColor = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
      self.sizeSpeedSeperator.textColor = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
      self.downloadSpeed.textColor = [UIColor colorWithRed:0.45 green:0.65 blue:0.95 alpha:1.0];
    }
  });
}

- (void)stopButtonPressed
{
  [self.downloadDelegate cancelDownload];
}

- (void)updateProgress:(int64_t)currentBytes totalBytes:(int64_t)totalBytes bytesPerSecond:(int64_t)bytesPerSecond animated:(BOOL)animated
{
    float progress = (float)currentBytes / (float)totalBytes;
    NSString* percentProgressString = [NSString stringWithFormat:@"%.1f%%", progress * 100];
    NSString* sizeString = [NSByteCountFormatter stringFromByteCount:currentBytes countStyle:NSByteCountFormatterCountStyleFile];
    NSString* sizeSpeedSeperator = @"@";
    NSString* speedString = [NSString stringWithFormat:@"%@/s", [NSByteCountFormatter stringFromByteCount:bytesPerSecond countStyle:NSByteCountFormatterCountStyleFile]];
    dispatch_async(dispatch_get_main_queue(),
    ^{
      [self.progressView setProgress:progress animated:animated];
      self.percentProgress.text = percentProgressString;
      self.sizeProgress.text = sizeString;
      self.sizeSpeedSeperator.text = sizeSpeedSeperator;
      self.downloadSpeed.text = speedString;
    });
}

@end