//  Download.h
// (c) 2017 opa334

#import "SPPreferenceManager.h"

@class Download;

@protocol DownloadTableDelegate
@required
- (void)reloadDataAndDataSources;
@end

@protocol DownloadCellDelegate
@required
- (void)updateDownloadSpeed:(int64_t)bytesPerSecond;
- (void)updateProgress:(int64_t)currentBytes totalBytes:(int64_t)totalBytes animated:(BOOL)animated;
@end

@protocol RootControllerDownloadDelegate
@required
- (void)dispatchNotificationWithText:(NSString*)text;
- (void)dismissNotificationWithCompletion:(void (^)(void))completion;
- (void)presentViewController:(id)viewController;
@end

@protocol DownloadManagerDelegate
@required
- (void)downloadFinished:(Download*)download withLocation:(NSURL*)location;
- (void)downloadCancelled:(Download*)download;
@end

@protocol CellDownloadDelegate
@required
- (void)cancelDownload;
- (void)pauseDownload;
- (void)resumeDownload;
- (void)setCellDelegate:(id<DownloadCellDelegate>)cellDelegate;
@end

@interface Download : NSObject <NSURLSessionDownloadDelegate, NSURLSessionDelegate, CellDownloadDelegate> {}
@property (nonatomic, strong) NSURLSession* session;
@property (nonatomic, strong) NSURLSessionDownloadTask* downloadTask;
@property (nonatomic, weak) id<DownloadManagerDelegate> downloadManagerDelegate;
@property (nonatomic, weak) id<DownloadCellDelegate> cellDelegate;
@property (nonatomic) BOOL paused;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) NSTimer* speedTimer;
@property (nonatomic) int64_t startBytes;
@property (nonatomic) int64_t totalBytesWritten;
@property (nonatomic) int64_t bytesPerSecond;
@property (nonatomic) NSString* fileName;
@property (nonatomic) int64_t fileSize;
@property (nonatomic) NSURL* filePath;
@property (nonatomic) BOOL replaceFile;
@property (nonatomic) NSString* identifier;
- (void)updateDownloadSpeed;
- (void)cancelDownload;
- (void)pauseDownload;
- (void)resumeDownload;
- (void)startDownloadFromRequest:(NSURLRequest*)request;
@end
