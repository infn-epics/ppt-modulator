/*
 * pptAutoSeq.st - State Notation Language program for PPT Modulator
 * 
 * Provides automatic ON and OFF sequencing for the modulator
 * 
 * Auto ON sequence:
 *   1. Thyratron Heater ON → wait for Thy:Status:Ready
 *   2. Klystron 80% ON → wait for Klys:Status:HeaterVoltage80Percent
 *   3. Klystron 100% ON → wait for Klys:Status:HeaterVoltage100Percent
 *   4. Focus ON → wait for Focus:Status:Ready
 *   5. Premagnetisation ON → wait for Premag:Status:Ready
 *   6. HVPS ON → wait for HVPS:Status:Ready
 *   7. Charge PFN ON → wait for HVPS:Status:HighVoltageOnOff
 *
 * Auto OFF sequence (reverse order):
 *   1. Charge PFN OFF → wait for HVPS:Status:HighVoltageOnOff = 0
 *   2. HVPS OFF → wait for HVPS:Status:Ready = 0
 *   3. Premagnetisation OFF → wait for Premag:Status:Ready = 0
 *   4. Focus OFF → wait for Focus:Status:Ready = 0
 *   5. Klystron 100% OFF → wait for Klys:Status:HeaterVoltage100Percent = 0
 *   6. Klystron 80% OFF → wait for Klys:Status:HeaterVoltage80Percent = 0
 *   7. Thyratron OFF → wait for Thy:Status:Ready = 0
 */

program pptAutoSeq("P=SPARC:MOD:PPT,R=MOD001")

/* Timeout for each step in seconds */
#define STEP_TIMEOUT    300.0
#define COMMAND_DELAY   1.0

%%#include <stdio.h>
%%#include <string.h>

/* === Control Variables === */
int autoOnCmd;
assign autoOnCmd to "{P}:{R}:AutoOn:Cmd";
monitor autoOnCmd;

int autoOffCmd;
assign autoOffCmd to "{P}:{R}:AutoOff:Cmd";
monitor autoOffCmd;

int autoAbortCmd;
assign autoAbortCmd to "{P}:{R}:Auto:Abort";
monitor autoAbortCmd;

/* === State Variables === */
int autoOnState;
assign autoOnState to "{P}:{R}:AutoOn:State";

int autoOffState;
assign autoOffState to "{P}:{R}:AutoOff:State";

int autoOnStep;
assign autoOnStep to "{P}:{R}:AutoOn:Step";

int autoOffStep;
assign autoOffStep to "{P}:{R}:AutoOff:Step";

string autoMessage;
assign autoMessage to "{P}:{R}:Auto:Message";

/* === ON Command Records === */
int thyOnCmd;
assign thyOnCmd to "{P}:{R}:Thy:OnCmd";

int klys80OnCmd;
assign klys80OnCmd to "{P}:{R}:Klys:On80Cmd";

int klys100OnCmd;
assign klys100OnCmd to "{P}:{R}:Klys:On100Cmd";

int focusOnCmd;
assign focusOnCmd to "{P}:{R}:Focus:OnCmd";

int premagOnCmd;
assign premagOnCmd to "{P}:{R}:Premag:OnCmd";

int hvpsOnCmd;
assign hvpsOnCmd to "{P}:{R}:HVPS:OnCmd";

int chargePfnOnCmd;
assign chargePfnOnCmd to "{P}:{R}:ChargePFN:OnCmd";

/* === OFF Command Records === */
int thyOffCmd;
assign thyOffCmd to "{P}:{R}:Thy:OffCmd";

int klys80OffCmd;
assign klys80OffCmd to "{P}:{R}:Klys:Off80Cmd";

int klys100OffCmd;
assign klys100OffCmd to "{P}:{R}:Klys:Off100Cmd";

int focusOffCmd;
assign focusOffCmd to "{P}:{R}:Focus:OffCmd";

int premagOffCmd;
assign premagOffCmd to "{P}:{R}:Premag:OffCmd";

int hvpsOffCmd;
assign hvpsOffCmd to "{P}:{R}:HVPS:OffCmd";

