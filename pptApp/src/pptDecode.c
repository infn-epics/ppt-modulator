/*
 * pptDecode.c
 * 
 * aSub record subroutines to decode PPT Modulator binary data
 * Input: 86 bytes (UCHAR array) from TCP stream
 * Output: 22 values split across two aSub records (11 values each)
 * 
 * All 16-bit words are little-endian (LSB + MSB)
 * 
 * Message structure (86 bytes = 43 words):
 * - Bytes 0-13: Thyratron section (voltages, currents, timers, status)
 * - Bytes 14-35: Klystron section (voltages, currents, temps, timers, status)
 * - Bytes 36-51: Focus Magnet section (3 coils, status)
 * - Bytes 52-59: Premagnetisation section (voltage, current, status)
 * - Bytes 60-67: Waveguide/VSWR/Clipper section (interlocks, counter)
 * - Bytes 68-79: HVPS + General section (HV, temp, status, general interlocks)
 * - Bytes 80-85: Reserved/Control
 * 
 * Scaling factors from documentation:
 * - Voltages: raw_value / 10.0 (V)
 * - Currents: raw_value / 100.0 (A) 
 * - Temperatures: raw_value / 10.0 (°C)
 * - Flow: raw_value / 100.0 (L/min)
 * - Power: raw_value / 10.0 (kW)
 * - HV Charging: raw_value / 10.0 (kV)
 * - Timers/Counters: raw_value (no scaling)
 * - Status/Interlock: raw_value (bitfields, no scaling)
 * 
 * See COMPLETE_86BYTE_MAPPING.md for full byte-by-byte documentation
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
 * pptDecodeThyratronKlystron
 * 
 * Decodes Thyratron and Klystron measurements + status/interlock words (15 values) from 86-byte buffer
 * 
 * INPA: Raw data buffer (UCHAR array, 86 bytes)
 * 
 * VALA-VALO: Output values (DOUBLE, one element each)
 *   A = Thyratron Heater Voltage (bytes 0-1, WORD0)
 *   B = Thyratron Reservoir Voltage (bytes 2-3, WORD1)
 *   C = Thyratron Total Current (bytes 4-5, WORD2)
 *   D = Klystron Heater Voltage (bytes 14-15, WORD7)
 *   E = Klystron Heater Current (bytes 16-17, WORD8)
 *   F = Klystron Body Water In Temp (bytes 18-19, WORD9)
 *   G = Klystron Body Water Out Temp (bytes 20-21, WORD10)
 *   H = Klystron Body Water Flow (bytes 22-23, WORD11)
 *   I = Klystron Dissipated Power (bytes 24-25, WORD12)
 *   J = Klystron Oil Temperature (bytes 26-27, WORD13)
 *   K = Thyratron Interlock Raw (bytes 10-11, WORD5)
 *   L = Thyratron Status Raw (bytes 12-13, WORD6)
 *   M = Klystron Interlock Raw (bytes 32-33, WORD16)
 *   N = Klystron Status Raw (bytes 34-35, WORD17)
 *   O = (Reserved for future use)
 */
