// VideoModule.h
// GNUstep / SystemPreferences module for managing display resolutions with RandR

#import <AppKit/AppKit.h>
#import "PreferencePanes.h"
NS_ASSUME_NONNULL_BEGIN

@interface VideoModule : NSPreferencePane <NSTableViewDataSource, NSTableViewDelegate>

// Outlets – wire them up in Gorm/Nib, or programmatically create in mainViewDidLoad
@property (nonatomic, strong) IBOutlet NSTableView *deviceTableView;       // List of connected outputs
@property (nonatomic, strong) IBOutlet NSTableView *outputDeviceTableView; // Modes for selected output
@property (nonatomic, strong) IBOutlet NSTableView *scaleTableView;	   // Scale Table
@property (nonatomic, strong) IBOutlet NSTableView *inputDeviceTableView;  // Details table
@property (nonatomic, strong) IBOutlet NSButton    *ApplyButton;           // Apply button
@property (nonatomic, strong) IBOutlet NSScrollView *scaleScrollView;
// SystemPreferences entry point
- (void)mainViewDidLoad;

// Actions
- (IBAction)onApply:(id)sender;

@end

NS_ASSUME_NONNULL_END
