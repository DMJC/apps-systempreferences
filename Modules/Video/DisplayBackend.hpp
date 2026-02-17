// DisplayBackend.hpp
#pragma once
#include <string>
#include <vector>
#include <functional>
#include <stdint.h>

struct ModeInfo {
  uint32_t width{};
  uint32_t height{};
  uint32_t refresh_mHz{};   // millihertz, e.g. 60000 = 60.0 Hz
  std::string id;           // backend-specific (RRMode as string or wl mode key)
  bool current{false};
};

struct OutputInfo {
  std::string name;
  std::vector<ModeInfo> modes;
  std::string currentModeId;  // id of current mode
};

class DisplayBackend {
public:
  virtual ~DisplayBackend() = default;

  // Enumerate outputs + modes
  virtual std::vector<OutputInfo> listOutputs() = 0;

  // Apply a mode to an output; return true if compositor accepted it
  // (position/rotation untouched)
  virtual bool setMode(const std::string& outputName, const std::string& modeId) = 0;

  // Optional: revert to remembered original mode for this output
  virtual bool revert(const std::string& outputName) = 0;
};