long pptDecodeThyratronKlystron(aSubRecord *prec) {
    unsigned char *rawData = (unsigned char *)prec->a;
    double *outA = (double *)prec->vala;  /* Thyratron Heater Voltage */
    double *outB = (double *)prec->valb;  /* Thyratron Reservoir Voltage */
    double *outC = (double *)prec->valc;  /* Thyratron Total Current */
    double *outD = (double *)prec->vald;  /* Klystron Heater Voltage */
    double *outE = (double *)prec->vale;  /* Klystron Heater Current */
    double *outF = (double *)prec->valf;  /* Klystron Body Water In Temp */
    double *outG = (double *)prec->valg;  /* Klystron Body Water Out Temp */
    double *outH = (double *)prec->valh;  /* Klystron Body Water Flow */
    double *outI = (double *)prec->vali;  /* Klystron Dissipated Power */
    double *outJ = (double *)prec->valj;  /* Klystron Oil Temperature */
    double *outK = (double *)prec->valk;  /* Thyratron Interlock Raw */
    double *outL = (double *)prec->vall;  /* Thyratron Status Raw */
    double *outM = (double *)prec->valm;  /* Klystron Interlock Raw */
    double *outN = (double *)prec->valn;  /* Klystron Status Raw */
    double *outO = (double *)prec->valo;  /* Reserved */

    unsigned short rawVal;
    
    if(prec->nea < 86) {
        printf("ERROR: received less bytes %d<86\n", prec->nea);
        return 1;
    }
    
    printf("=== Thyratron/Klystron Decode ===\n");
    
    /* Thyratron Section (bytes 0-13) */
    rawVal = getWord(rawData, 0);
    *outA = rawVal / 10.0;  /* Thyratron Heater Voltage (0..10V) */
    printf("Thyratron HeaterVoltage: raw=%u scaled=%.1f V\n", rawVal, *outA);

    rawVal = getWord(rawData, 2);
    *outB = rawVal / 10.0;  /* Thyratron Reservoir Voltage (0..10V) */
    printf("Thyratron ReservoirVoltage: raw=%u scaled=%.1f V\n", rawVal, *outB);

    rawVal = getWord(rawData, 4);
    *outC = rawVal / 100.0;  /* Thyratron Total Current (0..100A) */
    printf("Thyratron TotalCurrent: raw=%u scaled=%.2f A\n", rawVal, *outC);

    /* Klystron Section (bytes 14-35) */
    rawVal = getWord(rawData, 14);
    *outD = rawVal / 10.0;  /* Klystron Heater Voltage (0..270V) */
    printf("Klystron HeaterVoltage: raw=%u scaled=%.1f V\n", rawVal, *outD);

    rawVal = getWord(rawData, 16);
    *outE = rawVal / 100.0;  /* Klystron Heater Current (0..6A) */
    printf("Klystron HeaterCurrent: raw=%u scaled=%.2f A\n", rawVal, *outE);

    rawVal = getWord(rawData, 18);
    *outF = rawVal / 10.0;  /* Klystron Body Water In Temp (0..100°C) */
    printf("Klystron BodyWaterInTemp: raw=%u scaled=%.1f C\n", rawVal, *outF);

    rawVal = getWord(rawData, 20);
    *outG = rawVal / 10.0;  /* Klystron Body Water Out Temp (0..100°C) */
    printf("Klystron BodyWaterOutTemp: raw=%u scaled=%.1f C\n", rawVal, *outG);

    rawVal = getWord(rawData, 22);
    *outH = rawVal / 100.0;  /* Klystron Body Water Flow (0..10 L/min) */
    printf("Klystron BodyWaterFlow: raw=%u scaled=%.2f L/min\n", rawVal, *outH);

    rawVal = getWord(rawData, 24);
    *outI = rawVal / 10.0;  /* Klystron Dissipated Power (0..5000kW) */
    printf("Klystron DissipatedPower: raw=%u scaled=%.1f kW\n", rawVal, *outI);

    rawVal = getWord(rawData, 26);
    *outJ = rawVal / 10.0;  /* Klystron Oil Temperature (0..100°C) */
    printf("Klystron OilTemp: raw=%u scaled=%.1f C\n", rawVal, *outJ);

    /* Status/Interlock Words (no scaling, raw bitfields) */
    rawVal = getWord(rawData, 10);
    *outK = (double)rawVal;  /* Thyratron Interlock (WORD5) */
    printf("Thyratron InterlockRaw: 0x%04X (%u)\n", rawVal, rawVal);

    rawVal = getWord(rawData, 12);
    *outL = (double)rawVal;  /* Thyratron Status (WORD6) */
    printf("Thyratron StatusRaw: 0x%04X (%u)\n", rawVal, rawVal);

    rawVal = getWord(rawData, 32);
    *outM = (double)rawVal;  /* Klystron Interlock (WORD16) */
    printf("Klystron InterlockRaw: 0x%04X (%u)\n", rawVal, rawVal);

    rawVal = getWord(rawData, 34);
    *outN = (double)rawVal;  /* Klystron Status (WORD17) */
    printf("Klystron StatusRaw: 0x%04X (%u)\n", rawVal, rawVal);

    *outO = 0.0;  /* Reserved */

    printf("--- End Thyratron/Klystron decode ---\n");
    return 0;  /* Success */
}

