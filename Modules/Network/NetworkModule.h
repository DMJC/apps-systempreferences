#ifndef NETWORKMODULE_H
#define NETWORKMODULE_H

#import <Cocoa/Cocoa.h>
#import "PreferencePanes.h"

@interface NetworkModule : NSPreferencePane <NSTableViewDelegate, NSTableViewDataSource>
@property (retain) NSTableView *connectionListView;
@property (retain) NSArray *connectionTypes;
@property (retain) NSButton *addButton;
@property (retain) NSButton *removeButton;
@property (retain) NSTextField *statusField;
@property (retain) NSTextField *ipField;
@property (retain) NSTextField *maskField;
@property (retain) NSTextField *routerField;
@property (retain) NSTextField *dnsField;
@property (retain) NSTextField *searchField;
@property (retain) NSPopUpButton *methodPopup;
@end
#endif //NETWORKMODULE_H
