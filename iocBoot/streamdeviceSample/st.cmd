#!../../bin/linux-x86_64/streamdeviceSample

#- You may have to change streamdeviceSample to something else
#- everywhere it appears in this file

< envPaths

cd "${TOP}"

# Evironment variables
epicsEnvSet("STREAM_PROTOCOL_PATH", "${TOP}/db")
epicsEnvSet("BOOT","${TOP}/iocBoot/${IOC}")

## Register all support components
dbLoadDatabase "dbd/streamdeviceSample.dbd"
streamdeviceSample_registerRecordDeviceDriver pdbbase

### Create a IPCMini device instance
epicsEnvSet("DEVICE", "TEST:STREAMDEVICESAMPLE")
epicsEnvSet("IP", "192.168.197.105:4002")
## Create asyn IP port for communication over TCP/IP
drvAsynIPPortConfigure ("ASYNPORT", "$(IP)")
## Load record instances
dbLoadRecords("db/streamdevicesample.template","DEVICE=$(DEVICE),PORT=ASYNPORT,module=1,max=100")


cd "${TOP}/iocBoot/${IOC}"
iocInit
