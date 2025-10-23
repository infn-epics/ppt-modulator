#!../../bin/linux-x86_64/ppt

# < envPaths

#cd "${TOP}"

## Register all support components
dbLoadDatabase "../../dbd/ppt.dbd"
ppt_registerRecordDeviceDriver pdbbase

## Configure asyn port for TCP/IP communication
## drvAsynIPPortConfigure("portName", "hostname:port", priority, noAutoConnect, noProcessEos)
drvAsynIPPortConfigure("PPT1", "192.168.197.111:2000", 0, 0, 0)

## Optional: Enable asyn tracing for debugging
# asynSetTraceMask("PPT1", 0, 0x9)    # ASYN_TRACE_ERROR | ASYN_TRACEIO_DEVICE
# asynSetTraceIOMask("PPT1", 0, 0x2)  # ASYN_TRACEIO_HEX
epicsEnvSet("STREAM_PROTOCOL_PATH","../../db")

## Load record instances (using corrected aSub approach per documentation)
dbLoadRecords("../../db/ppt.template", "P=PPT,R=MOD1, PORT=PPT1")
dbLoadRecords("../../db/ppt_control.template", "P=PPT,R=MOD1, PORT=PPT1")


# cd "${TOP}/iocBoot/${IOC}"
iocInit

## Start any sequence programs
#seq sncExample, "user=epics"
