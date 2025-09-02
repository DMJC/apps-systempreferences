#import "VideoModule.h"
#import <AppKit/AppKit.h>
#import "DisplayBackend.hpp"
#import "DisplayBackendFactory.hpp"

#import <vector>
#import <memory>
#import <utility>
#import <string>
#import <cstdlib>
#import <algorithm>
#import <cmath>

static inline NSString* ns(const std::string& s) {
  return [[NSString alloc] initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding];
}

static inline NSString* modeString(const ModeInfo& mi) {
  double hz = mi.refresh_mHz / 1000.0;
  return [NSString stringWithFormat:@"%ux%u@%.0f", mi.width, mi.height, std::round(hz)];
}

struct OutputModel {
  OutputInfo info;          // data from backend
  std::string pendingMode;  // id of selected mode not yet applied
};

@interface VideoModule () <NSTableViewDataSource, NSTableViewDelegate>
{
  std::unique_ptr<DisplayBackend> _backend;
  std::vector<OutputModel> _outputs;
  NSInteger _selectedOutputRow;
}
@property (nonatomic, strong) NSTimer *revertTimer;
@end

@implementation VideoModule

- (instancetype)initWithBundle:(NSBundle *)bundle {
  if ((self = [super initWithBundle:bundle])) {
    _selectedOutputRow = -1;
  }
  return self;
}

- (void)buildUIInto:(NSView *)content {
  // Devices table
  if (!self.deviceTableView) {
    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(12, 200, 180, 200)];
    self.deviceTableView = [[NSTableView alloc] initWithFrame:[sv bounds]];
    NSTableColumn *cName = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    cName.title = @"Display (Output)"; cName.width = 160;
    [self.deviceTableView addTableColumn:cName];
    self.deviceTableView.delegate = (id)self;
    self.deviceTableView.dataSource = (id)self;
    [sv setDocumentView:self.deviceTableView]; sv.hasVerticalScroller = YES;
    [content addSubview:sv];
  }

  // Modes table
  if (!self.outputDeviceTableView) {
    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(200, 200, 202, 200)];
    self.outputDeviceTableView = [[NSTableView alloc] initWithFrame:[sv bounds]];
    NSTableColumn *m = [[NSTableColumn alloc] initWithIdentifier:@"mode"];
    m.title=@"Resolution @Hz"; m.width=100;
    NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:@"current"];
    c.title=@"Current"; c.width=90;
    NSTableColumn *p = [[NSTableColumn alloc] initWithIdentifier:@"pending"];
    p.title=@"Pending"; p.width=90;
    [self.outputDeviceTableView addTableColumn:m];
    self.outputDeviceTableView.delegate = (id)self;
    self.outputDeviceTableView.dataSource = (id)self;
    self.outputDeviceTableView.allowsEmptySelection = NO;
    [sv setDocumentView:self.outputDeviceTableView]; sv.hasVerticalScroller = YES;
    [content addSubview:sv];
  }

  // Details table
  if (!self.inputDeviceTableView) {
    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(12, 48, 696, 120)];
    self.inputDeviceTableView = [[NSTableView alloc] initWithFrame:[sv bounds]];
    NSTableColumn *d = [[NSTableColumn alloc] initWithIdentifier:@"detail"];
    d.title=@"Property"; d.width=250;
    NSTableColumn *v = [[NSTableColumn alloc] initWithIdentifier:@"value"];
    v.title=@"Value"; v.width=420;
    [self.inputDeviceTableView addTableColumn:d];
    [self.inputDeviceTableView addTableColumn:v];
    self.inputDeviceTableView.delegate = (id)self;
    self.inputDeviceTableView.dataSource = (id)self;
    [sv setDocumentView:self.inputDeviceTableView]; sv.hasVerticalScroller = YES;
    [content addSubview:sv];
  }

  // Apply button
  if (!self.ApplyButton) {
    self.ApplyButton = [[NSButton alloc] initWithFrame:NSMakeRect(470, 5, 96, 28)];
    self.ApplyButton.title = @"Apply";
    self.ApplyButton.bezelStyle = NSRoundedBezelStyle;
    self.ApplyButton.target = self;
    self.ApplyButton.action = @selector(onApply:);
    [content addSubview:self.ApplyButton];
  }
}

- (NSView *)mainView {
  NSView *v = [super mainView];
  if (!v) {
    v = [[NSView alloc] initWithFrame:NSMakeRect(0,0,720,420)];
    [super setMainView:v];
    [self buildUIInto:v];
    [self openDisplayAndLoad];
  }
  return v;
}

