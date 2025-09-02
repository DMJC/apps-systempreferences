#ifndef NETWORKMODULE_H
#define NETWORKMODULE_H

#import <Cocoa/Cocoa.h>
#import "PreferencePanes.h"

@interface NetworkModule : NSPreferencePane <NSTableViewDelegate, NSTableViewDataSource>
@property (strong) NSTableView *connectionListView;
@property (strong) NSArray *connectionTypes;
@property (strong) NSButton *addButton;
@property (strong) NSButton *removeButton;
@end
#endif //NETWORKMODULE_H
