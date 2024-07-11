# Microsoft Storey Peak experiments

documenting microsoft storey peak fpga board

## resources:

- https://github.com/j-marjanovic/jtag-quartus-ft232h#initialization
- https://github.com/racerxdl/pcieledblink/tree/main
- https://github.com/thinkoco/microsoft_fpga
- https://github.com/tow3rs/catapult-v3-smartnic-re
- https://j-marjanovic.io/stratix-v-accelerator-card-from-ebay-part-7.html
- https://github.com/j-marjanovic/pp-sp-reference-design/tree/master
- https://github.com/ruurdk/jtag-quartus-ft323h-windows
- https://www.devops.lol/azure-fpga/
- https://github.com/carlosedp/chisel-fpga-pinfinder/tree/main
- https://github.com/wirebond/catapult_v2_pikes_peak
- https://github.com/ruurdk/storey-peak

## repos credit

[pp-sp-reference-design](https://github.com/j-marjanovic/pp-sp-reference-design)

[jtag_uart_example](https://github.com/tomverbeure/jtag_uart_example/tree/master)

## quick reference

(duplicated elsewhere just keeping for reference)
need to run 

```
openocd \
    -f interface/ftdi/um232h.cfg \
    -c "adapter speed 2000; transport select jtag; jtag newtap auto0 tap -irlen 10 -expected-id 0x029070dd; init; exit;"

```
~ 4 min programming time is normal at this speeed (2000 = 2MHz)

## libjtag_hw_otma.so incompatibility

compiling custom jtag driver for quartus does not work on modern ubuntu (24.04)

quartus loads an old version of libstdc++ and the modules fail to load without the system libstdc++

workaround for now is to use version compiled on old ubuntu (20.04)

## pcie weirdness

https://github.com/racerxdl/pcieledblink does not work

https://github.com/j-marjanovic/pp-sp-reference-design works

Failing behavior:

- System fails to train link
- Hangs scanning of pcie bus (lspci hangs)
- Output of dmesg in `pcie_issue_dmesg.log`
- After reboot, device is missing entirely

Platform: Asus X99 Deluxe

Tried:
- Changing link speed of pcieledblink qsys to PCIe gen2 from gen1 => no change
- Match all qsys settings in pcieledblink for HIP except for link size and avalon width => no change
- Removing other HIP block in pp-sp-reference-design => no change
- Removing all other components in pp-sp-reference-design (nios, ddr3, etc.) => breaks

## saving/restoring flash

TBD, what is the correct format to use for flashing?

JIC? How to generate?

Uses QSPI_256m flash supposedly, but Quartus does not have options to generate for QSPI flash
