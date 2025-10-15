/*
 * pptDecode.c
 * 
 * aSub record subroutines to decode PPT Modulator binary data
 * Input: 86 bytes (CHAR array) from TCP stream
 * Output: 22 values split across two aSub records (11 values each)
 * 
 * All 16-bit words are little-endian (LSB + MSB)
 */

#include <stdio.h>
#include <string.h>
#include <epicsExport.h>
#include <aSubRecord.h>
#include <registryFunction.h>

/* Helper function to extract 16-bit little-endian unsigned word */
static unsigned short getWord(const unsigned char *data, int offset) {
    return (unsigned short)(data[offset] | (data[offset+1] << 8));
}

/*
 * pptDecodeVoltagesCurrent
 * 
 * Decodes voltages and currents (11 values) from 86-byte buffer
 * 
 * INPA: Raw data buffer (CHAR array, 86 bytes)
 * 
 * VALA-VALK: Output values (DOUBLE, one element each)
 *   A = HeaterVoltage1 (bytes 0-1, WORD0)
 *   B = HeaterVoltage2 (bytes 28-29, WORD14)
 *   C = ReservoirVoltage (bytes 4-5, WORD2)
 *   D = KlystronVoltage (bytes 64-65, WORD32)
 *   E = MagnetVoltageCoil1 (bytes 72-73, WORD36)
 *   F = MagnetVoltageCoil2 (bytes 80-81, WORD40)
 *   G = TotalCurrent (bytes 8-9, WORD4)
 *   H = HeaterCurrent (bytes 32-33, WORD16)
 *   I = KlystronCurrent (bytes 68-69, WORD34)
 *   J = MagnetCurrentCoil1 (bytes 76-77, WORD38)
 *   K = MagnetCurrentCoil2 (bytes 84-85, WORD42)
 */
long pptDecodeVoltagesCurrent(aSubRecord *prec) {
    unsigned char *rawData = (unsigned char *)prec->a;
    double *outA = (double *)prec->vala;  /* HeaterVoltage1 */
    double *outB = (double *)prec->valb;  /* HeaterVoltage2 */
    double *outC = (double *)prec->valc;  /* ReservoirVoltage */
    double *outD = (double *)prec->vald;  /* KlystronVoltage */
    double *outE = (double *)prec->vale;  /* MagnetVoltageCoil1 */
    double *outF = (double *)prec->valf;  /* MagnetVoltageCoil2 */
    double *outG = (double *)prec->valg;  /* TotalCurrent */
    double *outH = (double *)prec->valh;  /* HeaterCurrent */
    double *outI = (double *)prec->vali;  /* KlystronCurrent */
    double *outJ = (double *)prec->valj;  /* MagnetCurrentCoil1 */
    double *outK = (double *)prec->valk;  /* MagnetCurrentCoil2 */

    /* Check input size */
    if (prec->nea < 86) {
        printf("pptDecodeVoltagesCurrent: Error - input buffer too small (%ld bytes, need 86)\n", prec->nea);
        return 1;
    }

    /* Extract voltage and current values */
    *outA = (double)getWord(rawData, 0);   /* HeaterVoltage1 - WORD0 */
    *outB = (double)getWord(rawData, 28);  /* HeaterVoltage2 - WORD14 */
    *outC = (double)getWord(rawData, 4);   /* ReservoirVoltage - WORD2 */
    *outD = (double)getWord(rawData, 64);  /* KlystronVoltage - WORD32 */
    *outE = (double)getWord(rawData, 72);  /* MagnetVoltageCoil1 - WORD36 */
    *outF = (double)getWord(rawData, 80);  /* MagnetVoltageCoil2 - WORD40 */
    *outG = (double)getWord(rawData, 8);   /* TotalCurrent - WORD4 */
    *outH = (double)getWord(rawData, 32);  /* HeaterCurrent - WORD16 */
    *outI = (double)getWord(rawData, 68);  /* KlystronCurrent - WORD34 */
    *outJ = (double)getWord(rawData, 76);  /* MagnetCurrentCoil1 - WORD38 */
    *outK = (double)getWord(rawData, 84);  /* MagnetCurrentCoil2 - WORD42 */

    return 0;  /* Success */
}

