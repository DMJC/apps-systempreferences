#import "VideoModule.h"

@implementation VideoModule {
    NSComboBox *videoModeComboBox;
    NSButton *applyButton;
    NSMutableArray<NSString *> *videoModes;
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *modes;

    struct wl_display *display;
    struct wl_registry *registry;
    struct wl_output *output;
}

- (void)mainViewDidLoad {
    [super mainViewDidLoad];

    videoModes = [NSMutableArray array];
    modes = [NSMutableArray array];

    // Create and configure NSComboBox
    videoModeComboBox = [[NSComboBox alloc] initWithFrame:NSMakeRect(20, 100, 300, 25)];
    [videoModeComboBox setEditable:NO];
    [videoModeComboBox setUsesDataSource:NO];
    [[self mainView] addSubview:videoModeComboBox];

    // Create and configure NSButton
    applyButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 60, 100, 30)];
    [applyButton setTitle:@"Apply"];
//    [applyButton setBezelStyle:NSBezelStyleRounded];
    [applyButton setTarget:self];
    [applyButton setAction:@selector(applyVideoMode)];
    [[self mainView] addSubview:applyButton];

    // Initialize Wayland backend
    [self initializeWayland];
}

- (void)initializeWayland {
    // Connect to Wayland display
    display = wl_display_connect(NULL);
    if (!display) {
        NSLog(@"Failed to connect to Wayland display");
        return;
    }
    NSLog(@"Connected to Wayland display");

    // Get registry and add listener
    registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &(struct wl_registry_listener){
        .global = registry_global,
        .global_remove = registry_global_remove
    }, (__bridge void *)self);

    // Wait for registry events
    wl_display_roundtrip(display);
}

void registry_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    VideoModule *self = (__bridge VideoModule *)data;

    if (strcmp(interface, "wl_output") == 0) {
        self->output = wl_registry_bind(registry, name, &wl_output_interface, version);

        wl_output_add_listener(self->output, &(struct wl_output_listener){
            .geometry = output_geometry,
            .mode = output_mode,
            .done = output_done,
            .scale = output_scale
        }, (__bridge void *)self);
    }
}

void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name) {
    // Handle removal of global objects if necessary
}

void output_geometry(void *data, struct wl_output *wl_output, int32_t x, int32_t y, int32_t physical_width, int32_t physical_height, int32_t subpixel, const char *make, const char *model, int32_t transform) {
    NSLog(@"Output geometry: %s %s", make, model);
}

void output_mode(void *data, struct wl_output *wl_output, uint32_t flags, int32_t width, int32_t height, int32_t refresh) {
    VideoModule *self = (__bridge VideoModule *)data;
    NSString *modeString = [NSString stringWithFormat:@"%dx%d @ %.2fHz", width, height, refresh / 1000.0];
    [self->videoModes addObject:modeString];
    [self->modes addObject:@{@"width": @(width), @"height": @(height), @"refresh": @(refresh)}];
}

void output_done(void *data, struct wl_output *wl_output) {
    VideoModule *self = (__bridge VideoModule *)data;
    [self->videoModeComboBox removeAllItems];
    [self->videoModeComboBox addItemsWithObjectValues:self->videoModes];
}

void output_scale(void *data, struct wl_output *wl_output, int32_t factor) {
    NSLog(@"Output scale: %d", factor);
}

- (void)applyVideoMode {
    NSInteger selectedIndex = [videoModeComboBox indexOfSelectedItem];
    if (selectedIndex < 0 || selectedIndex >= modes.count) {
        NSLog(@"No mode selected");
        return;
    }

    NSDictionary<NSString *, NSNumber *> *selectedMode = modes[selectedIndex];
    int32_t width = [selectedMode[@"width"] intValue];
    int32_t height = [selectedMode[@"height"] intValue];
    int32_t refresh = [selectedMode[@"refresh"] intValue];

    NSLog(@"Applying mode: %dx%d @ %.2fHz", width, height, refresh / 1000.0);
    // Implement mode setting using Wayland protocol (requires wl_output protocol extensions)
}

@end
