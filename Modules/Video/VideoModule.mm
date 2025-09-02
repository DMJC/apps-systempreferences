#import "VideoModule.h"
#import <AppKit/AppKit.h>

extern "C" {
  #include <X11/Xlib.h>
  #include <X11/extensions/Xrandr.h>
}

#import <vector>
#import <memory>
#import <algorithm>
#import <string>
#import <cmath>

// ---------- RAII deleters ----------
struct XRRScreenResourcesDeleter {
  void operator()(XRRScreenResources* p) const noexcept { if (p) XRRFreeScreenResources(p); }
};
struct XRROutputInfoDeleter {
  void operator()(XRROutputInfo* p) const noexcept { if (p) XRRFreeOutputInfo(p); }
};
struct XRRCrtcInfoDeleter {
  void operator()(XRRCrtcInfo* p) const noexcept { if (p) XRRFreeCrtcInfo(p); }
};

using ScreenResPtr = std::unique_ptr<XRRScreenResources, XRRScreenResourcesDeleter>;
using OutputInfoPtr = std::unique_ptr<XRROutputInfo, XRROutputInfoDeleter>;
using CrtcInfoPtr   = std::unique_ptr<XRRCrtcInfo,   XRRCrtcInfoDeleter>;

// ---------- C++ model ----------
struct ModeId { RRMode id{}; };
struct OutputModel {
  RROutput output{};
  RRCrtc   crtc{};
  RRMode   originalMode{};
  int      originalX{};
  int      originalY{};
  Rotation originalRotation{};
  RRMode   pendingMode{};              // 0 if none
  std::string name;
  std::vector<ModeId> modes;
};

static inline std::string toStdString(const char* bytes, int len) {
    if (!bytes || len <= 0) return {};
    return std::string(bytes, static_cast<size_t>(len));
}

/*static inline std::string toStdString(const unsigned char* bytes, int len) {
  if (!bytes || len <= 0) return {};
  return std::string(reinterpret_cast<const char*>(bytes), static_cast<size_t>(len));
}*/
static inline NSString* ns(const std::string& s) {
  return [[NSString alloc] initWithBytes:s.data() length:s.size() encoding:NSUTF8StringEncoding];
}
static inline NSString* modeString(const XRRModeInfo& mi) {
  double hz = 0.0;
  if (mi.hTotal && mi.vTotal) hz = double(mi.dotClock) / double(mi.hTotal * mi.vTotal);
  return [NSString stringWithFormat:@"%ux%u@%.0f", mi.width, mi.height, std::round(hz)];
}

// ---------- Class extension ----------
// If your header already declares these outlets, this redeclaration is fine in a class extension.
@interface VideoModule () <NSTableViewDataSource, NSTableViewDelegate>
{
  // No brace initializers here; assign in -initWithBundle:
  Display       *_dpy;
  Window         _root;
  int            _screen;
  ScreenResPtr   _res;

  std::vector<OutputModel> _outputs;
  NSInteger     _selectedOutputRow;
}
@property (nonatomic, strong) NSTimer *revertTimer;
@property (nonatomic, strong) NSArray<NSString *> *scaleValues;
// Outlets (provide here if not in header; safe to duplicate as 'strong')
@end

@implementation VideoModule

// Add near the top of @implementation
- (void)buildUIInto:(NSView *)content
{
  // --- Devices table
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

  // --- Modes table
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

  // --- Details table
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

  // --- Apply button
  if (!self.ApplyButton) {
    self.ApplyButton = [[NSButton alloc] initWithFrame:NSMakeRect(470, 5, 96, 28)];
    self.ApplyButton.title = @"Apply";
    self.ApplyButton.bezelStyle = NSRoundedBezelStyle;
    self.ApplyButton.target = self;
    self.ApplyButton.action = @selector(onApply:);
    [content addSubview:self.ApplyButton];
  }
}

// NEW: override mainView (GNUstep/SystemPreferences asks this first)
- (NSView *)mainView
{
  NSView *v = [super mainView];
  if (!v) {
    v = [[NSView alloc] initWithFrame:NSMakeRect(0,0,720,420)];
    [super setMainView:v];
    [self buildUIInto:v];        // build widgets
    [self openDisplayAndLoad];   // populate data
  }
  return v;
}

- (instancetype)initWithBundle:(NSBundle *)bundle {
  if ((self = [super initWithBundle:bundle])) {
    _dpy = nullptr;
    _root = 0;
    _screen = 0;
    _res.reset();        // empty unique_ptr
    _outputs.clear();
    _selectedOutputRow = -1;
  }
  return self;
}

