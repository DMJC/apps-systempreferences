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

@end