/*
 * pptDecodeMagnetsTimersStatus
 * 
 * Decodes Focus Magnets, Premagnetisation, Timers and Status/Interlock words (15 values) from 86-byte buffer
 * 
 * INPA: Raw data buffer (UCHAR array, 86 bytes)
 * 
 * VALA-VALO: Output values (DOUBLE, one element each)
 *   A = Focus Magnet Voltage Coil 1 (bytes 36-37, WORD18)
 *   B = Focus Magnet Current Coil 1 (bytes 38-39, WORD19)
 *   C = Focus Magnet Voltage Coil 2 (bytes 40-41, WORD20)
 *   D = Focus Magnet Current Coil 2 (bytes 42-43, WORD21)
 *   E = Focus Magnet Voltage Coil 3 (bytes 44-45, WORD22)
 *   F = Focus Magnet Current Coil 3 (bytes 46-47, WORD23)
 *   G = Premagnetisation Voltage (bytes 52-53, WORD26)
 *   H = Premagnetisation Current (bytes 54-55, WORD27)
 *   I = Thyratron Timer Preheat Min (bytes 6-7, WORD3)
 *   J = Thyratron Timer Preheat Sec (bytes 8-9, WORD4)
 *   K = Klystron Timer Preheat100 Min (bytes 28-29, WORD14)
 *   L = Focus Magnet Interlock Raw (bytes 48-49, WORD24)
 *   M = Focus Magnet Status Raw (bytes 50-51, WORD25)
 *   N = Premagnetisation Interlock Raw (bytes 56-57, WORD28)
 *   O = Premagnetisation Status Raw (bytes 58-59, WORD29)
 */
