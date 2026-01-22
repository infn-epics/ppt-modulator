/*
 * pptAutoSeq.st - State Notation Language program for PPT Modulator
 * 
 * Provides automatic ON and OFF sequencing for the modulator
 * 
 * Auto ON sequence:
 *   1. Thyratron Heater ON → wait for Thy:Status:ContactsOn
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

program pptAutoSeq("P=SPARC:MOD:PPT,R=MOD001,RETRY_DELAY=5.0")

%%#include <stdio.h>
%%#include <string.h>

/* Timeout for each step in seconds */
#define STEP_TIMEOUT    300.0
#define COMMAND_DELAY   1.0
#define DEFAULT_RETRY_DELAY 5.0

/* Retry delay - time between command retries */
double retryDelay = DEFAULT_RETRY_DELAY;

/* Retry counters for tracking attempts */
int onRetryCount;
int offRetryCount;

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
monitor autoOnState;  /* Monitor so OFF sequence can see it */

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

double thyContactsOn;
assign thyContactsOn to "{P}:{R}:Thy:Status:ContactsOn";
monitor thyContactsOn;

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

/* Interlock monitoring */
double generalInterlockRaw;
assign generalInterlockRaw to "{P}:{R}:General:InterlockRaw";
monitor generalInterlockRaw;

/* Thyratron preheat timer - must be 0 before HVPS can be enabled */
double thyPreheatMin;
assign thyPreheatMin to "{P}:{R}:Thy:TimerPreheatMin";
monitor thyPreheatMin;

double thyPreheatSec;
assign thyPreheatSec to "{P}:{R}:Thy:TimerPreheatSec";
monitor thyPreheatSec;

