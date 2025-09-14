TOP=../..

include $(TOP)/configure/CONFIG
#----------------------------------------
#  ADD MACRO DEFINITIONS AFTER THIS LINE
#=============================

#=============================
# Build the IOC application

PROD_IOC = streamdeviceSample
# streamdeviceSample.dbd will be created and installed
DBD += streamdeviceSample.dbd

# streamdeviceSample.dbd will be made up from these files:
streamdeviceSample_DBD += base.dbd
streamdeviceSample_DBD += stream.dbd ## streamdevice.dbd
streamdeviceSample_DBD += asyn.dbd 
streamdeviceSample_DBD += drvAsynIPPort.dbd
streamdeviceSample_DBD += drvAsynSerialPort.dbd


# Include dbd files from all support applications:
#streamdevice_DBD += xxx.dbd

# Add all the support libraries needed by this IOC
#streamdevice_LIBS += xxx
streamdeviceSample_LIBS += stream
streamdeviceSample_LIBS += asyn


# streamdevice_registerRecordDeviceDriver.cpp derives from streamdevice.dbd
streamdeviceSample_SRCS += streamdeviceSample_registerRecordDeviceDriver.cpp

# Build the main IOC entry point on workstation OSs.
streamdeviceSample_SRCS_DEFAULT += streamdeviceSampleMain.cpp
streamdeviceSample_SRCS_vxWorks += -nil-

# Add support from base/src/vxWorks if needed
#streamdeviceSample_OBJS_vxWorks += $(EPICS_BASE_BIN)/vxComLibrary

# Finally link to the EPICS Base libraries
streamdeviceSample_LIBS += $(EPICS_BASE_IOC_LIBS)

#===========================

include $(TOP)/configure/RULES
#----------------------------------------
#  ADD RULES AFTER THIS LINE