int chargePfnOffCmd;
assign chargePfnOffCmd to "{P}:{R}:ChargePFN:OffCmd";

/* === Status Readback Variables === */
double thyReady;
assign thyReady to "{P}:{R}:Thy:Status:Ready";
monitor thyReady;

double klys80Status;
assign klys80Status to "{P}:{R}:Klys:Status:HeaterVoltage80Percent";
monitor klys80Status;

double klys100Status;
assign klys100Status to "{P}:{R}:Klys:Status:HeaterVoltage100Percent";
monitor klys100Status;

double focusReady;
assign focusReady to "{P}:{R}:Focus:Status:Ready";
monitor focusReady;

double premagReady;
assign premagReady to "{P}:{R}:Premag:Status:Ready";
monitor premagReady;

double hvpsReady;
assign hvpsReady to "{P}:{R}:HVPS:Status:Ready";
monitor hvpsReady;

double hvOnOff;
assign hvOnOff to "{P}:{R}:HVPS:Status:HighVoltageOnOff";
monitor hvOnOff;

/* === State Set: Auto ON Sequence === */
ss autoOnSequence {

    state idle {
        entry {
            autoOnState = 0;  /* Idle */
            pvPut(autoOnState);
            autoOnStep = 0;
            pvPut(autoOnStep);
        }
        when (autoOnCmd == 1) {
            autoOnCmd = 0;
            pvPut(autoOnCmd);
            autoAbortCmd = 0;
            pvPut(autoAbortCmd);
        } state autoOn_thyratron
    }

    /* Step 1: Thyratron */
    state autoOn_thyratron {
        entry {
            autoOnState = 1;  /* Running */
            pvPut(autoOnState);
            autoOnStep = 1;
            pvPut(autoOnStep);
            strcpy(autoMessage, "Step 1: Turning ON Thyratron...");
            pvPut(autoMessage);
            thyOnCmd = 1;
            pvPut(thyOnCmd);
        }
        when (thyReady >= 1.0) {
            strcpy(autoMessage, "Thyratron Ready");
            pvPut(autoMessage);
        } state autoOn_klys80
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Thyratron not ready");
            pvPut(autoMessage);
        } state autoOn_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOn_aborted
    }

    /* Step 2: Klystron 80% */
    state autoOn_klys80 {
        entry {
            autoOnStep = 2;
            pvPut(autoOnStep);
            strcpy(autoMessage, "Step 2: Turning ON Klystron 80%...");
            pvPut(autoMessage);
            klys80OnCmd = 1;
            pvPut(klys80OnCmd);
        }
        when (klys80Status >= 1.0) {
            strcpy(autoMessage, "Klystron 80% Ready");
            pvPut(autoMessage);
        } state autoOn_klys100
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Klystron 80% not ready");
            pvPut(autoMessage);
        } state autoOn_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOn_aborted
    }

    /* Step 3: Klystron 100% */
    state autoOn_klys100 {
        entry {
            autoOnStep = 3;
            pvPut(autoOnStep);
            strcpy(autoMessage, "Step 3: Turning ON Klystron 100%...");
            pvPut(autoMessage);
            klys100OnCmd = 1;
            pvPut(klys100OnCmd);
        }
        when (klys100Status >= 1.0) {
            strcpy(autoMessage, "Klystron 100% Ready");
            pvPut(autoMessage);
        } state autoOn_focus
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Klystron 100% not ready");
            pvPut(autoMessage);
        } state autoOn_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOn_aborted
    }

    /* Step 4: Focus */
    state autoOn_focus {
        entry {
            autoOnStep = 4;
            pvPut(autoOnStep);
            strcpy(autoMessage, "Step 4: Turning ON Focus...");
            pvPut(autoMessage);
            focusOnCmd = 1;
            pvPut(focusOnCmd);
        }
        when (focusReady >= 1.0) {
            strcpy(autoMessage, "Focus Ready");
            pvPut(autoMessage);
        } state autoOn_premag
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Focus not ready");
            pvPut(autoMessage);
        } state autoOn_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOn_aborted
    }

    /* Step 5: Premagnetisation */
    state autoOn_premag {
        entry {
            autoOnStep = 5;
            pvPut(autoOnStep);
            strcpy(autoMessage, "Step 5: Turning ON Premagnetisation...");
            pvPut(autoMessage);
            premagOnCmd = 1;
            pvPut(premagOnCmd);
        }
        when (premagReady >= 1.0) {
            strcpy(autoMessage, "Premagnetisation Ready");
            pvPut(autoMessage);
        } state autoOn_hvps
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Premagnetisation not ready");
            pvPut(autoMessage);
        } state autoOn_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOn_aborted
    }

    /* Step 6: HVPS */
    state autoOn_hvps {
        entry {
            autoOnStep = 6;
            pvPut(autoOnStep);
            strcpy(autoMessage, "Step 6: Turning ON HVPS...");
            pvPut(autoMessage);
            hvpsOnCmd = 1;
            pvPut(hvpsOnCmd);
        }
        when (hvpsReady >= 1.0) {
            strcpy(autoMessage, "HVPS Ready");
            pvPut(autoMessage);
        } state autoOn_chargePfn
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: HVPS not ready");
            pvPut(autoMessage);
        } state autoOn_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOn_aborted
    }

    /* Step 7: Charge PFN */
    state autoOn_chargePfn {
        entry {
            autoOnStep = 7;
            pvPut(autoOnStep);
            strcpy(autoMessage, "Step 7: Turning ON Charge PFN...");
            pvPut(autoMessage);
            chargePfnOnCmd = 1;
            pvPut(chargePfnOnCmd);
        }
        when (hvOnOff >= 1.0) {
            strcpy(autoMessage, "Charge PFN Ready - SEQUENCE COMPLETE");
            pvPut(autoMessage);
        } state autoOn_done
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Charge PFN not ready");
            pvPut(autoMessage);
        } state autoOn_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOn_aborted
    }

    state autoOn_done {
        entry {
            autoOnState = 2;  /* Done */
            pvPut(autoOnState);
            autoOnStep = 8;   /* Complete */
            pvPut(autoOnStep);
        }
        when (delay(2.0)) {
        } state idle
    }

    state autoOn_error {
        entry {
            autoOnState = 3;  /* Error */
            pvPut(autoOnState);
        }
        when (delay(5.0)) {
        } state idle
    }

    state autoOn_aborted {
        entry {
            autoOnState = 4;  /* Aborted */
            pvPut(autoOnState);
            autoAbortCmd = 0;
            pvPut(autoAbortCmd);
        }
        when (delay(2.0)) {
        } state idle
    }
}

