TOP=../..

include $(TOP)/configure/CONFIG
#----------------------------------------
#  ADD MACRO DEFINITIONS AFTER THIS LINE
#=============================

#=============================
# Build the IOC application

PROD_IOC = ppt
LIBRARY_IOC += pptsup

# ppt.dbd will be created and installed
DBD += ppt.dbd

# ppt.dbd will be made up from these files:
ppt_DBD += base.dbd
ppt_DBD += stream.dbd ## streamdevice.dbd
ppt_DBD += asyn.dbd 
ppt_DBD += drvAsynIPPort.dbd
ppt_DBD += drvAsynSerialPort.dbd
ppt_DBD += pptsup.dbd 

# Add sequencer dbd to IOC
ifneq ($(SEQ),)
ppt_DBD += pptAutoSeq.dbd
endif

# pptsup library - reusable by other IOCs
# Add aSub record subroutine for decoding binary data
pptsup_SRCS += pptDecode.c

# Add sequencer Auto ON/OFF state program to library
ifneq ($(SEQ),)
SNCFLAGS += +r
pptsup_SNCFLAGS += +r
pptsup_SRCS += pptAutoSeq.st
pptsup_LIBS += seq pv
endif

# Include dbd files from all support applications:
#streamdevice_DBD += xxx.dbd

# Add all the support libraries needed by this IOC
#streamdevice_LIBS += xxx
ppt_LIBS += stream
ppt_LIBS += asyn

# Add sequencer libs if available
ifneq ($(SEQ),)
ppt_LIBS += seq pv
endif

# streamdevice_registerRecordDeviceDriver.cpp derives from streamdevice.dbd
ppt_SRCS += ppt_registerRecordDeviceDriver.cpp

# Build the main IOC entry point on workstation OSs.
ppt_SRCS_DEFAULT += pptMain.cpp
ppt_SRCS_vxWorks += -nil-

# Add support from base/src/vxWorks if needed
#ppt_OBJS_vxWorks += $(EPICS_BASE_BIN)/vxComLibrary

# Finally link to the EPICS Base libraries
ppt_LIBS += $(LIBRARY_IOC)
ppt_LIBS += $(EPICS_BASE_IOC_LIBS) 

#===========================

include $(TOP)/configure/RULES
#----------------------------------------
#  ADD RULES AFTER THIS LINE