- (void)mainViewDidLoad {
  NSView *content = [self mainView];
  if (!content) {
    content = [[NSView alloc] initWithFrame:NSMakeRect(0,0,720,420)];
    [self setMainView:content];
  }

  // Devices table
  if (!self.deviceTableView) {
    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(12, 200, 280, 200)];
    self.deviceTableView = [[NSTableView alloc] initWithFrame:[sv bounds]];
    NSTableColumn *cName = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    cName.title = @"Display (Output)"; cName.width = 260;
    [self.deviceTableView addTableColumn:cName];
    self.deviceTableView.delegate = (id)self;
    self.deviceTableView.dataSource = (id)self;
    [sv setDocumentView:self.deviceTableView]; sv.hasVerticalScroller = YES;
    [content addSubview:sv];
  }

  // Modes table
  if (!self.outputDeviceTableView) {
    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(306, 200, 402, 200)];
    self.outputDeviceTableView = [[NSTableView alloc] initWithFrame:[sv bounds]];
    auto addCol = ^(NSString *ident, NSString *title, CGFloat w) {
      NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:ident];
      col.title = title; col.width = w;
      [self.outputDeviceTableView addTableColumn:col];
    };
    addCol(@"mode", @"Resolution @Hz", 200);
    addCol(@"current", @"Current", 90);
    addCol(@"pending", @"Pending", 90);
    self.outputDeviceTableView.delegate = (id)self;
    self.outputDeviceTableView.dataSource = (id)self;
    self.outputDeviceTableView.allowsEmptySelection = NO;
    [sv setDocumentView:self.outputDeviceTableView]; sv.hasVerticalScroller = YES;
    [content addSubview:sv];
  }

  // Details table
  if (!self.inputDeviceTableView) {
    NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSMakeRect(12, 12, 696, 170)];
    self.inputDeviceTableView = [[NSTableView alloc] initWithFrame:[sv bounds]];
    auto addCol = ^(NSString *ident, NSString *title, CGFloat w) {
      NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:ident];
      col.title = title; col.width = w;
      [self.inputDeviceTableView addTableColumn:col];
    };
    addCol(@"detail", @"Property", 250);
    addCol(@"value",  @"Value",    420);
    self.inputDeviceTableView.delegate = (id)self;
    self.inputDeviceTableView.dataSource = (id)self;
    [sv setDocumentView:self.inputDeviceTableView]; sv.hasVerticalScroller = YES;
    [content addSubview:sv];
  }

  // Apply button
  if (!self.ApplyButton) {
    self.ApplyButton = [[NSButton alloc] initWithFrame:NSMakeRect(612, 380, 96, 28)];
    self.ApplyButton.title = @"Apply";
    self.ApplyButton.bezelStyle = NSRoundedBezelStyle;
    self.ApplyButton.target = self;
    self.ApplyButton.action = @selector(onApply:);
    [content addSubview:self.ApplyButton];
  }

  [self openDisplayAndLoad];
}

#pragma mark - RandR