long pptDecodeMagnetsTimersStatus(aSubRecord *prec) {
    unsigned char *rawData = (unsigned char *)prec->a;
    double *outA = (double *)prec->vala;  /* Focus Magnet Voltage Coil 1 */
    double *outB = (double *)prec->valb;  /* Focus Magnet Current Coil 1 */
    double *outC = (double *)prec->valc;  /* Focus Magnet Voltage Coil 2 */
    double *outD = (double *)prec->vald;  /* Focus Magnet Current Coil 2 */
    double *outE = (double *)prec->vale;  /* Focus Magnet Voltage Coil 3 */
    double *outF = (double *)prec->valf;  /* Focus Magnet Current Coil 3 */
    double *outG = (double *)prec->valg;  /* Premagnetisation Voltage */
    double *outH = (double *)prec->valh;  /* Premagnetisation Current */
    double *outI = (double *)prec->vali;  /* Thyratron Timer Preheat Min */
    double *outJ = (double *)prec->valj;  /* Thyratron Timer Preheat Sec */
    double *outK = (double *)prec->valk;  /* Klystron Timer Preheat100 Min */
    double *outL = (double *)prec->vall;  /* Focus Magnet Interlock Raw */
    double *outM = (double *)prec->valm;  /* Focus Magnet Status Raw */
    double *outN = (double *)prec->valn;  /* Premagnetisation Interlock Raw */
    double *outO = (double *)prec->valo;  /* Premagnetisation Status Raw */
    
    unsigned short rawVal;
    
    if(prec->nea < 86) {
        printf("ERROR: received less bytes %d<86\n", prec->nea);
        return 1;
    }
    
    printf("=== Magnets/Timers/Status Decode ===\n");
    
    /* Focus Magnet Section (bytes 36-47) */
    rawVal = getWord(rawData, 36);
    *outA = rawVal / 10.0;  /* Focus Magnet Voltage Coil 1 (0..132V) */
    printf("FocusMagnet Coil1Voltage: raw=%u scaled=%.1f V\n", rawVal, *outA);

    rawVal = getWord(rawData, 38);
    *outB = rawVal / 100.0;  /* Focus Magnet Current Coil 1 (0..50A) */
    printf("FocusMagnet Coil1Current: raw=%u scaled=%.2f A\n", rawVal, *outB);

    rawVal = getWord(rawData, 40);
    *outC = rawVal / 10.0;  /* Focus Magnet Voltage Coil 2 (0..132V) */
    printf("FocusMagnet Coil2Voltage: raw=%u scaled=%.1f V\n", rawVal, *outC);

    rawVal = getWord(rawData, 42);
    *outD = rawVal / 100.0;  /* Focus Magnet Current Coil 2 (0..50A) */
    printf("FocusMagnet Coil2Current: raw=%u scaled=%.2f A\n", rawVal, *outD);

    rawVal = getWord(rawData, 44);
    *outE = rawVal / 10.0;  /* Focus Magnet Voltage Coil 3 (0..132V) */
    printf("FocusMagnet Coil3Voltage: raw=%u scaled=%.1f V\n", rawVal, *outE);

    rawVal = getWord(rawData, 46);
    *outF = rawVal / 100.0;  /* Focus Magnet Current Coil 3 (0..50A) */
    printf("FocusMagnet Coil3Current: raw=%u scaled=%.2f A\n", rawVal, *outF);

    /* Premagnetisation Section (bytes 52-55) */
    rawVal = getWord(rawData, 52);
    *outG = rawVal / 10.0;  /* Premagnetisation Voltage (0..70V) */
    printf("Premagnetisation Voltage: raw=%u scaled=%.1f V\n", rawVal, *outG);

    rawVal = getWord(rawData, 54);
    *outH = rawVal / 100.0;  /* Premagnetisation Current (0..20A) */
    printf("Premagnetisation Current: raw=%u scaled=%.2f A\n", rawVal, *outH);

    /* Timer Section (no scaling) */
    rawVal = getWord(rawData, 6);
    *outI = (double)rawVal;  /* Thyratron Timer Preheat Minutes (0..15) */
    printf("Thyratron TimerPreheatMin: raw=%u value=%d min\n", rawVal, (int)*outI);

    rawVal = getWord(rawData, 8);
    *outJ = (double)rawVal;  /* Thyratron Timer Preheat Seconds (0..60) */
    printf("Thyratron TimerPreheatSec: raw=%u value=%d sec\n", rawVal, (int)*outJ);

    rawVal = getWord(rawData, 28);
    *outK = (double)rawVal;  /* Klystron Timer Preheat100 Minutes (0..15) */
    printf("Klystron TimerPreheat100Min: raw=%u value=%d min\n", rawVal, (int)*outK);

    /* Status/Interlock Words (no scaling, raw bitfields) */
    rawVal = getWord(rawData, 48);
    *outL = (double)rawVal;  /* Focus Magnet Interlock (WORD24) */
    printf("FocusMagnet InterlockRaw: 0x%04X (%u)\n", rawVal, rawVal);

    rawVal = getWord(rawData, 50);
    *outM = (double)rawVal;  /* Focus Magnet Status (WORD25) */
    printf("FocusMagnet StatusRaw: 0x%04X (%u)\n", rawVal, rawVal);

    rawVal = getWord(rawData, 56);
    *outN = (double)rawVal;  /* Premagnetisation Interlock (WORD28) */
    printf("Premagnetisation InterlockRaw: 0x%04X (%u)\n", rawVal, rawVal);

    rawVal = getWord(rawData, 58);
    *outO = (double)rawVal;  /* Premagnetisation Status (WORD29) */
    printf("Premagnetisation StatusRaw: 0x%04X (%u)\n", rawVal, rawVal);

    printf("--- End Magnets/Timers/Status decode ---\n");
    return 0;  /* Success */
}

/* Register the functions */
epicsRegisterFunction(pptDecodeThyratronKlystron);
epicsRegisterFunction(pptDecodeMagnetsTimersStatus);
