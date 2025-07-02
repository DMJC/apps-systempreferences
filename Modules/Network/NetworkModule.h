#ifndef NETWORKMODULE_H
#define NETWORKMODULE_H

#import <Cocoa/Cocoa.h>
#import "PreferencePanes.h"

@interface NetworkModule : NSPreferencePane <NSTableViewDelegate, NSTableViewDataSource>
@property (strong) NSTableView *deviceTableView;
@property (strong) NSTableView *inputDeviceTableView;
@property (strong) NSTableView *outputDeviceTableView;
@property (nonatomic, strong) NSButton *ApplyButton;
@end
#endif //NETWORKMODULE_H