/* === State Set: Auto OFF Sequence === */
ss autoOffSequence {

    state idle {
        entry {
            autoOffState = 0;  /* Idle */
            pvPut(autoOffState);
            autoOffStep = 0;
            pvPut(autoOffStep);
        }
        when (autoOffCmd == 1) {
            autoOffCmd = 0;
            pvPut(autoOffCmd);
            autoAbortCmd = 0;
            pvPut(autoAbortCmd);
        } state autoOff_chargePfn
    }

    /* Step 1: Charge PFN OFF */
    state autoOff_chargePfn {
        entry {
            autoOffState = 1;  /* Running */
            pvPut(autoOffState);
            autoOffStep = 1;
            pvPut(autoOffStep);
            strcpy(autoMessage, "Step 1: Turning OFF Charge PFN...");
            pvPut(autoMessage);
            chargePfnOffCmd = 1;
            pvPut(chargePfnOffCmd);
        }
        when (hvOnOff < 1.0) {
            strcpy(autoMessage, "Charge PFN OFF");
            pvPut(autoMessage);
        } state autoOff_hvps
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Charge PFN still on");
            pvPut(autoMessage);
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOff_aborted
    }

    /* Step 2: HVPS OFF */
    state autoOff_hvps {
        entry {
            autoOffStep = 2;
            pvPut(autoOffStep);
            strcpy(autoMessage, "Step 2: Turning OFF HVPS...");
            pvPut(autoMessage);
            hvpsOffCmd = 1;
            pvPut(hvpsOffCmd);
        }
        when (hvpsReady < 1.0) {
            strcpy(autoMessage, "HVPS OFF");
            pvPut(autoMessage);
        } state autoOff_premag
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: HVPS still on");
            pvPut(autoMessage);
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOff_aborted
    }

    /* Step 3: Premagnetisation OFF */
    state autoOff_premag {
        entry {
            autoOffStep = 3;
            pvPut(autoOffStep);
            strcpy(autoMessage, "Step 3: Turning OFF Premagnetisation...");
            pvPut(autoMessage);
            premagOffCmd = 1;
            pvPut(premagOffCmd);
        }
        when (premagReady < 1.0) {
            strcpy(autoMessage, "Premagnetisation OFF");
            pvPut(autoMessage);
        } state autoOff_focus
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Premagnetisation still on");
            pvPut(autoMessage);
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOff_aborted
    }

    /* Step 4: Focus OFF */
    state autoOff_focus {
        entry {
            autoOffStep = 4;
            pvPut(autoOffStep);
            strcpy(autoMessage, "Step 4: Turning OFF Focus...");
            pvPut(autoMessage);
            focusOffCmd = 1;
            pvPut(focusOffCmd);
        }
        when (focusReady < 1.0) {
            strcpy(autoMessage, "Focus OFF");
            pvPut(autoMessage);
        } state autoOff_klys100
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Focus still on");
            pvPut(autoMessage);
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOff_aborted
    }

    /* Step 5: Klystron 100% OFF */
    state autoOff_klys100 {
        entry {
            autoOffStep = 5;
            pvPut(autoOffStep);
            strcpy(autoMessage, "Step 5: Turning OFF Klystron 100%...");
            pvPut(autoMessage);
            klys100OffCmd = 1;
            pvPut(klys100OffCmd);
        }
        when (klys100Status < 1.0) {
            strcpy(autoMessage, "Klystron 100% OFF");
            pvPut(autoMessage);
        } state autoOff_klys80
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Klystron 100% still on");
            pvPut(autoMessage);
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOff_aborted
    }

    /* Step 6: Klystron 80% OFF */
    state autoOff_klys80 {
        entry {
            autoOffStep = 6;
            pvPut(autoOffStep);
            strcpy(autoMessage, "Step 6: Turning OFF Klystron 80%...");
            pvPut(autoMessage);
            klys80OffCmd = 1;
            pvPut(klys80OffCmd);
        }
        when (klys80Status < 1.0) {
            strcpy(autoMessage, "Klystron 80% OFF");
            pvPut(autoMessage);
        } state autoOff_thyratron
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Klystron 80% still on");
            pvPut(autoMessage);
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOff_aborted
    }

    /* Step 7: Thyratron OFF */
    state autoOff_thyratron {
        entry {
            autoOffStep = 7;
            pvPut(autoOffStep);
            strcpy(autoMessage, "Step 7: Turning OFF Thyratron...");
            pvPut(autoMessage);
            thyOffCmd = 1;
            pvPut(thyOffCmd);
        }
        when (thyReady < 1.0) {
            strcpy(autoMessage, "Thyratron OFF - SEQUENCE COMPLETE");
            pvPut(autoMessage);
        } state autoOff_done
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Thyratron still on");
            pvPut(autoMessage);
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
        } state autoOff_aborted
    }

    state autoOff_done {
        entry {
            autoOffState = 2;  /* Done */
            pvPut(autoOffState);
            autoOffStep = 8;   /* Complete */
            pvPut(autoOffStep);
        }
        when (delay(2.0)) {
        } state idle
    }

    state autoOff_error {
        entry {
            autoOffState = 3;  /* Error */
            pvPut(autoOffState);
        }
        when (delay(5.0)) {
        } state idle
    }

    state autoOff_aborted {
        entry {
            autoOffState = 4;  /* Aborted */
            pvPut(autoOffState);
            autoAbortCmd = 0;
            pvPut(autoAbortCmd);
        }
        when (delay(2.0)) {
        } state idle
    }
}
