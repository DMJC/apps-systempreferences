RPM_DISABLE_RELOCATABLE = YES

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = VideoModule
BUNDLE_EXTENSION = .prefPane

VideoModule_HAS_RESOURCE_BUNDLE = yes

# Compiler flags for all files, including the unstable flag
ADDITIONAL_OBJCCFLAGS += -Wall -fobjc-runtime=gnustep-2.0 -DWLR_USE_UNSTABLE $(shell pkg-config --cflags wayland-client)

VideoModule_OBJCC_FILES = VideoModule.mm

VideoModule_PRINCIPAL_CLASS = VideoModule

VideoModule_RESOURCE_FILES = \
Video.tiff \
Resources/English.lproj

VideoModule_LANGUAGES = \
Resources/English

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  ADDITIONAL_GUI_LIBS += -lGSPreferencePanes -lwayland-client
#-lwlroots
else
  ADDITIONAL_GUI_LIBS += -lPreferencePanes -lwayland-client
#-lwlroots
endif

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.postamble
