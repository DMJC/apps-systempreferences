// X11Backend.cpp
extern "C" {
  #include <X11/Xlib.h>
  #include <X11/extensions/Xrandr.h>
}
#include "DisplayBackend.hpp"
#include <unordered_map>
#include <memory>
#include <sstream>

class X11Backend : public DisplayBackend {
  Display* dpy_{nullptr};
  Window root_{};
  int screen_{};
  struct Orig { RRCrtc crtc{}; RRMode mode{}; int x{}; int y{}; Rotation rot{}; };
  std::unordered_map<std::string, Orig> originals_;
public:
  X11Backend() {
    dpy_ = XOpenDisplay(nullptr);
    if (dpy_) { screen_ = DefaultScreen(dpy_); root_ = RootWindow(dpy_, screen_); }
  }
  ~X11Backend() override { if (dpy_) XCloseDisplay(dpy_); }

  std::vector<OutputInfo> listOutputs() override {
    std::vector<OutputInfo> out;
    if (!dpy_) return out;
    XRRScreenResources* res = XRRGetScreenResourcesCurrent(dpy_, root_);
    if (!res) return out;
    for (int i=0;i<res->noutput;i++) {
      XRROutputInfo* oi = XRRGetOutputInfo(dpy_, res, res->outputs[i]);
      if (!oi) continue;
      if (oi->connection != RR_Connected || oi->crtc == 0 || oi->nmode == 0) { XRRFreeOutputInfo(oi); continue; }
      XRRCrtcInfo* ci = XRRGetCrtcInfo(dpy_, res, oi->crtc);
      if (!ci) { XRRFreeOutputInfo(oi); continue; }

      OutputInfo O;
      O.name.assign(oi->name, oi->name + oi->nameLen);
      originals_[O.name] = { oi->crtc, ci->mode, ci->x, ci->y, ci->rotation };

      for (int m=0;m<oi->nmode;m++) {
        RRMode mid = oi->modes[m];
        for (int j=0;j<res->nmode;j++) if (res->modes[j].id == mid) {
          const XRRModeInfo& mi = res->modes[j];
          ModeInfo M;
          M.width = mi.width; M.height = mi.height;
          uint32_t mhz = (mi.hTotal && mi.vTotal) ? (uint64_t)mi.dotClock * 1000ull / (mi.hTotal * mi.vTotal) : 0;
          M.refresh_mHz = mhz;
          std::ostringstream os; os << mid; M.id = os.str();
          M.current = (ci->mode == mid);
          if (M.current) O.currentModeId = M.id;
          O.modes.push_back(M);
          break;
        }
      }
      out.push_back(std::move(O));
      XRRFreeCrtcInfo(ci);
      XRRFreeOutputInfo(oi);
    }
    XRRFreeScreenResources(res);
    return out;
  }

  bool setMode(const std::string& name, const std::string& modeId) override {
    if (!dpy_) return false;
    XRRScreenResources* res = XRRGetScreenResourcesCurrent(dpy_, root_);
    if (!res) return false;

    RRCrtc crtc{}; RRMode newMode{};
    int ox=0, oy=0; Rotation rot=RR_Rotate_0;
    for (int i=0;i<res->noutput;i++) {
      XRROutputInfo* oi = XRRGetOutputInfo(dpy_, res, res->outputs[i]);
      if (!oi) continue;
      std::string nm(oi->name, oi->name + oi->nameLen);
      if (nm == name && oi->crtc) {
        XRRCrtcInfo* ci = XRRGetCrtcInfo(dpy_, res, oi->crtc);
        if (ci) { crtc=oi->crtc; ox=ci->x; oy=ci->y; rot=ci->rotation; XRRFreeCrtcInfo(ci); }
        // parse RRMode id
        newMode = (RRMode)strtoull(modeId.c_str(), nullptr, 10);
        XRRFreeOutputInfo(oi);
        break;
      }
      XRRFreeOutputInfo(oi);
    }

    if (!crtc || !newMode) { XRRFreeScreenResources(res); return false; }
    Status st = XRRSetCrtcConfig(dpy_, res, crtc, CurrentTime, ox, oy, newMode, rot, nullptr, 0);
    XSync(dpy_, False);
    XRRFreeScreenResources(res);
    return st == Success;
  }

  bool revert(const std::string& name) override {
    if (!dpy_) return false;
    auto it = originals_.find(name);
    if (it == originals_.end()) return false;
    XRRScreenResources* res = XRRGetScreenResourcesCurrent(dpy_, root_);
    if (!res) return false;
    const Orig& o = it->second;
    Status st = XRRSetCrtcConfig(dpy_, res, o.crtc, CurrentTime, o.x, o.y, o.mode, o.rot, nullptr, 0);
    XSync(dpy_, False);
    XRRFreeScreenResources(res);
    return st == Success;
  }
};

// factory
std::unique_ptr<DisplayBackend> MakeX11Backend() {
  return std::unique_ptr<DisplayBackend>(new X11Backend());
}
