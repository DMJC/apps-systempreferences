#import "NetworkModule.h"

@implementation NetworkModule

- (void)dealloc {
    [super dealloc];
}

- (void)mainViewDidLoad {
    [super mainViewDidLoad];
    [self setupUI];
}

#pragma mark - Data

- (NSArray *)fetchConnectionTypes {
    NSMutableSet *types = [NSMutableSet set];
    @try {
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/env"];
        [task setArguments:@[@"nmcli", @"-t", @"-f", @"TYPE", @"connection", @"show"]];
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        [task launch];
        [task waitUntilExit];

        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSArray *lines = [output componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            if ([line length] > 0) {
                [types addObject:line];
            }
        }
    }
    @catch (NSException *exception) {
        // ignore and fall back to defaults
    }

    if ([types count] == 0) {
        [types addObjectsFromArray:@[@"ethernet", @"wifi", @"bond", @"ip-tunnel",
                                     @"macsec", @"team", @"vlan", @"wireguard",
                                     @"bridge", @"bluetooth", @"dsl", @"infiniband",
                                     @"gsm", @"vpn"]];
    }

    NSMutableArray *result = [NSMutableArray array];
    for (NSString *type in types) {
        NSImage *icon = [self iconForConnectionType:type];
        if (!icon) {
            NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"Network" ofType:@"tiff"];
            icon = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
        }
        [result addObject:@{ @"name": type, @"icon": icon }];
    }
    return result;
}

- (NSImage *)iconForConnectionType:(NSString *)type {
    NSString *iconName = nil;
    if ([type caseInsensitiveCompare:@"ethernet"] == NSOrderedSame) {
        iconName = @"Ethernet";
    } else if ([type caseInsensitiveCompare:@"bluetooth"] == NSOrderedSame) {
        iconName = @"bluetooth";
    } else {
        iconName = @"Network";
    }

    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:iconName ofType:@"tiff"];
    return [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
}

- (NSString *)maskFromPrefix:(NSInteger)prefix {
    uint32_t mask = prefix == 0 ? 0 : 0xffffffff << (32 - prefix);
    return [NSString stringWithFormat:@"%d.%d.%d.%d",
            (mask >> 24) & 0xFF,
            (mask >> 16) & 0xFF,
            (mask >> 8) & 0xFF,
            mask & 0xFF];
}

