#import "VideoModule.h"

@implementation VideoModule

- (void)dealloc {
    [super dealloc];
}

- (void)mainViewDidLoad {
    [super mainViewDidLoad];
    [self setupUI];
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *contentView = [self mainView];
    CGFloat width = contentView.bounds.size.width;
    //TabView
    // Set up the main view frame
    self.mainView.frame = NSMakeRect(0, 0, 400, 300);
    // Create an NSTabView and set it up
    NSTabView *tabView = [[NSTabView alloc] initWithFrame:self.mainView.bounds];
    tabView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    tabView.tabViewType = NSTopTabsBezelBorder;

    // Add tabs
    NSTabViewItem *displayTab = [[NSTabViewItem alloc] initWithIdentifier:@"Display"];
    [displayTab setLabel:@"Display"];

    // Create a view for the General tab
    NSView *generalView = [[NSView alloc] initWithFrame:tabView.bounds];
    generalView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    // Add a label to the General tab
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, generalView.bounds.size.height - 50, 300, 20)];
    label.stringValue = @"Select an Alert Sound:";
    label.editable = NO;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.alignment = NSTextAlignmentLeft;
    label.font = [NSFont systemFontOfSize:13.0];
    [generalView addSubview:label];
    [displayTab setView:generalView];
    [tabView addTabViewItem:displayTab];

    // Add Audio Output Tab
    NSTabViewItem *arrangementViewTab = [[NSTabViewItem alloc] initWithIdentifier:@"Output"];
    [arrangementViewTab setLabel:@"Arrangement"];
    NSView *arrangementView = [[NSView alloc] initWithFrame:tabView.bounds];
    [arrangementViewTab setView:arrangementView];
    [tabView addTabViewItem:arrangementViewTab];

    // Add the tabView to the mainView
    [self.mainView addSubview:tabView];

    NSTextField *arrangementView_top_label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, generalView.bounds.size.height - 30, 420, 20)];
    arrangementView_top_label.stringValue = @"To rearrange the displays, drag them to the desired position.";
    arrangementView_top_label.editable = NO;
    arrangementView_top_label.bezeled = NO;
    arrangementView_top_label.drawsBackground = NO;
    arrangementView_top_label.alignment = NSTextAlignmentLeft;
    arrangementView_top_label.font = [NSFont systemFontOfSize:13.0];
    [arrangementView addSubview:arrangementView_top_label];

    NSTextField *arrangementView_bot_label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, generalView.bounds.size.height - 45, 420, 20)];
    arrangementView_bot_label.stringValue = @"To relocate the menu bar, drag it to a different display.";
    arrangementView_bot_label.editable = NO;
    arrangementView_bot_label.bezeled = NO;
    arrangementView_bot_label.drawsBackground = NO;
    arrangementView_bot_label.alignment = NSTextAlignmentLeft;
    arrangementView_bot_label.font = [NSFont systemFontOfSize:13.0];
    [arrangementView addSubview:arrangementView_bot_label];

    NSTextField *arrangementViewlabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 30, width - 100, 20)];
    arrangementViewlabel.stringValue = @"Output volume:";
    arrangementViewlabel.editable = NO;
    arrangementViewlabel.bezeled = NO;
    arrangementViewlabel.drawsBackground = NO;
    arrangementViewlabel.alignment = NSTextAlignmentLeft;
    arrangementViewlabel.font = [NSFont systemFontOfSize:13.0];
    [arrangementView addSubview:arrangementViewlabel];

    // Apply Button
    self.ApplyButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 80, 25, 60, 30)];
    [self.ApplyButton setTitle:@"Apply"];
    [self.ApplyButton setButtonType:NSSwitchButton];
    [self.ApplyButton setTarget:self];
    [self.ApplyButton setAction:@selector(ApplyButtonPressed:)];
    [arrangementView addSubview:self.ApplyButton];

    // Add Colour Management Tab
    NSTabViewItem *colourTab = [[NSTabViewItem alloc] initWithIdentifier:@"Colour"];
    [colourTab setLabel:@"Colour"];
    NSView *colorView = [[NSView alloc] initWithFrame:tabView.bounds];
    [colourTab setView:colorView];
    [tabView addTabViewItem:colourTab];

    NSTextField *colour_top_label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, generalView.bounds.size.height - 50, 300, 20)];
    colour_top_label.stringValue = @"Select a device for Sound I:";
    colour_top_label.editable = NO;
    colour_top_label.bezeled = NO;
    colour_top_label.drawsBackground = NO;
    colour_top_label.alignment = NSTextAlignmentLeft;
    colour_top_label.font = [NSFont systemFontOfSize:13.0];
    [colorView addSubview:colour_top_label];
    
    NSTextField *colourlabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 30, width - 100, 20)];
    colourlabel.stringValue = @"colour volume:";
    colourlabel.editable = NO;
    colourlabel.bezeled = NO;
    colourlabel.drawsBackground = NO;
    colourlabel.alignment = NSTextAlignmentLeft;
    colourlabel.font = [NSFont systemFontOfSize:13.0];
    [colorView addSubview:colourlabel];
}

- (void)ApplyButtonPressed:(NSButton *)sender {
/*    NSInteger selectedRow = [self.colourDeviceTableView selectedRow];
    if (selectedRow >= 0) {
        uint32_t index = self.colourDeviceIndexes[selectedRow].unsignedIntValue;
        BOOL mute = (sender.state == NSControlStateValueOn);
        pa_context_set_source_mute_by_index(self.context, index, mute, NULL, NULL);
    }*/
    NSLog(@"Apply Button Pressed");
}

@end
