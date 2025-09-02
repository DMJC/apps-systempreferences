// WaylandBackend.cpp - wlr-randr based backend
#include "DisplayBackend.hpp"
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <sstream>
#include <unordered_map>

class WaylandBackend : public DisplayBackend {
  std::unordered_map<std::string,std::string> originals_;
public:
  WaylandBackend() { std::fprintf(stderr, "[WaylandBackend] init\n"); }
  ~WaylandBackend() override { std::fprintf(stderr, "[WaylandBackend] destroy\n"); }

  std::vector<OutputInfo> listOutputs() override {
    std::fprintf(stderr, "[WaylandBackend] listOutputs\n");
    std::vector<OutputInfo> outs;
    FILE* fp = popen("wlr-randr", "r");
    if (!fp) return outs;
    char buf[256];
    OutputInfo cur;
    while (fgets(buf, sizeof(buf), fp)) {
      std::string line(buf);
      if (!line.empty() && line.back()=='\n') line.pop_back();
      if (line.empty()) continue;
      if (line[0] != ' ' && line[0] != '\t') {
        if (!cur.name.empty()) { outs.push_back(cur); cur = OutputInfo(); }
        std::istringstream iss(line);
        iss >> cur.name; // first token is output name
      } else {
        line.erase(0, line.find_first_not_of(" \t"));
        bool current = false;
        if (!line.empty() && line[0]=='*') { current=true; line.erase(0,1); }
        unsigned w=0,h=0; double hz=0.0;
        if (sscanf(line.c_str(), "%ux%u@%lf", &w,&h,&hz)==3) {
          ModeInfo mi; mi.width=w; mi.height=h; mi.refresh_mHz=(uint32_t)(hz*1000.0+0.5);
          std::ostringstream id; id<<w<<"x"<<h<<"@"<<mi.refresh_mHz; mi.id=id.str();
          mi.current=current; if (current) cur.currentModeId=mi.id;
          cur.modes.push_back(mi);
        }
      }
    }
    if (!cur.name.empty()) outs.push_back(cur);
    pclose(fp);
    originals_.clear();
    for (const auto& o : outs) originals_[o.name]=o.currentModeId;
    return outs;
  }

  bool setMode(const std::string& name, const std::string& modeId) override {
    std::fprintf(stderr, "[WaylandBackend] setMode %s -> %s\n", name.c_str(), modeId.c_str());
    unsigned w=0,h=0; unsigned mhz=0;
    if (sscanf(modeId.c_str(), "%ux%u@%u", &w,&h,&mhz)!=3) return false;
    std::ostringstream cmd; cmd<<"wlr-randr --output "<<name<<" --mode "<<w<<"x"<<h<<"@"<<(mhz/1000.0);
    int rc = std::system(cmd.str().c_str());
    return rc==0;
  }

  bool revert(const std::string& name) override {
    std::fprintf(stderr, "[WaylandBackend] revert %s\n", name.c_str());
    auto it = originals_.find(name);
    if (it==originals_.end()) return false;
    return setMode(name, it->second);
  }
};

std::unique_ptr<DisplayBackend> MakeWaylandBackend() {
  std::fprintf(stderr, "[Factory] MakeWaylandBackend\n");
  return std::unique_ptr<DisplayBackend>(new WaylandBackend());
}