- (NSDictionary *)detailsForConnectionType:(NSString *)type {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    @try {
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath:@"/usr/bin/env"];
        [task setArguments:@[@"nmcli", @"-t", @"-f", @"DEVICE,TYPE", @"connection", @"show", @"--active"]];
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput:pipe];
        [task launch];
        [task waitUntilExit];
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        NSArray *lines = [output componentsSeparatedByString:@"\n"];
        NSString *device = nil;
        for (NSString *line in lines) {
            NSArray *parts = [line componentsSeparatedByString:@":"];
            if ([parts count] == 2) {
                if ([[parts objectAtIndex:1] isEqualToString:type]) {
                    device = [parts objectAtIndex:0];
                    break;
                }
            }
        }

        if (device) {
            NSTask *detail = [[NSTask alloc] init];
            [detail setLaunchPath:@"/usr/bin/env"];
            [detail setArguments:@[@"nmcli", @"-t", @"-f",
                                   @"GENERAL.STATE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP4.DOMAIN",
                                   @"device", @"show", device]];
            NSPipe *dpipe = [NSPipe pipe];
            [detail setStandardOutput:dpipe];
            [detail launch];
            [detail waitUntilExit];
            NSData *ddata = [[dpipe fileHandleForReading] readDataToEndOfFile];
            NSString *dout = [[[NSString alloc] initWithData:ddata encoding:NSUTF8StringEncoding] autorelease];
            NSArray *dl = [dout componentsSeparatedByString:@"\n"];
            BOOL connected = NO;
            for (NSString *l in dl) {
                if ([l hasPrefix:@"GENERAL.STATE:"]) {
                    connected = ([l rangeOfString:@"connected"].location != NSNotFound);
                } else if ([l hasPrefix:@"IP4.ADDRESS"]) {
                    NSString *val = [[l componentsSeparatedByString:@":"] lastObject];
                    NSRange slash = [val rangeOfString:@"/"];
                    if (slash.location != NSNotFound) {
                        NSString *ip = [val substringToIndex:slash.location];
                        NSInteger prefix = [[val substringFromIndex:slash.location+1] integerValue];
                        [info setObject:ip forKey:@"ip"];
                        [info setObject:[self maskFromPrefix:prefix] forKey:@"mask"];
                    } else {
                        [info setObject:val forKey:@"ip"];
                    }
                } else if ([l hasPrefix:@"IP4.GATEWAY:"]) {
                    [info setObject:[[l componentsSeparatedByString:@":"] lastObject] forKey:@"router"];
                } else if ([l hasPrefix:@"IP4.DNS"]) {
                    NSString *dns = [info objectForKey:@"dns"];
                    NSString *val = [[l componentsSeparatedByString:@":"] lastObject];
                    if (dns) {
                        dns = [dns stringByAppendingFormat:@",%@", val];
                        [info setObject:dns forKey:@"dns"];
                    } else {
                        [info setObject:val forKey:@"dns"];
                    }
                } else if ([l hasPrefix:@"IP4.DOMAIN"]) {
                    NSString *domains = [info objectForKey:@"search"];
                    NSString *val = [[l componentsSeparatedByString:@":"] lastObject];
                    if (domains) {
                        domains = [domains stringByAppendingFormat:@",%@", val];
                        [info setObject:domains forKey:@"search"];
                    } else {
                        [info setObject:val forKey:@"search"];
                    }
                }
            }
            [info setObject:(connected ? @"Connected" : @"Disconnected") forKey:@"status"];
        } else {
            [info setObject:@"Disconnected" forKey:@"status"];
        }
    }
    @catch (NSException *exception) {
        // ignore, return whatever we have
    }

    return info;
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *contentView = [self mainView];
    self.mainView.frame = NSMakeRect(0, 0, 400, 360);

    self.connectionTypes = [self fetchConnectionTypes];

    NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 40, 100, 300)] autorelease];
    NSTableView *tableView = [[[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 100, 300)] autorelease];
    NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"TypeColumn"] autorelease];
    [column setWidth:100];
    [tableView addTableColumn:column];
    [tableView setHeaderView:nil];
    tableView.delegate = self;
    tableView.dataSource = self;
    self.connectionListView = tableView;
    scrollView.documentView = tableView;
    [scrollView setHasVerticalScroller:YES];
    [contentView addSubview:scrollView];

    self.addButton = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 10, 20, 20)] autorelease];
    [self.addButton setTitle:@"+"];
    [self.addButton setBezelStyle:NSBezelStyleTexturedSquare];
    [self.addButton setTarget:self];
    [self.addButton setAction:@selector(addConnection:)];
    [contentView addSubview:self.addButton];

    self.removeButton = [[[NSButton alloc] initWithFrame:NSMakeRect(60, 10, 20, 20)] autorelease];
    [self.removeButton setTitle:@"-"];
    [self.removeButton setBezelStyle:NSBezelStyleTexturedSquare];
    [self.removeButton setTarget:self];
    [self.removeButton setAction:@selector(removeConnection:)];
    [contentView addSubview:self.removeButton];

    CGFloat labelX = 140.0;
    CGFloat valueX = 240.0;
    CGFloat startY = 320.0;

    NSTextField *(^makeLabel)(NSString *, CGFloat) = ^NSTextField *(NSString *text, CGFloat y) {
        NSTextField *label = [[[NSTextField alloc] initWithFrame:NSMakeRect(labelX, y, 100, 20)] autorelease];
        [label setStringValue:text];
        [label setBordered:NO];
        [label setEditable:NO];
        [label setBackgroundColor:[NSColor clearColor]];
        [contentView addSubview:label];
        return label;
    };

    NSTextField *(^makeValueField)(CGFloat) = ^NSTextField *(CGFloat y) {
        NSTextField *field = [[[NSTextField alloc] initWithFrame:NSMakeRect(valueX, y, 140, 20)] autorelease];
        [field setEditable:NO];
        [contentView addSubview:field];
        return field;
    };

    makeLabel(@"Status:", startY);
    self.statusField = makeValueField(startY);

    makeLabel(@"IP Address:", startY - 30);
    self.ipField = makeValueField(startY - 30);

    makeLabel(@"Subnet Mask:", startY - 60);
    self.maskField = makeValueField(startY - 60);

    makeLabel(@"Router:", startY - 90);
    self.routerField = makeValueField(startY - 90);

    makeLabel(@"DNS Server:", startY - 120);
    self.dnsField = makeValueField(startY - 120);

    makeLabel(@"Search Domains:", startY - 150);
    self.searchField = makeValueField(startY - 150);
}

#pragma mark - Actions

- (void)addConnection:(id)sender {
    NSLog(@"Add Connection Pressed");
}

- (void)removeConnection:(id)sender {
    NSInteger row = [self.connectionListView selectedRow];
    if (row >= 0) {
        NSLog(@"Remove Connection at row %ld", (long)row);
    }
}

#pragma mark - TableView Data Source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.connectionTypes count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSDictionary *info = [self.connectionTypes objectAtIndex:row];
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"Cell" owner:self];
    if (!cell) {
        cell = [[[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 100, 20)] autorelease];
        cell.identifier = @"Cell";
        NSImageView *imageView = [[[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 20, 20)] autorelease];
        [imageView setImageScaling:NSImageScaleProportionallyDown];
        [cell addSubview:imageView];
        NSTextField *textField = [[[NSTextField alloc] initWithFrame:NSMakeRect(24, 0, 76, 20)] autorelease];
        [textField setBordered:NO];
        [textField setEditable:NO];
        [textField setBackgroundColor:[NSColor clearColor]];
        [cell addSubview:textField];
        cell.imageView = imageView;
        cell.textField = textField;
    }

    cell.imageView.image = [info objectForKey:@"icon"];
    cell.textField.stringValue = [info objectForKey:@"name"];
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = [self.connectionListView selectedRow];
    if (row < 0 || row >= [self.connectionTypes count]) {
        return;
    }
    NSString *type = [[self.connectionTypes objectAtIndex:row] objectForKey:@"name"];
    NSDictionary *details = [self detailsForConnectionType:type];
    self.statusField.stringValue = [details objectForKey:@"status"] ?: @"";
    self.ipField.stringValue = [details objectForKey:@"ip"] ?: @"";
    self.maskField.stringValue = [details objectForKey:@"mask"] ?: @"";
    self.routerField.stringValue = [details objectForKey:@"router"] ?: @"";
    self.dnsField.stringValue = [details objectForKey:@"dns"] ?: @"";
    self.searchField.stringValue = [details objectForKey:@"search"] ?: @"";
}

@end
