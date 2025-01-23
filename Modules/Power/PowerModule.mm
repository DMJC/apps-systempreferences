#import "PowerModule.h"

@implementation PowerManagementPane

- (instancetype)initWithBundle:(NSBundle *)bundle {
    self = [super initWithBundle:bundle];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    mainView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];

    sliderLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 240, 360, 20)];
    [sliderLabel setStringValue:@"Set computer sleep time:"];
    [sliderLabel setBezeled:NO];
    [sliderLabel setDrawsBackground:NO];
    [sliderLabel setEditable:NO];
    [sliderLabel setSelectable:NO];
    [mainView addSubview:sliderLabel];

    sleepSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(20, 210, 360, 20)];
    [sleepSlider setMinValue:1];
    [sleepSlider setMaxValue:180];
    [sleepSlider setNumberOfTickMarks:7];
    [sleepSlider setAllowsTickMarkValuesOnly:YES];
    [mainView addSubview:sleepSlider];

    sliderValuesLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 190, 360, 20)];
    [sliderValuesLabel setStringValue:@"1m       15m       30m       1h       2h       3h       Never"];
    [sliderValuesLabel setAlignment:NSTextAlignmentCenter];
    [sliderValuesLabel setBezeled:NO];
    [sliderValuesLabel setDrawsBackground:NO];
    [sliderValuesLabel setEditable:NO];
    [sliderValuesLabel setSelectable:NO];
    [mainView addSubview:sliderValuesLabel];

    preventSleepCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 180, 360, 20)];
    [preventSleepCheckbox setButtonType:NSSwitchButton];
    [preventSleepCheckbox setTitle:@"Prevent computer from sleeping automatically when the display is off"];
    [mainView addSubview:preventSleepCheckbox];

    putDisksToSleepCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 150, 360, 20)];
    [putDisksToSleepCheckbox setButtonType:NSSwitchButton];
    [putDisksToSleepCheckbox setTitle:@"Put hard disks to sleep when possible"];
    [mainView addSubview:putDisksToSleepCheckbox];

    wakeForNetworkCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 120, 360, 20)];
    [wakeForNetworkCheckbox setButtonType:NSSwitchButton];
    [wakeForNetworkCheckbox setTitle:@"Wake for Ethernet network access"];
    [mainView addSubview:wakeForNetworkCheckbox];

    startupAfterPowerFailureCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 90, 360, 20)];
    [startupAfterPowerFailureCheckbox setButtonType:NSSwitchButton];
    [startupAfterPowerFailureCheckbox setTitle:@"Start up automatically after a power failure"];
    [mainView addSubview:startupAfterPowerFailureCheckbox];

    enablePowerNapCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 60, 360, 20)];
    [enablePowerNapCheckbox setButtonType:NSSwitchButton];
    [enablePowerNapCheckbox setTitle:@"Enable Power Nap"];
    [mainView addSubview:enablePowerNapCheckbox];

    restoreDefaultsButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 20, 150, 30)];
    [restoreDefaultsButton setTitle:@"Restore Defaults"];
    [restoreDefaultsButton setTarget:self];
    [restoreDefaultsButton setAction:@selector(restoreDefaults)];
    [mainView addSubview:restoreDefaultsButton];

    scheduleButton = [[NSButton alloc] initWithFrame:NSMakeRect(230, 20, 150, 30)];
    [scheduleButton setTitle:@"Schedule..."];
    [scheduleButton setTarget:self];
    [scheduleButton setAction:@selector(openScheduleDialog)];
    [mainView addSubview:scheduleButton];
}

- (void)restoreDefaults {
    [sleepSlider setDoubleValue:30];
    [preventSleepCheckbox setState:NSControlStateValueOff];
    [putDisksToSleepCheckbox setState:NSControlStateValueOn];
    [wakeForNetworkCheckbox setState:NSControlStateValueOn];
    [startupAfterPowerFailureCheckbox setState:NSControlStateValueOff];
    [enablePowerNapCheckbox setState:NSControlStateValueOn];
}

- (void)openScheduleDialog {
    // Placeholder for schedule dialog
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Schedule power management tasks"];
    [alert runModal];
}

- (NSView *)mainView {
    return mainView;
}

@end