/*
 * pptDecodeTempFlowStatus
 * 
 * Decodes temperatures, flow, timers and status (11 values) from 86-byte buffer
 * 
 * INPA: Raw data buffer (CHAR array, 86 bytes)
 * 
 * VALA-VALK: Output values (DOUBLE, one element each)
 *   A = BodyWaterInTemp (bytes 36-37, WORD18)
 *   B = BodyWaterOutTemp (bytes 40-41, WORD20)
 *   C = BodyWaterFlow (bytes 44-45, WORD22)
 *   D = TimerPreheatMin (bytes 12-13, WORD6)
 *   E = TimerPreheatSec (bytes 16-17, WORD8)
 *   F = TimerPreheat100Min (bytes 48-49, WORD24)
 *   G = TimerPreheat100Sec (bytes 52-53, WORD26)
 *   H = InterlockMsg1 (bytes 20-21, WORD10)
 *   I = InterlockMsg2 (bytes 56-57, WORD28)
 *   J = StatusMsg1 (bytes 24-25, WORD12)
 *   K = StatusMsg2 (bytes 60-61, WORD30)
 */
long pptDecodeTempFlowStatus(aSubRecord *prec) {
    unsigned char *rawData = (unsigned char *)prec->a;
    double *outA = (double *)prec->vala;  /* BodyWaterInTemp */
    double *outB = (double *)prec->valb;  /* BodyWaterOutTemp */
    double *outC = (double *)prec->valc;  /* BodyWaterFlow */
    double *outD = (double *)prec->vald;  /* TimerPreheatMin */
    double *outE = (double *)prec->vale;  /* TimerPreheatSec */
    double *outF = (double *)prec->valf;  /* TimerPreheat100Min */
    double *outG = (double *)prec->valg;  /* TimerPreheat100Sec */
    double *outH = (double *)prec->valh;  /* InterlockMsg1 */
    double *outI = (double *)prec->vali;  /* InterlockMsg2 */
    double *outJ = (double *)prec->valj;  /* StatusMsg1 */
    double *outK = (double *)prec->valk;  /* StatusMsg2 */

    /* Check input size */
    if (prec->nea < 86) {
        printf("pptDecodeTempFlowStatus: Error - input buffer too small (%ld bytes, need 86)\n", prec->nea);
        return 1;
    }

    /* Extract temperature, flow, timer and status values */
    *outA = (double)getWord(rawData, 36);  /* BodyWaterInTemp - WORD18 */
    *outB = (double)getWord(rawData, 40);  /* BodyWaterOutTemp - WORD20 */
    *outC = (double)getWord(rawData, 44);  /* BodyWaterFlow - WORD22 */
    *outD = (double)getWord(rawData, 12);  /* TimerPreheatMin - WORD6 */
    *outE = (double)getWord(rawData, 16);  /* TimerPreheatSec - WORD8 */
    *outF = (double)getWord(rawData, 48);  /* TimerPreheat100Min - WORD24 */
    *outG = (double)getWord(rawData, 52);  /* TimerPreheat100Sec - WORD26 */
    *outH = (double)getWord(rawData, 20);  /* InterlockMsg1 - WORD10 */
    *outI = (double)getWord(rawData, 56);  /* InterlockMsg2 - WORD28 */
    *outJ = (double)getWord(rawData, 24);  /* StatusMsg1 - WORD12 */
    *outK = (double)getWord(rawData, 60);  /* StatusMsg2 - WORD30 */

    return 0;  /* Success */
}

/* Register the functions */
epicsRegisterFunction(pptDecodeVoltagesCurrent);
epicsRegisterFunction(pptDecodeTempFlowStatus);
