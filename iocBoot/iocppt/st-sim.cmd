#!../../bin/linux-x86_64/ppt

# < envPaths

#cd "${TOP}"

## Same as st.cmd, but pointing at ppt_modulator_sim.py instead of real hardware.
## Run the simulator first, e.g.:
##   python3 ../../sim/ppt_modulator_sim.py --port 2000
##   python3 ../../sim/ppt_modulator_sim.py --port 2001   # if testing MOD002 too

## Register all support components
dbLoadDatabase "../../dbd/ppt.dbd"
ppt_registerRecordDeviceDriver pdbbase

## Configure asyn port for TCP/IP communication
## drvAsynIPPortConfigure("portName", "hostname:port", priority, noAutoConnect, noProcessEos)
drvAsynIPPortConfigure("PPT1", "127.0.0.1:2000", 0, 0, 0)

## Optional: Enable asyn tracing for debugging
# asynSetTraceMask("PPT1", 0, 0x9)    # ASYN_TRACE_ERROR | ASYN_TRACEIO_DEVICE
# asynSetTraceIOMask("PPT1", 0, 0x2)  # ASYN_TRACEIO_HEX
epicsEnvSet("STREAM_PROTOCOL_PATH","../../db")

## Load record instances (using corrected aSub approach per documentation)
## HVMAX macro sets the maximum operational HV voltage (default: 37 kV)
dbLoadRecords("../../db/ppt.template", "P=SPARC:MOD:PPT,R=MOD001, PORT=PPT1")
dbLoadRecords("../../db/ppt_control.template", "P=SPARC:MOD:PPT,R=MOD001, PORT=PPT1, HVMAX=37")
dbLoadRecords("../../db/ppt_autoseq.template", "P=SPARC:MOD:PPT,R=MOD001")




# drvAsynIPPortConfigure("PPT2", "127.0.0.1:2001", 0, 0, 0)

# ## Optional: Enable asyn tracing for debugging
# # asynSetTraceMask("PPT2", 0, 0x9)    # ASYN_TRACE_ERROR | ASYN_TRACEIO_DEVICE
# # asynSetTraceIOMask("PPT2", 0, 0x2)  # ASYN_TRACEIO_HEX
# epicsEnvSet("STREAM_PROTOCOL_PATH","../../db")

# ## Load record instances (using corrected aSub approach per documentation)
# ## HVMAX macro sets the maximum operational HV voltage (default: 37 kV)
# dbLoadRecords("../../db/ppt.template", "P=SPARC:MOD:PPT,R=MOD002, PORT=PPT2")
# dbLoadRecords("../../db/ppt_control.template", "P=SPARC:MOD:PPT,R=MOD002, PORT=PPT2, HVMAX=37")
# dbLoadRecords("../../db/ppt_autoseq.template", "P=SPARC:MOD:PPT,R=MOD002")

# cd "${TOP}/iocBoot/${IOC}"
iocInit

## Start any sequence programs
## RETRY_DELAY: time in seconds between command retries (default: 5.0)
seq pptAutoSeq, "P=SPARC:MOD:PPT,R=MOD001,RETRY_DELAY=5.0"
# seq pptAutoSeq, "P=SPARC:MOD:PPT,R=MOD002,RETRY_DELAY=5.0"
