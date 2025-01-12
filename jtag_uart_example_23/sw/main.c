#include <stdint.h>
#include <stdlib.h>

#include "riscv.h"
#include "reg.h"
#include "top_defines.h"
#include "lib.h"
#include "jtag_uart.h"

void wait_led_cycle(int ms)
{
    if (REG_RD_FIELD(STATUS, SIMULATION) == 1){
        // Wait for a much shorter time when simulation...
        wait_cycles(100);
    }
    else{
        wait_ms(ms);
    }
}

void help()
{
    jtag_uart_tx_str(
            "r:     reverse LED toggle sequence\n"
            "\n"
        );
}

void spart_unit_test() {
    if (*SPART_CMD_ADDR) {
        jtag_uart_tx_str("Cmd should be 0 at start..\n");
        return;
    }
    *SPART_DATA_ADDR = ((uint32_t)'h') << 24;
    *SPART_DATA_ADDR = ((uint32_t)'e') << 24;
    *SPART_DATA_ADDR = ((uint32_t)'l') << 24;
    *SPART_DATA_ADDR = ((uint32_t)'l') << 24;
    *SPART_DATA_ADDR = ((uint32_t)'o') << 24;
    *SPART_DATA_ADDR = ((uint32_t)'w') << 24;
    *SPART_DATA_ADDR = ((uint32_t)'o') << 24;
    *SPART_DATA_ADDR = ((uint32_t)'r') << 24;
    *SPART_DATA_ADDR = ((uint32_t)'l') << 24;
    *SPART_DATA_ADDR = ((uint32_t)'d') << 24;
    // 9 characters: enough to fill buffer
    if (!*SPART_CMD_ADDR) {
        jtag_uart_tx_str("SPART queue should be full..\n");
    }

    //if (*SPART_DATA_ADDR != 0xFFFF0000) {
    //    jtag_uart_tx_str("Expected SPART to have nothing in receive buffer..");
    //    return;
    //}
    jtag_uart_tx_str("SPART test passed!\n");
}

int main() 
{
    jtag_uart_tx_str("Hello World!\n");

    int reverse_dir = 0;

    //spart_unit_test();

    uint32_t spart_out;
    int ret;
    uint64_t start;

    start = rdcycle64();
    uint64_t endcycles = (uint32_t)CPU_FREQ / 1000UL * 5000; // 5s
    while (1) { //(rdcycle64() - start) <= (uint64_t)endcycles)  {
        // read from VROOM
        while ((spart_out = *SPART_DATA_ADDR) != 0xFFFF0000) {
            //if (spart_out != 0) {
            //    jtag_uart_tx_char((char)(spart_out >> 24));
            //}
            jtag_uart_tx_char((char)(spart_out >> 24));
        }
        unsigned char c;
        ret = jtag_uart_rx_get_char(&c);
        if (ret == 0) continue;

        // escape pressed
        if (c == (unsigned char)0x72) {
            jtag_uart_tx_str("Escape key hit, resetting!\n");
            wait_ms(1000);
    *RESET_ADDR = 0;
        } else {
            *SPART_DATA_ADDR = ((uint32_t)c) << 24;
        }
    }
}