- (void)openDisplayAndLoad {
  _dpy = XOpenDisplay(nullptr);
  if (!_dpy) { NSBeep(); return; }
  _screen = DefaultScreen(_dpy);
  _root   = RootWindow(_dpy, _screen);

  int maj=0, min=0;
  if (!XRRQueryVersion(_dpy, &maj, &min) || (maj < 1 || (maj == 1 && min < 3))) { NSBeep(); return; }

  _res.reset(XRRGetScreenResourcesCurrent(_dpy, _root));
  if (!_res) { NSBeep(); return; }

  _outputs.clear();
  _outputs.reserve(_res->noutput);

  for (int i = 0; i < _res->noutput; i++) {
    OutputInfoPtr oi(XRRGetOutputInfo(_dpy, _res.get(), _res->outputs[i]));
    if (!oi) continue;
    if (oi->connection != RR_Connected || oi->crtc == 0 || oi->nmode == 0) continue;

    CrtcInfoPtr ci(XRRGetCrtcInfo(_dpy, _res.get(), oi->crtc));
    if (!ci) continue;

    OutputModel e;
    e.output = _res->outputs[i];
    e.crtc   = oi->crtc;
    e.originalMode = ci->mode;
    e.originalX = ci->x; e.originalY = ci->y;
    e.originalRotation = ci->rotation;
    e.name = toStdString(oi->name, oi->nameLen);
    e.modes.reserve(oi->nmode);
    for (int m = 0; m < oi->nmode; m++) e.modes.push_back(ModeId{oi->modes[m]});

    _outputs.push_back(std::move(e));
  }

  [self.deviceTableView reloadData];
  [self.outputDeviceTableView reloadData];
  [self.inputDeviceTableView reloadData];

  if (!_outputs.empty()) {
    _selectedOutputRow = 0;
    [self.deviceTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
  }
}

- (XRRModeInfo)modeInfoForId:(RRMode)mode {
  for (int i = 0; i < _res->nmode; i++) if (_res->modes[i].id == mode) return _res->modes[i];
  XRRModeInfo z{}; return z;
}

- (BOOL)applyMode:(RRMode)newMode forIndex:(NSInteger)idx {
  if (idx < 0 || idx >= (NSInteger)_outputs.size()) return NO;
  auto &e = _outputs[(size_t)idx];

  CrtcInfoPtr ci(XRRGetCrtcInfo(_dpy, _res.get(), e.crtc));
  if (!ci) return NO;

  Status st = XRRSetCrtcConfig(_dpy, _res.get(), e.crtc, CurrentTime,
                               ci->x, ci->y, newMode, ci->rotation,
                               ci->outputs, ci->noutput);
  XSync(_dpy, False);
  return (st == Success);
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
  for (auto &e : _outputs) {
    if (e.pendingMode != 0 && e.pendingMode != e.originalMode) {
      CrtcInfoPtr ci(XRRGetCrtcInfo(_dpy, _res.get(), e.crtc));
      if (ci) {
        XRRSetCrtcConfig(_dpy, _res.get(), e.crtc, CurrentTime,
                         e.originalX, e.originalY, e.originalMode, e.originalRotation,
                         ci->outputs, ci->noutput);
        XSync(_dpy, False);
      }
      e.pendingMode = 0;
    }
  }
  [self.outputDeviceTableView reloadData];
  [self.inputDeviceTableView reloadData];
}

- (IBAction)onApply:(id)sender {
  for (auto &e : _outputs) {
    if (e.pendingMode != 0 && e.pendingMode != e.originalMode) {
      e.originalMode = e.pendingMode;
      CrtcInfoPtr ci(XRRGetCrtcInfo(_dpy, _res.get(), e.crtc));
      if (ci) { e.originalX = ci->x; e.originalY = ci->y; e.originalRotation = ci->rotation; }
      e.pendingMode = 0;
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
    return (NSInteger)_outputs[(size_t)_selectedOutputRow].modes.size();
  }
  if (tv == self.inputDeviceTableView) return 4;
  return 0;
}

- (id)tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
  if (tv == self.deviceTableView) {
    const auto &e = _outputs[(size_t)row];
    if ([col.identifier isEqual:@"name"]) return ns(e.name);
  } else if (tv == self.outputDeviceTableView) {
    const auto &e = _outputs[(size_t)_selectedOutputRow];
    RRMode mid = e.modes[(size_t)row].id;
    XRRModeInfo mi = [self modeInfoForId:mid];
    if ([col.identifier isEqual:@"mode"])    return modeString(mi);
    if ([col.identifier isEqual:@"current"]) return (mid == e.originalMode) ? @"●" : @"";
    if ([col.identifier isEqual:@"pending"]) return (mid == e.pendingMode)  ? @"●" : @"";
  } else if (tv == self.inputDeviceTableView) {
    if (_selectedOutputRow < 0 || _selectedOutputRow >= (NSInteger)_outputs.size()) return @"";
    const auto &e = _outputs[(size_t)_selectedOutputRow];
    switch (row) {
      case 0: return [col.identifier isEqual:@"detail"] ? @"Output"     : ns(e.name);
      case 1: {
        if ([col.identifier isEqual:@"detail"]) return @"Current";
        XRRModeInfo mi = [self modeInfoForId:e.originalMode];
        return modeString(mi);
      }
      case 2: {
        if ([col.identifier isEqual:@"detail"]) return @"Pending";
        if (e.pendingMode == 0) return @"—";
        XRRModeInfo mi = [self modeInfoForId:e.pendingMode];
        return modeString(mi);
      }
      case 3: {
        if ([col.identifier isEqual:@"detail"]) return @"Auto-revert";
        return self.revertTimer ? @"In 10s (tap Apply to keep)" : @"Inactive";
      }
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
    if (row < 0 || row >= (NSInteger)e.modes.size()) return;

    RRMode mid = e.modes[(size_t)row].id;
    if ([self applyMode:mid forIndex:_selectedOutputRow]) {
      e.pendingMode = mid;
      [self startRevertTimer];
      [self.outputDeviceTableView reloadData];
      [self.inputDeviceTableView reloadData];
    } else {
      NSBeep();
      [tv deselectRow:row];
    }
  }
}

- (void)dealloc {
  if (_dpy) XCloseDisplay(_dpy);
}

@end
