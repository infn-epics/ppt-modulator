/*
 * pptDecode.c
 * 
 * aSub record subroutines to decode PPT Modulator binary data
 * Input: 86 bytes (CHAR array) from TCP stream
 * Output: 22 values split across two aSub records (11 values each)
 * 
 * All 16-bit words are little-endian (LSB + MSB)
 * 
 * Scaling factors from documentation:
 * - Voltages: raw_value / 10.0 (V)
 * - Currents: raw_value / 100.0 (A)
 * - Temperatures: raw_value / 10.0 (°C)
 * - Flow: raw_value / 100.0 (L/min)
 * - Timers: raw_value (no scaling, minutes/seconds as integers)
 * - Status/Interlock: raw_value (bitfields, no scaling)
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

    unsigned short rawVal;

    /* Extract and scale voltage values (divide by 10 for Volts) */
    rawVal = getWord(rawData, 0);
    *outA = rawVal / 10.0;  /* HeaterVoltage1 - WORD0 */
    printf("HeaterVoltage1: raw=%u scaled=%.1f V\n", rawVal, *outA);

    rawVal = getWord(rawData, 28);
    *outB = rawVal / 10.0;  /* HeaterVoltage2 - WORD14 */
    printf("HeaterVoltage2: raw=%u scaled=%.1f V\n", rawVal, *outB);

    rawVal = getWord(rawData, 4);
    *outC = rawVal / 10.0;  /* ReservoirVoltage - WORD2 */
    printf("ReservoirVoltage: raw=%u scaled=%.1f V\n", rawVal, *outC);

    rawVal = getWord(rawData, 64);
    *outD = rawVal / 10.0;  /* KlystronVoltage - WORD32 */
    printf("KlystronVoltage: raw=%u scaled=%.1f V\n", rawVal, *outD);

    rawVal = getWord(rawData, 72);
    *outE = rawVal / 10.0;  /* MagnetVoltageCoil1 - WORD36 */
    printf("MagnetVoltageCoil1: raw=%u scaled=%.1f V\n", rawVal, *outE);

    rawVal = getWord(rawData, 80);
    *outF = rawVal / 10.0;  /* MagnetVoltageCoil2 - WORD40 */
    printf("MagnetVoltageCoil2: raw=%u scaled=%.1f V\n", rawVal, *outF);

    /* Extract and scale current values (divide by 100 for Amperes) */
    rawVal = getWord(rawData, 8);
    *outG = rawVal / 100.0;  /* TotalCurrent - WORD4 */
    printf("TotalCurrent: raw=%u scaled=%.2f A\n", rawVal, *outG);

    rawVal = getWord(rawData, 32);
    *outH = rawVal / 100.0;  /* HeaterCurrent - WORD16 */
    printf("HeaterCurrent: raw=%u scaled=%.2f A\n", rawVal, *outH);

    rawVal = getWord(rawData, 68);
    *outI = rawVal / 100.0;  /* KlystronCurrent - WORD34 */
    printf("KlystronCurrent: raw=%u scaled=%.2f A\n", rawVal, *outI);

    rawVal = getWord(rawData, 76);
    *outJ = rawVal / 100.0;  /* MagnetCurrentCoil1 - WORD38 */
    printf("MagnetCurrentCoil1: raw=%u scaled=%.2f A\n", rawVal, *outJ);

    rawVal = getWord(rawData, 84);
    *outK = rawVal / 100.0;  /* MagnetCurrentCoil2 - WORD42 */
    printf("MagnetCurrentCoil2: raw=%u scaled=%.2f A\n", rawVal, *outK);

    printf("--- End VoltagesCurrent decode ---\n");
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

    unsigned short rawVal;

    /* Extract and scale temperature values (divide by 10 for °C) */
    rawVal = getWord(rawData, 36);
    *outA = rawVal / 10.0;  /* BodyWaterInTemp - WORD18 */
    printf("BodyWaterInTemp: raw=%u scaled=%.1f C\n", rawVal, *outA);

    rawVal = getWord(rawData, 40);
    *outB = rawVal / 10.0;  /* BodyWaterOutTemp - WORD20 */
    printf("BodyWaterOutTemp: raw=%u scaled=%.1f C\n", rawVal, *outB);

    /* Extract and scale flow value (divide by 100 for L/min) */
    rawVal = getWord(rawData, 44);
    *outC = rawVal / 100.0;  /* BodyWaterFlow - WORD22 */
    printf("BodyWaterFlow: raw=%u scaled=%.2f L/min\n", rawVal, *outC);

    /* Extract timer values (no scaling, already in minutes/seconds) */
    rawVal = getWord(rawData, 12);
    *outD = (double)rawVal;  /* TimerPreheatMin - WORD6 */
    printf("TimerPreheatMin: raw=%u value=%d min\n", rawVal, (int)*outD);

    rawVal = getWord(rawData, 16);
    *outE = (double)rawVal;  /* TimerPreheatSec - WORD8 */
    printf("TimerPreheatSec: raw=%u value=%d sec\n", rawVal, (int)*outE);

    rawVal = getWord(rawData, 48);
    *outF = (double)rawVal;  /* TimerPreheat100Min - WORD24 */
    printf("TimerPreheat100Min: raw=%u value=%d min\n", rawVal, (int)*outF);

    rawVal = getWord(rawData, 52);
    *outG = (double)rawVal;  /* TimerPreheat100Sec - WORD26 */
    printf("TimerPreheat100Sec: raw=%u value=%d sec\n", rawVal, (int)*outG);

    /* Extract status/interlock bitfields (no scaling) */
    rawVal = getWord(rawData, 20);
    *outH = (double)rawVal;  /* InterlockMsg1 - WORD10 */
    printf("InterlockMsg1: raw=0x%04X value=%u\n", rawVal, rawVal);

    rawVal = getWord(rawData, 56);
    *outI = (double)rawVal;  /* InterlockMsg2 - WORD28 */
    printf("InterlockMsg2: raw=0x%04X value=%u\n", rawVal, rawVal);

    rawVal = getWord(rawData, 24);
    *outJ = (double)rawVal;  /* StatusMsg1 - WORD12 */
    printf("StatusMsg1: raw=0x%04X value=%u\n", rawVal, rawVal);

    rawVal = getWord(rawData, 60);
    *outK = (double)rawVal;  /* StatusMsg2 - WORD30 */
    printf("StatusMsg2: raw=0x%04X value=%u\n", rawVal, rawVal);

    printf("--- End TempFlowStatus decode ---\n");
    return 0;  /* Success */
}

/* Register the functions */
epicsRegisterFunction(pptDecodeVoltagesCurrent);
epicsRegisterFunction(pptDecodeTempFlowStatus);