/* === State Set: Auto ON Sequence === */
ss autoOnSequence {

    state idle {
        entry {
            printf("pptAutoSeq ON: Entering IDLE state\n");
            autoOnState = 0;  /* Idle */
            pvPut(autoOnState);
            autoOnStep = 0;
            pvPut(autoOnStep);
            onRetryCount = 0;
        }
        when (autoOnCmd == 1) {
            printf("pptAutoSeq ON: AutoOnCmd received, starting sequence, retryDelay=%.1f\n", retryDelay);
            autoOnCmd = 0;
            pvPut(autoOnCmd);
            autoAbortCmd = 0;
            pvPut(autoAbortCmd);
            onRetryCount = 0;
        } state autoOn_thyratron
    }

    /* Step 1: Thyratron */
    state autoOn_thyratron {
        entry {
            printf("pptAutoSeq ON: Step 1 Thyratron entry, retryCount=%d, thyContactsOn=%.1f, thyReady=%.1f\n", 
                   onRetryCount, thyContactsOn, thyReady);
            autoOnState = 1;  /* Running */
            pvPut(autoOnState);
            autoOnStep = 1;
            pvPut(autoOnStep);
            if (onRetryCount == 0) {
                strcpy(autoMessage, "Step 1: Turning ON Thyratron...");
            } else {
                sprintf(autoMessage, "Step 1: Retry %d - Thyratron ON...", onRetryCount);
            }
            pvPut(autoMessage);
            /* Send command on initial entry */
            thyOnCmd = 1;
            pvPut(thyOnCmd);
            printf("pptAutoSeq ON: *** SENDING thyOnCmd=1 (attempt %d) ***\n", onRetryCount + 1);
            onRetryCount++;
        }
        when (thyContactsOn >= 1.0) {
            printf("pptAutoSeq ON: thyContactsOn=%.1f >= 1.0, moving to klys80\n", thyContactsOn);
            strcpy(autoMessage, "Thyratron Contacts ON");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_klys80
        when (delay(retryDelay) && onRetryCount * retryDelay < STEP_TIMEOUT) {
            /* Re-send command on retry - entry block doesn't re-run on self-transition */
            onRetryCount++;
            printf("pptAutoSeq ON: Retry %d, re-sending thyOnCmd=1\n", onRetryCount);
            sprintf(autoMessage, "Step 1: Retry %d - Thyratron ON...", onRetryCount);
            pvPut(autoMessage);
            thyOnCmd = 1;
            pvPut(thyOnCmd);
        } state autoOn_thyratron
        when (delay(STEP_TIMEOUT)) {
            printf("pptAutoSeq ON: STEP_TIMEOUT reached for thyratron\n");
            strcpy(autoMessage, "TIMEOUT: Thyratron not ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_error
        when (generalInterlockRaw != 0) {
            printf("pptAutoSeq ON: INTERLOCK detected, generalInterlockRaw=%.1f\n", generalInterlockRaw);
            strcpy(autoMessage, "ABORTED: Interlock active");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
        when (autoAbortCmd == 1) {
            printf("pptAutoSeq ON: ABORT command received\n");
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
    }

    /* Step 2: Klystron 80% */
    state autoOn_klys80 {
        entry {
            printf("pptAutoSeq ON: Step 2 Klys80 entry, klys80Status=%.1f\n", klys80Status);
            autoOnStep = 2;
            pvPut(autoOnStep);
            if (onRetryCount == 0) {
                strcpy(autoMessage, "Step 2: Turning ON Klystron 80%...");
            } else {
                sprintf(autoMessage, "Step 2: Retry %d - Klystron 80% ON...", onRetryCount);
            }
            pvPut(autoMessage);
            klys80OnCmd = 1;
            pvPut(klys80OnCmd);
            onRetryCount++;
        }
        when (klys80Status >= 1.0) {
            strcpy(autoMessage, "Klystron 80% Ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_klys100
        when (delay(retryDelay) && onRetryCount * retryDelay < STEP_TIMEOUT) {
            onRetryCount++;
            sprintf(autoMessage, "Step 2: Retry %d - Klystron 80%% ON...", onRetryCount);
            pvPut(autoMessage);
            klys80OnCmd = 1;
            pvPut(klys80OnCmd);
        } state autoOn_klys80
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Klystron 80% not ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_error
        when (generalInterlockRaw != 0) {
            strcpy(autoMessage, "ABORTED: Interlock active");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
    }

    /* Step 3: Klystron 100% */
    state autoOn_klys100 {
        entry {
            autoOnStep = 3;
            pvPut(autoOnStep);
            if (onRetryCount == 0) {
                strcpy(autoMessage, "Step 3: Turning ON Klystron 100%...");
            } else {
                sprintf(autoMessage, "Step 3: Retry %d - Klystron 100% ON...", onRetryCount);
            }
            pvPut(autoMessage);
            klys100OnCmd = 1;
            pvPut(klys100OnCmd);
            onRetryCount++;
        }
        when (klys100Status >= 1.0) {
            strcpy(autoMessage, "Klystron 100% Ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_focus
        when (delay(retryDelay) && onRetryCount * retryDelay < STEP_TIMEOUT) {
            onRetryCount++;
            sprintf(autoMessage, "Step 3: Retry %d - Klystron 100%% ON...", onRetryCount);
            pvPut(autoMessage);
            klys100OnCmd = 1;
            pvPut(klys100OnCmd);
        } state autoOn_klys100
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Klystron 100% not ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_error
        when (generalInterlockRaw != 0) {
            strcpy(autoMessage, "ABORTED: Interlock active");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
    }

    /* Step 4: Focus */
    state autoOn_focus {
        entry {
            autoOnStep = 4;
            pvPut(autoOnStep);
            if (onRetryCount == 0) {
                strcpy(autoMessage, "Step 4: Turning ON Focus...");
            } else {
                sprintf(autoMessage, "Step 4: Retry %d - Focus ON...", onRetryCount);
            }
            pvPut(autoMessage);
            focusOnCmd = 1;
            pvPut(focusOnCmd);
            onRetryCount++;
        }
        when (focusReady >= 1.0) {
            strcpy(autoMessage, "Focus Ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_premag
        when (delay(retryDelay) && onRetryCount * retryDelay < STEP_TIMEOUT) {
            onRetryCount++;
            sprintf(autoMessage, "Step 4: Retry %d - Focus ON...", onRetryCount);
            pvPut(autoMessage);
            focusOnCmd = 1;
            pvPut(focusOnCmd);
        } state autoOn_focus
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Focus not ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_error
        when (generalInterlockRaw != 0) {
            strcpy(autoMessage, "ABORTED: Interlock active");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
    }

    /* Step 5: Premagnetisation */
    state autoOn_premag {
        entry {
            autoOnStep = 5;
            pvPut(autoOnStep);
            if (onRetryCount == 0) {
                strcpy(autoMessage, "Step 5: Turning ON Premagnetisation...");
            } else {
                sprintf(autoMessage, "Step 5: Retry %d - Premag ON...", onRetryCount);
            }
            pvPut(autoMessage);
            premagOnCmd = 1;
            pvPut(premagOnCmd);
            onRetryCount++;
        }
        when (premagReady >= 1.0) {
            strcpy(autoMessage, "Premagnetisation Ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_waitPreheat
        when (delay(retryDelay) && onRetryCount * retryDelay < STEP_TIMEOUT) {
            onRetryCount++;
            sprintf(autoMessage, "Step 5: Retry %d - Premag ON...", onRetryCount);
            pvPut(autoMessage);
            premagOnCmd = 1;
            pvPut(premagOnCmd);
        } state autoOn_premag
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Premagnetisation not ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_error
        when (generalInterlockRaw != 0) {
            strcpy(autoMessage, "ABORTED: Interlock active");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
    }

    /* Wait for Thyratron preheat timer to elapse before enabling HVPS */
    state autoOn_waitPreheat {
        entry {
            printf("pptAutoSeq ON: Waiting for preheat timer, min=%.0f sec=%.0f\n", thyPreheatMin, thyPreheatSec);
            if (thyPreheatMin > 0 || thyPreheatSec > 0) {
                sprintf(autoMessage, "Waiting for preheat: %d:%02d remaining", (int)thyPreheatMin, (int)thyPreheatSec);
            } else {
                strcpy(autoMessage, "Preheat complete");
            }
            pvPut(autoMessage);
        }
        when (thyPreheatMin <= 0 && thyPreheatSec <= 0) {
            printf("pptAutoSeq ON: Preheat complete, proceeding to HVPS\n");
            strcpy(autoMessage, "Preheat complete - enabling HVPS");
            pvPut(autoMessage);
        } state autoOn_hvps
        when (delay(1.0) && (thyPreheatMin > 0 || thyPreheatSec > 0)) {
            /* Update message every second while waiting */
            sprintf(autoMessage, "Waiting for preheat: %d:%02d remaining", (int)thyPreheatMin, (int)thyPreheatSec);
            pvPut(autoMessage);
        } state autoOn_waitPreheat
        when (generalInterlockRaw != 0) {
            strcpy(autoMessage, "ABORTED: Interlock active");
            pvPut(autoMessage);
        } state autoOn_aborted
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
            if (onRetryCount == 0) {
                strcpy(autoMessage, "Step 6: Turning ON HVPS...");
            } else {
                sprintf(autoMessage, "Step 6: Retry %d - HVPS ON...", onRetryCount);
            }
            pvPut(autoMessage);
            hvpsOnCmd = 1;
            pvPut(hvpsOnCmd);
            onRetryCount++;
        }
        when (hvpsReady >= 1.0) {
            strcpy(autoMessage, "HVPS Ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_chargePfn
        when (delay(retryDelay) && onRetryCount * retryDelay < STEP_TIMEOUT) {
            onRetryCount++;
            sprintf(autoMessage, "Step 6: Retry %d - HVPS ON...", onRetryCount);
            pvPut(autoMessage);
            hvpsOnCmd = 1;
            pvPut(hvpsOnCmd);
        } state autoOn_hvps
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: HVPS not ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_error
        when (generalInterlockRaw != 0) {
            strcpy(autoMessage, "ABORTED: Interlock active");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
    }

    /* Step 7: Charge PFN */
    state autoOn_chargePfn {
        entry {
            autoOnStep = 7;
            pvPut(autoOnStep);
            if (onRetryCount == 0) {
                strcpy(autoMessage, "Step 7: Turning ON Charge PFN...");
            } else {
                sprintf(autoMessage, "Step 7: Retry %d - Charge PFN ON...", onRetryCount);
            }
            pvPut(autoMessage);
            chargePfnOnCmd = 1;
            pvPut(chargePfnOnCmd);
            onRetryCount++;
        }
        when (hvOnOff >= 1.0) {
            strcpy(autoMessage, "Charge PFN Ready - SEQUENCE COMPLETE");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_done
        when (delay(retryDelay) && onRetryCount * retryDelay < STEP_TIMEOUT) {
            onRetryCount++;
            sprintf(autoMessage, "Step 7: Retry %d - Charge PFN ON...", onRetryCount);
            pvPut(autoMessage);
            chargePfnOnCmd = 1;
            pvPut(chargePfnOnCmd);
        } state autoOn_chargePfn
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Charge PFN not ready");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_error
        when (generalInterlockRaw != 0) {
            strcpy(autoMessage, "ABORTED: Interlock active");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            onRetryCount = 0;
        } state autoOn_aborted
    }

    state autoOn_done {
        entry {
            printf("pptAutoSeq ON: DONE - Entering done state\n");
            autoOnState = 2;  /* Done */
            pvPut(autoOnState);
            autoOnStep = 8;   /* Complete */
            pvPut(autoOnStep);
        }
        when (delay(2.0)) {
            printf("pptAutoSeq ON: Done timeout, returning to idle\n");
        } state idle
    }

    state autoOn_error {
        entry {
            printf("pptAutoSeq ON: ERROR - Entering error state\n");
            autoOnState = 3;  /* Error */
            pvPut(autoOnState);
        }
        when (delay(5.0)) {
            printf("pptAutoSeq ON: Error timeout, returning to idle\n");
        } state idle
    }

    state autoOn_aborted {
        entry {
            printf("pptAutoSeq ON: ABORTED - Entering aborted state, clearing autoAbortCmd\n");
            autoOnState = 4;  /* Aborted */
            pvPut(autoOnState);
            autoAbortCmd = 0;
            pvPut(autoAbortCmd);
        }
        when (delay(2.0)) {
            printf("pptAutoSeq ON: Aborted timeout, returning to idle\n");
        } state idle
    }
}

/* === State Set: Auto OFF Sequence === */
ss autoOffSequence {

    state idle {
        entry {
            printf("pptAutoSeq OFF: Entering IDLE state, autoOnState=%d\n", autoOnState);
            autoOffState = 0;  /* Idle */
            pvPut(autoOffState);
            autoOffStep = 0;
            pvPut(autoOffStep);
            offRetryCount = 0;
        }
        when (autoOffCmd == 1) {
            printf("pptAutoSeq OFF: AutoOffCmd received, autoOnState=%d\n", autoOnState);
            autoOffCmd = 0;
            pvPut(autoOffCmd);
            /* If Auto ON is running, abort it first */
            if (autoOnState == 1) {  /* Running */
                printf("pptAutoSeq OFF: AutoON is running, sending abort\n");
                autoAbortCmd = 1;
                pvPut(autoAbortCmd);
            }
            offRetryCount = 0;
        } state autoOff_waitAbort
        when (autoOffCmd == 0 && autoOnState != 1) {
            /* Not used, but keeps state machine clean */
        } state idle
    }

    /* Wait for Auto ON to abort if it was running */
    state autoOff_waitAbort {
        entry {
            printf("pptAutoSeq OFF: Waiting for AutoON abort, autoOnState=%d, autoAbortCmd=%d\n", 
                   autoOnState, autoAbortCmd);
        }
        when (delay(0.5) || autoOnState != 1) {
            printf("pptAutoSeq OFF: Wait done, autoOnState=%d, proceeding to step 1\n", autoOnState);
            autoAbortCmd = 0;
            pvPut(autoAbortCmd);
        } state autoOff_chargePfn
    }

    /* Step 1: Charge PFN OFF */
    state autoOff_chargePfn {
        entry {
            printf("pptAutoSeq OFF: Step 1 ChargePFN entry, hvOnOff=%.1f, retryCount=%d\n", 
                   hvOnOff, offRetryCount);
            autoOffState = 1;  /* Running */
            pvPut(autoOffState);
            autoOffStep = 1;
            pvPut(autoOffStep);
            if (offRetryCount == 0) {
                strcpy(autoMessage, "Step 1: Turning OFF Charge PFN...");
            } else {
                sprintf(autoMessage, "Step 1: Retry %d - Charge PFN OFF...", offRetryCount);
            }
            pvPut(autoMessage);
            chargePfnOffCmd = 1;
            pvPut(chargePfnOffCmd);
            printf("pptAutoSeq OFF: Sent chargePfnOffCmd=1\n");
            offRetryCount++;
        }
        when (hvOnOff < 1.0) {
            printf("pptAutoSeq OFF: hvOnOff=%.1f < 1.0, moving to hvps\n", hvOnOff);
            strcpy(autoMessage, "Charge PFN OFF");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_hvps
        when (delay(retryDelay) && offRetryCount * retryDelay < STEP_TIMEOUT) {
            offRetryCount++;
            printf("pptAutoSeq OFF: Retry %d, re-sending chargePfnOffCmd=1\n", offRetryCount);
            sprintf(autoMessage, "Step 1: Retry %d - Charge PFN OFF...", offRetryCount);
            pvPut(autoMessage);
            chargePfnOffCmd = 1;
            pvPut(chargePfnOffCmd);
        } state autoOff_chargePfn
        when (delay(STEP_TIMEOUT)) {
            printf("pptAutoSeq OFF: TIMEOUT for ChargePFN\n");
            strcpy(autoMessage, "TIMEOUT: Charge PFN still on");;
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_aborted
    }

    /* Step 2: HVPS OFF */
    state autoOff_hvps {
        entry {
            autoOffStep = 2;
            pvPut(autoOffStep);
            if (offRetryCount == 0) {
                strcpy(autoMessage, "Step 2: Turning OFF HVPS...");
            } else {
                sprintf(autoMessage, "Step 2: Retry %d - HVPS OFF...", offRetryCount);
            }
            pvPut(autoMessage);
            hvpsOffCmd = 1;
            pvPut(hvpsOffCmd);
            offRetryCount++;
        }
        when (hvpsReady < 1.0) {
            strcpy(autoMessage, "HVPS OFF");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_premag
        when (delay(retryDelay) && offRetryCount * retryDelay < STEP_TIMEOUT) {
            offRetryCount++;
            sprintf(autoMessage, "Step 2: Retry %d - HVPS OFF...", offRetryCount);
            pvPut(autoMessage);
            hvpsOffCmd = 1;
            pvPut(hvpsOffCmd);
        } state autoOff_hvps
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: HVPS still on");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_aborted
    }

    /* Step 3: Premagnetisation OFF */
    state autoOff_premag {
        entry {
            autoOffStep = 3;
            pvPut(autoOffStep);
            if (offRetryCount == 0) {
                strcpy(autoMessage, "Step 3: Turning OFF Premagnetisation...");
            } else {
                sprintf(autoMessage, "Step 3: Retry %d - Premag OFF...", offRetryCount);
            }
            pvPut(autoMessage);
            premagOffCmd = 1;
            pvPut(premagOffCmd);
            offRetryCount++;
        }
        when (premagReady < 1.0) {
            strcpy(autoMessage, "Premagnetisation OFF");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_focus
        when (delay(retryDelay) && offRetryCount * retryDelay < STEP_TIMEOUT) {
            offRetryCount++;
            sprintf(autoMessage, "Step 3: Retry %d - Premag OFF...", offRetryCount);
            pvPut(autoMessage);
            premagOffCmd = 1;
            pvPut(premagOffCmd);
        } state autoOff_premag
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Premagnetisation still on");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_aborted
    }

    /* Step 4: Focus OFF */
    state autoOff_focus {
        entry {
            autoOffStep = 4;
            pvPut(autoOffStep);
            if (offRetryCount == 0) {
                strcpy(autoMessage, "Step 4: Turning OFF Focus...");
            } else {
                sprintf(autoMessage, "Step 4: Retry %d - Focus OFF...", offRetryCount);
            }
            pvPut(autoMessage);
            focusOffCmd = 1;
            pvPut(focusOffCmd);
            offRetryCount++;
        }
        when (focusReady < 1.0) {
            strcpy(autoMessage, "Focus OFF");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_klys100
        when (delay(retryDelay) && offRetryCount * retryDelay < STEP_TIMEOUT) {
            offRetryCount++;
            sprintf(autoMessage, "Step 4: Retry %d - Focus OFF...", offRetryCount);
            pvPut(autoMessage);
            focusOffCmd = 1;
            pvPut(focusOffCmd);
        } state autoOff_focus
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Focus still on");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_aborted
    }

    /* Step 5: Klystron 100% OFF */
    state autoOff_klys100 {
        entry {
            autoOffStep = 5;
            pvPut(autoOffStep);
            if (offRetryCount == 0) {
                strcpy(autoMessage, "Step 5: Turning OFF Klystron 100%...");
            } else {
                sprintf(autoMessage, "Step 5: Retry %d - Klystron 100% OFF...", offRetryCount);
            }
            pvPut(autoMessage);
            klys100OffCmd = 1;
            pvPut(klys100OffCmd);
            offRetryCount++;
        }
        when (klys100Status < 1.0) {
            strcpy(autoMessage, "Klystron 100% OFF");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_klys80
        when (delay(retryDelay) && offRetryCount * retryDelay < STEP_TIMEOUT) {
            offRetryCount++;
            sprintf(autoMessage, "Step 5: Retry %d - Klystron 100%% OFF...", offRetryCount);
            pvPut(autoMessage);
            klys100OffCmd = 1;
            pvPut(klys100OffCmd);
        } state autoOff_klys100
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Klystron 100% still on");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_aborted
    }

    /* Step 6: Klystron 80% OFF */
    state autoOff_klys80 {
        entry {
            autoOffStep = 6;
            pvPut(autoOffStep);
            if (offRetryCount == 0) {
                strcpy(autoMessage, "Step 6: Turning OFF Klystron 80%...");
            } else {
                sprintf(autoMessage, "Step 6: Retry %d - Klystron 80% OFF...", offRetryCount);
            }
            pvPut(autoMessage);
            klys80OffCmd = 1;
            pvPut(klys80OffCmd);
            offRetryCount++;
        }
        when (klys80Status < 1.0) {
            strcpy(autoMessage, "Klystron 80% OFF");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_thyratron
        when (delay(retryDelay) && offRetryCount * retryDelay < STEP_TIMEOUT) {
            offRetryCount++;
            sprintf(autoMessage, "Step 6: Retry %d - Klystron 80%% OFF...", offRetryCount);
            pvPut(autoMessage);
            klys80OffCmd = 1;
            pvPut(klys80OffCmd);
        } state autoOff_klys80
        when (delay(STEP_TIMEOUT)) {
            strcpy(autoMessage, "TIMEOUT: Klystron 80% still on");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_error
        when (autoAbortCmd == 1) {
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_aborted
    }

    /* Step 7: Thyratron OFF */
    state autoOff_thyratron {
        entry {
            printf("pptAutoSeq OFF: Step 7 Thyratron entry, thyReady=%.1f, thyContactsOn=%.1f, retryCount=%d\n", 
                   thyReady, thyContactsOn, offRetryCount);
            autoOffStep = 7;
            pvPut(autoOffStep);
            if (offRetryCount == 0) {
                strcpy(autoMessage, "Step 7: Turning OFF Thyratron...");
            } else {
                sprintf(autoMessage, "Step 7: Retry %d - Thyratron OFF...", offRetryCount);
            }
            pvPut(autoMessage);
            thyOffCmd = 1;
            pvPut(thyOffCmd);
            printf("pptAutoSeq OFF: Sent thyOffCmd=1\n");
            offRetryCount++;
        }
        /* Check thyContactsOn < 1.0 - matches ON sequence which waits for thyContactsOn >= 1.0 */
        when (thyContactsOn < 1.0) {
            printf("pptAutoSeq OFF: thyContactsOn=%.1f < 1.0, SEQUENCE COMPLETE\n", thyContactsOn);
            strcpy(autoMessage, "Thyratron OFF - SEQUENCE COMPLETE");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_done
        when (delay(retryDelay) && offRetryCount * retryDelay < STEP_TIMEOUT) {
            offRetryCount++;
            printf("pptAutoSeq OFF: Retry %d, re-sending thyOffCmd=1\n", offRetryCount);
            sprintf(autoMessage, "Step 7: Retry %d - Thyratron OFF...", offRetryCount);
            pvPut(autoMessage);
            thyOffCmd = 1;
            pvPut(thyOffCmd);
        } state autoOff_thyratron
        when (delay(STEP_TIMEOUT)) {
            printf("pptAutoSeq OFF: TIMEOUT for Thyratron\n");
            strcpy(autoMessage, "TIMEOUT: Thyratron still on");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_error
        when (autoAbortCmd == 1) {
            printf("pptAutoSeq OFF: ABORT command in thyratron step\n");
            strcpy(autoMessage, "ABORTED by user");
            pvPut(autoMessage);
            offRetryCount = 0;
        } state autoOff_aborted
    }

    state autoOff_done {
        entry {
            printf("pptAutoSeq OFF: DONE - Entering done state\n");
            autoOffState = 2;  /* Done */
            pvPut(autoOffState);
            autoOffStep = 8;   /* Complete */
            pvPut(autoOffStep);
        }
        when (delay(2.0)) {
            printf("pptAutoSeq OFF: Done timeout, returning to idle\n");
        } state idle
    }

    state autoOff_error {
        entry {
            printf("pptAutoSeq OFF: ERROR - Entering error state\n");
            autoOffState = 3;  /* Error */
            pvPut(autoOffState);
        }
        when (delay(5.0)) {
            printf("pptAutoSeq OFF: Error timeout, returning to idle\n");
        } state idle
    }

    state autoOff_aborted {
        entry {
            printf("pptAutoSeq OFF: ABORTED - Entering aborted state\n");
            autoOffState = 4;  /* Aborted */
            pvPut(autoOffState);
            autoAbortCmd = 0;
            pvPut(autoAbortCmd);
        }
        when (delay(2.0)) {
            printf("pptAutoSeq OFF: Aborted timeout, returning to idle\n");
        } state idle
    }
}
