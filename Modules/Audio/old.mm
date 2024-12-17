#import <Cocoa/Cocoa.h>
#include <pulse/pulseaudio.h>
#import <GNUstepBase/GSPreferencesModule.h>

@interface AppDelegate : NSObject <GSPreferencesModule, NSTableViewDelegate, NSTableViewDataSource>
@property (strong) NSTableView *deviceTableView;
@property (strong) NSSlider *volumeSlider;
@property (nonatomic) pa_mainloop *mainloop;
@property (nonatomic) pa_context *context;
@property (nonatomic, strong) NSMutableArray<NSString *> *deviceNames;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *deviceIndexes;
@property (nonatomic, strong) NSButton *muteButton;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.deviceNames = [NSMutableArray array];
    self.deviceIndexes = [NSMutableArray array];

    [self setupPulseAudio];
    [self setupUI];
}

- (void)setupUI {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300)
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskResizable | NSWindowStyleMaskClosable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setTitle:@"PulseAudio Volume Control"];
    [self.window makeKeyAndOrderFront:nil];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 100, 380, 150)];
    self.deviceTableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
    [self.deviceTableView setDelegate:self];
    [self.deviceTableView setDataSource:self];

    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"DeviceColumn"];
    [column setTitle:@"Input Devices"];
    [self.deviceTableView addTableColumn:column];

    [scrollView setDocumentView:self.deviceTableView];
    [scrollView setHasVerticalScroller:YES];
    [[self.window contentView] addSubview:scrollView];

    self.volumeSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(10, 50, 380, 40)];
    [self.volumeSlider setMinValue:0.0];
    [self.volumeSlider setMaxValue:100.0];
    [self.volumeSlider setTarget:self];
    [self.volumeSlider setAction:@selector(sliderValueChanged:)];
    [[self.window contentView] addSubview:self.volumeSlider];

    self.muteButton = [[NSButton alloc] initWithFrame:NSMakeRect(150, 10, 80, 30)];
    [self.muteButton setTitle:@"Mute"];
    [self.muteButton setButtonType:NSSwitchButton];
    [self.muteButton setTarget:self];
    [self.muteButton setAction:@selector(muteButtonPressed:)];
    [self.window.contentView addSubview:self.muteButton];
}

- (void)setupPulseAudio {
    self.mainloop = pa_mainloop_new();
    self.context = pa_context_new(pa_mainloop_get_api(self.mainloop), "VolumeControlApp");

    pa_context_connect(self.context, NULL, PA_CONTEXT_NOFLAGS, NULL);
    pa_context_set_state_callback(self.context, context_state_callback, (__bridge void *)self);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        pa_mainloop_run(self.mainloop, NULL);
    });
}

- (void)updateDeviceList {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.deviceTableView reloadData];
    });
}

- (void)sliderValueChanged:(NSSlider *)sender {
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    if (selectedRow >= 0) {
        uint32_t index = self.deviceIndexes[selectedRow].unsignedIntValue;
        pa_cvolume volume;
        pa_cvolume_set(&volume, 2, (uint32_t)(sender.doubleValue * PA_VOLUME_NORM / 100.0));
        pa_context_set_source_volume_by_index(self.context, index, &volume, NULL, NULL);
    }
}

- (void)muteButtonPressed:(NSButton *)sender {
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    if (selectedRow >= 0) {
        uint32_t index = self.deviceIndexes[selectedRow].unsignedIntValue;
        BOOL mute = (sender.state == NSControlStateValueOn);
        // Set mute state for the selected input device (source)
        pa_context_set_source_mute_by_index(self.context, index, mute, NULL, NULL);
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.deviceNames.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return self.deviceNames[row];
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = [self.deviceTableView selectedRow];
    if (selectedRow >= 0) {
        uint32_t index = self.deviceIndexes[selectedRow].unsignedIntValue;
        pa_context_get_source_info_by_index(self.context, index, source_info_callback, (__bridge void *)self);
    }
}

#pragma mark - PulseAudio Callbacks

static void context_state_callback(pa_context *context, void *userdata) {
    if (pa_context_get_state(context) == PA_CONTEXT_READY) {
        // Fetch input devices (sources) instead of output devices
        pa_context_get_source_info_list(context, source_list_callback, userdata);
    }
}

/*
static void context_state_callback(pa_context *context, void *userdata) {
    if (pa_context_get_state(context) == PA_CONTEXT_READY) {
        pa_context_get_sink_info_list(context, sink_list_callback, userdata);
    }
}
*/

// Fetch individual source (input device) info
static void source_info_callback(pa_context *context, const pa_source_info *info, int eol, void *userdata) {
    if (eol > 0) return; // End of info
    AppDelegate *self = (__bridge AppDelegate *)userdata;
    dispatch_async(dispatch_get_main_queue(), ^{
        uint32_t avg_volume = pa_cvolume_avg(&info->volume);
        self.volumeSlider.doubleValue = (avg_volume * 100.0) / PA_VOLUME_NORM;
        [self.muteButton setState:(info->mute ? NSControlStateValueOn : NSControlStateValueOff)];
    });
}


// Fetch list of sources (input devices)
static void source_list_callback(pa_context *context, const pa_source_info *info, int eol, void *userdata) {
    if (eol > 0) return; // End of list
    AppDelegate *self = (__bridge AppDelegate *)userdata;
    [self.deviceNames addObject:[NSString stringWithUTF8String:info->description]];
    [self.deviceIndexes addObject:@(info->index)];
    [self updateDeviceList];
}

static void sink_list_callback(pa_context *context, const pa_sink_info *info, int eol, void *userdata) {
    if (eol > 0) return;
    AppDelegate *self = (__bridge AppDelegate *)userdata;
    [self.deviceNames addObject:[NSString stringWithUTF8String:info->description]];
    [self.deviceIndexes addObject:@(info->index)];
    [self updateDeviceList];
}

static void sink_info_callback(pa_context *context, const pa_sink_info *info, int eol, void *userdata) {
    if (eol > 0) return;
    AppDelegate *self = (__bridge AppDelegate *)userdata;
    dispatch_async(dispatch_get_main_queue(), ^{
        uint32_t avg_volume = pa_cvolume_avg(&info->volume);
        self.volumeSlider.doubleValue = (avg_volume * 100.0) / PA_VOLUME_NORM;
    });
}

@end
