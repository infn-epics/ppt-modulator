TOP=../..

include $(TOP)/configure/CONFIG
#----------------------------------------
#  ADD MACRO DEFINITIONS AFTER THIS LINE
#=============================

#=============================
# Build the IOC application

PROD_IOC = ppt
# ppt.dbd will be created and installed
DBD += ppt.dbd

# ppt.dbd will be made up from these files:
ppt_DBD += base.dbd
ppt_DBD += stream.dbd ## streamdevice.dbd
ppt_DBD += asyn.dbd 
ppt_DBD += drvAsynIPPort.dbd
ppt_DBD += drvAsynSerialPort.dbd


# Include dbd files from all support applications:
#streamdevice_DBD += xxx.dbd

# Add all the support libraries needed by this IOC
#streamdevice_LIBS += xxx
ppt_LIBS += stream
ppt_LIBS += asyn


# streamdevice_registerRecordDeviceDriver.cpp derives from streamdevice.dbd
ppt_SRCS += ppt_registerRecordDeviceDriver.cpp

# Build the main IOC entry point on workstation OSs.
ppt_SRCS_DEFAULT += pptMain.cpp
ppt_SRCS_vxWorks += -nil-

# Add support from base/src/vxWorks if needed
#ppt_OBJS_vxWorks += $(EPICS_BASE_BIN)/vxComLibrary

# Finally link to the EPICS Base libraries
ppt_LIBS += $(EPICS_BASE_IOC_LIBS)

#===========================

include $(TOP)/configure/RULES
#----------------------------------------
#  ADD RULES AFTER THIS LINE

