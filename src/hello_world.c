/*
 * Copyright (c) 2013 - 2015, Freescale Semiconductor, Inc.
 * Copyright 2016-2017, 2024 NXP
 * All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "fsl_device_registers.h"
#include "fsl_debug_console.h"
#include "fsl_clock.h"
#include "board.h"
#include "app.h"

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/* Heartbeat LED: toggling every 250 ms gives a full on/off cycle every
 * 500 ms, i.e. a 2 Hz flash. Lets you confirm the firmware is alive
 * without a UART attached. */
#define HEARTBEAT_TOGGLE_MS 250U

/*******************************************************************************
 * Definitions
 ******************************************************************************/

/*******************************************************************************
 * Prototypes
 ******************************************************************************/

/*******************************************************************************
 * Variables
 ******************************************************************************/

/*******************************************************************************
 * Code
 ******************************************************************************/
/*!
 * @brief Main function
 */
int main(void)
{
    uint32_t coreClock_Hz;

    /* Init board hardware. */
    BOARD_InitHardware();

    LED_GREEN_INIT(LOGIC_LED_OFF);
    coreClock_Hz = CLOCK_GetFreq(kCLOCK_SysClk);

    PRINTF("MCUX SDK version: %s\r\n", MCUXSDK_VERSION_FULL_STR);

    PRINTF("hello world.\r\n");

    /* The stock demo echoed UART input here, but GETCHAR() blocks, which
     * would stall the heartbeat whenever nothing was being typed. Blinking
     * is the more useful signal since it needs no UART at all. */
    while (1)
    {
        LED_GREEN_TOGGLE();
        SDK_DelayAtLeastMs(HEARTBEAT_TOGGLE_MS, coreClock_Hz);
    }
}