- (void)mainViewDidLoad {
  NSView *content = [self mainView];
  if (!content) {
    content = [[NSView alloc] initWithFrame:NSMakeRect(0,0,720,420)];
    [self setMainView:content];
  }
  [self buildUIInto:content];
  [self openDisplayAndLoad];
}

- (void)openDisplayAndLoad {
  bool isWayland = getenv("WAYLAND_DISPLAY") != nullptr;
  NSLog(@"VideoModule: openDisplayAndLoad using %@ backend", isWayland?@"Wayland":@"X11");
  _backend = isWayland ? MakeWaylandBackend() : MakeX11Backend();
  _outputs.clear();
  if (_backend) {
    for (auto &out : _backend->listOutputs()) {
      OutputModel m;
      m.info = out;
      m.pendingMode.clear();
      _outputs.push_back(std::move(m));
    }
  }
  [self.deviceTableView reloadData];
  [self.outputDeviceTableView reloadData];
  [self.inputDeviceTableView reloadData];
  if (!_outputs.empty()) {
    _selectedOutputRow = 0;
    [self.deviceTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
  }
}

#pragma mark - Revert / Apply

- (void)startRevertTimer {
  [self.revertTimer invalidate];
  self.revertTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                      target:self
                                                    selector:@selector(onRevert:)
                                                    userInfo:nil
                                                     repeats:NO];
}

- (void)onRevert:(NSTimer*)t {
  if (!_backend) return;
  for (auto &e : _outputs) {
    if (!e.pendingMode.empty() && e.pendingMode != e.info.currentModeId) {
      _backend->revert(e.info.name);
      e.pendingMode.clear();
    }
  }
  [self.outputDeviceTableView reloadData];
  [self.inputDeviceTableView reloadData];
}

- (IBAction)onApply:(id)sender {
  NSLog(@"VideoModule: onApply");
  if (!_backend) return;
  for (auto &e : _outputs) {
    if (!e.pendingMode.empty() && e.pendingMode != e.info.currentModeId) {
      if (_backend->setMode(e.info.name, e.pendingMode)) {
        e.info.currentModeId = e.pendingMode;
      }
      e.pendingMode.clear();
    }
  }
  [self.revertTimer invalidate];
  self.revertTimer = nil;
  [self.outputDeviceTableView reloadData];
  [self.inputDeviceTableView reloadData];
}

#pragma mark - NSTableView Data Source / Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
  if (tv == self.deviceTableView) return (NSInteger)_outputs.size();
  if (tv == self.outputDeviceTableView) {
    if (_selectedOutputRow < 0 || _selectedOutputRow >= (NSInteger)_outputs.size()) return 0;
    return (NSInteger)_outputs[(size_t)_selectedOutputRow].info.modes.size();
  }
  if (tv == self.inputDeviceTableView) return 2;
  return 0;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
  if (tv == self.deviceTableView) {
    const auto &e = _outputs[(size_t)row].info;
    if ([col.identifier isEqual:@"name"]) return ns(e.name);
  } else if (tv == self.outputDeviceTableView) {
    const auto &e = _outputs[(size_t)_selectedOutputRow];
    const ModeInfo &mi = e.info.modes[(size_t)row];
    if ([col.identifier isEqual:@"mode"])    return modeString(mi);
    if ([col.identifier isEqual:@"current"]) return (mi.id == e.info.currentModeId) ? @"●" : @"";
    if ([col.identifier isEqual:@"pending"]) return (mi.id == e.pendingMode)  ? @"●" : @"";
  } else if (tv == self.inputDeviceTableView) {
    const auto &e = _outputs[(size_t)_selectedOutputRow];
    if (row == 0) return @"Current Mode";
    if (row == 1) {
      NSString *m = @"";
      for (const auto &mi : e.info.modes) if (mi.id == e.info.currentModeId) { m = modeString(mi); break; }
      return m;
    }
  }
  return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)note {
  NSTableView *tv = note.object;
  if (tv == self.deviceTableView) {
    _selectedOutputRow = tv.selectedRow;
    [self.outputDeviceTableView reloadData];
    [self.inputDeviceTableView reloadData];
  } else if (tv == self.outputDeviceTableView) {
    if (_selectedOutputRow < 0 || _selectedOutputRow >= (NSInteger)_outputs.size()) return;
    auto &e = _outputs[(size_t)_selectedOutputRow];
    NSInteger row = tv.selectedRow;
    if (row < 0 || row >= (NSInteger)e.info.modes.size()) return;
    e.pendingMode = e.info.modes[(size_t)row].id;
    [self.outputDeviceTableView reloadData];
    [self.inputDeviceTableView reloadData];
    [self startRevertTimer];
  }
}

- (void)dealloc {
}

@end

