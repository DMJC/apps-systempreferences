RPM_DISABLE_RELOCATABLE=YES

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = PowerModule
BUNDLE_EXTENSION = .prefPane

PowerModule_HAS_RESOURCE_BUNDLE = yes

OBJCCFLAGS += -Wall -fobjc-runtime=gnustep-2.0 libpulse

PowerModule_OBJCC_FILES = PowerModule.mm

PowerModule_PRINCIPAL_CLASS = PowerModule

PowerModule_RESOURCE_FILES = \
Power.tiff \
Resources/English.lproj

PowerModule_LANGUAGES = \
Resources/English

ifeq ($(findstring darwin, $(GNUSTEP_TARGET_OS)), darwin)
  ADDITIONAL_GUI_LIBS += -lGSPreferencePanes -lpulse
else
  ADDITIONAL_GUI_LIBS += -lPreferencePanes -lpulse
endif

include $(GNUSTEP_MAKEFILES)/bundle.make

-include GNUmakefile.preamble
-include GNUmakefile.postamble

