#ifndef VIDEOMODULE_H
#define VIDEOMODULE_H

#import <Cocoa/Cocoa.h>
#import "PreferencePanes.h"

@interface VideoModule : NSPreferencePane <NSTableViewDelegate, NSTableViewDataSource>
@property (strong) NSTableView *deviceTableView;
@property (strong) NSTableView *inputDeviceTableView;
@property (strong) NSTableView *outputDeviceTableView;
@property (nonatomic, strong) NSButton *ApplyButton;
@end
#endif //VIDEOMODULE_H
