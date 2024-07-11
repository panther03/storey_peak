// from https://github.com/racerxdl/pcieledblink/blob/822082e03fddfd774da5dbda1182cb0b9f577f55/prog/test.c
/*
	Use with 
		modprobe uio_pci_generic

	And then:
		echo "1172 00a7" > /sys/bus/pci/drivers/uio_pci_generic/new_id

	Be sure to change the sysfs path below
*/
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>
#include <stdlib.h>

#define MMSIZE (4096) * 3

#define BRAM_BASE 0x1000
#define PTR_BASE 0x2000

void main_loop(uint8_t *ptr) {
	int addr, data;
	while (1) {
		printf("Command? ");
		char c;
		while ((c = getchar()) == '\n') continue;
		switch (c) {
			case 'w': {
				printf("Address,data? ");
				int r = scanf("%d,%d", &addr, &data);
				if (r == 2) {
					ptr[BRAM_BASE + addr] = data;
					printf("ptr[%d]=%d\n", BRAM_BASE + addr * 16, data);
				}
				break;
			}
			case 'p': {
				printf("Address? ");
				int r = scanf("%d", &addr);
				if (r == 1) {
					ptr[PTR_BASE] = addr;
					printf("ptr[%d]=%d\n", BRAM_BASE, addr);
				}
				break;
			}
			case 'q': {
				return;
			}
			default: {
				printf("Unrecognized\n");
			}
		}
	}
}

int main() {
	int f = open("/sys/bus/pci/devices/0000:02:00.0/resource0", O_RDWR);
	if (f == -1 || f == 0) {
		printf("Error opening uio0\n");
		return 1;
	}

	uint8_t *ptr = mmap(0, MMSIZE, PROT_READ | PROT_WRITE, MAP_SHARED, f, 0);
	if (ptr == MAP_FAILED || ptr == 0) {
		printf("Error mapping UIO\n");
		return 1;
	}
	printf("Waiting\n");
	sleep(2);

	main_loop(ptr);

	munmap(ptr, MMSIZE);
	close(f);
	return 0;
}
