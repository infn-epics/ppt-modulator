/*
 * pptDecode.c
 * 
 * aSub record subroutine to decode PPT Modulator binary data
 * Input: 86 bytes (CHAR array) from TCP stream
 * Output: 22 values (DOUBLE arrays, one element each)
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
 * pptDecodeData
 * 
 * Decodes all 22 measurements from 86-byte buffer
 * 
 * INPA: Raw data buffer (CHAR array, 86 bytes)
 * 
 * VALA-VALV: Output values (DOUBLE, one element each)
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
 *   L = BodyWaterInTemp (bytes 36-37, WORD18)
 *   M = BodyWaterOutTemp (bytes 40-41, WORD20)
 *   N = BodyWaterFlow (bytes 44-45, WORD22)
 *   O = TimerPreheatMin (bytes 12-13, WORD6)
 *   P = TimerPreheatSec (bytes 16-17, WORD8)
 *   Q = TimerPreheat100Min (bytes 48-49, WORD24)
 *   R = TimerPreheat100Sec (bytes 52-53, WORD26)
 *   S = InterlockMsg1 (bytes 20-21, WORD10)
 *   T = InterlockMsg2 (bytes 56-57, WORD28)
 *   U = StatusMsg1 (bytes 24-25, WORD12)
 *   V = StatusMsg2 (bytes 60-61, WORD30)
 */
long pptDecodeData(aSubRecord *prec) {
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
    double *outL = (double *)prec->vall;  /* BodyWaterInTemp */
    double *outM = (double *)prec->valm;  /* BodyWaterOutTemp */
    double *outN = (double *)prec->valn;  /* BodyWaterFlow */
    double *outO = (double *)prec->valo;  /* TimerPreheatMin */
    double *outP = (double *)prec->valp;  /* TimerPreheatSec */
    double *outQ = (double *)prec->valq;  /* TimerPreheat100Min */
    double *outR = (double *)prec->valr;  /* TimerPreheat100Sec */
    double *outS = (double *)prec->vals;  /* InterlockMsg1 */
    double *outT = (double *)prec->valt;  /* InterlockMsg2 */
    double *outU = (double *)prec->valu;  /* StatusMsg1 */
    double *outV = (double *)prec->valv;  /* StatusMsg2 */

    /* Check input size */
    if (prec->nea < 86) {
        printf("pptDecodeData: Error - input buffer too small (%ld bytes, need 86)\n", prec->nea);
        return 1;
    }

    /* Extract all 22 values */
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
    *outL = (double)getWord(rawData, 36);  /* BodyWaterInTemp - WORD18 */
    *outM = (double)getWord(rawData, 40);  /* BodyWaterOutTemp - WORD20 */
    *outN = (double)getWord(rawData, 44);  /* BodyWaterFlow - WORD22 */
    *outO = (double)getWord(rawData, 12);  /* TimerPreheatMin - WORD6 */
    *outP = (double)getWord(rawData, 16);  /* TimerPreheatSec - WORD8 */
    *outQ = (double)getWord(rawData, 48);  /* TimerPreheat100Min - WORD24 */
    *outR = (double)getWord(rawData, 52);  /* TimerPreheat100Sec - WORD26 */
    *outS = (double)getWord(rawData, 20);  /* InterlockMsg1 - WORD10 */
    *outT = (double)getWord(rawData, 56);  /* InterlockMsg2 - WORD28 */
    *outU = (double)getWord(rawData, 24);  /* StatusMsg1 - WORD12 */
    *outV = (double)getWord(rawData, 60);  /* StatusMsg2 - WORD30 */

    return 0;  /* Success */
}

/* Register the function */
epicsRegisterFunction(pptDecodeData);
