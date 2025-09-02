// WaylandBackend.cpp (debug stub)
#include "DisplayBackend.hpp"
#include <cstdio>
#include <memory>

class WaylandBackend : public DisplayBackend {
public:
  WaylandBackend() { std::fprintf(stderr, "[WaylandBackend] init\n"); }
  ~WaylandBackend() override { std::fprintf(stderr, "[WaylandBackend] destroy\n"); }

  std::vector<OutputInfo> listOutputs() override {
    std::fprintf(stderr, "[WaylandBackend] listOutputs\n");
    return {};
  }

  bool setMode(const std::string& outputName, const std::string& modeId) override {
    std::fprintf(stderr, "[WaylandBackend] setMode %s -> %s\n", outputName.c_str(), modeId.c_str());
    return false;
  }

  bool revert(const std::string& outputName) override {
    std::fprintf(stderr, "[WaylandBackend] revert %s\n", outputName.c_str());
    return false;
  }
};

std::unique_ptr<DisplayBackend> MakeWaylandBackend() {
  std::fprintf(stderr, "[Factory] MakeWaylandBackend\n");
  return std::unique_ptr<DisplayBackend>(new WaylandBackend());
}
