/*
Copyright (c) 2021 Jan Marjanovic

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "IDT8NxQ001.h"

static const int NR_CH = IDT8NXQ001_NR_CH;

struct idt8nxq001_freq_conf {
  uint8_t MINT;
  uint32_t MFRAC;
  uint8_t N;
  uint8_t P;
  bool DSM_ENA;
};

static struct idt8nxq001_freq_conf
    idt8nxq001_freq_confs[IDT8NXQ001_FREQ_COUNT] = {
        [IDT8NXQ001_FREQ_100M] =
            {.MINT = 24, .MFRAC = 0, .N = 24, .P = 0, .DSM_ENA = 0},
        [IDT8NXQ001_FREQ_125M] =
            {.MINT = 25, .MFRAC = 0, .N = 20, .P = 0, .DSM_ENA = 0},
        [IDT8NXQ001_FREQ_156p25M] =
            {.MINT = 25, .MFRAC = 0, .N = 16, .P = 0, .DSM_ENA = 0},
        [IDT8NXQ001_FREQ_200M] =
            {.MINT = 24, .MFRAC = 0, .N = 12, .P = 0, .DSM_ENA = 0},
        [IDT8NXQ001_FREQ_300M] =
            {.MINT = 24, .MFRAC = 0, .N = 8, .P = 0, .DSM_ENA = 0},
        [IDT8NXQ001_FREQ_312p5M] =
            {.MINT = 25, .MFRAC = 0, .N = 8, .P = 0, .DSM_ENA = 0},
};

static const unsigned int MINT_MAX = (1 << 6) - 1;
static const unsigned int MFRAC_MAX = (1 << 18) - 1;
static const unsigned int N_MAX = (1 << 7) - 1;
static const unsigned int P_MAX = (1 << 2) - 1;
static const unsigned int DSM_MAX = (1 << 2) - 1;
static const unsigned int CP_MAX = (1 << 2) - 1;

void idt8nxq001_decode_conf(const uint8_t conf_bytes[24],
                            struct idt8nxq001_conf *conf) {
  assert(conf);

  memset(conf, 0, sizeof(struct idt8nxq001_conf));

  for (int i = 0; i < NR_CH; i++) {
    conf->MINT[i] =
        ((conf_bytes[0 + i] >> 1) & 0x1F) | (conf_bytes[20 + i] & (1 << 5));
  }

  for (int i = 0; i < NR_CH; i++) {
    conf->MFRAC[i] = ((conf_bytes[0 + i] & 0x1) << 17) |
                     (conf_bytes[4 + i] << 9) | (conf_bytes[8 + i] << 1) |
                     ((conf_bytes[12 + i] >> 7) & 0x1);
  }

  for (int i = 0; i < NR_CH; i++) {
    conf->N[i] = conf_bytes[12 + i] & 0x7F;
  }

  for (int i = 0; i < NR_CH; i++) {
    conf->P[i] = (conf_bytes[20 + i] >> 6) & 0x3;
  }

  for (int i = 0; i < NR_CH; i++) {
    conf->DG[i] = (conf_bytes[20 + i] >> 2) & 0x1;
  }

  for (int i = 0; i < NR_CH; i++) {
    conf->DSM[i] = (conf_bytes[20 + i] >> 3) & 0x3;
  }

  for (int i = 0; i < NR_CH; i++) {
    conf->DSM_ENA[i] = (conf_bytes[20 + i] >> 1) & 0x1;
  }

  for (int i = 0; i < NR_CH; i++) {
    conf->LF[i] = conf_bytes[20 + i] & 0x1;
  }

  for (int i = 0; i < NR_CH; i++) {
    conf->CP[i] = (conf_bytes[0 + i] >> 6) & 0x3;
  }

  conf->FSEL = (conf_bytes[18] >> 3) & 0x3;
  conf->nPLL_BYP = (conf_bytes[18] >> 5) & 0x1;
  conf->ADC_ENA = (conf_bytes[18] >> 7) & 0x1;
}

void idt8nxq001_encode_conf(const struct idt8nxq001_conf *conf,
                            uint8_t conf_bytes[24]) {

  for (int i = 0; i < NR_CH; i++) {
    assert(conf->MINT[i] <= MINT_MAX);
    assert(conf->MFRAC[i] <= MFRAC_MAX);
    assert(conf->N[i] <= N_MAX);
    assert(conf->P[i] <= P_MAX);
    assert(conf->DSM[i] <= DSM_MAX);
    assert(conf->CP[i] <= CP_MAX);
  }

  for (int i = 0; i < NR_CH; i++) {
    conf_bytes[0 + i] = (conf->CP[i] << 6) | ((conf->MINT[i] & 0x1F) << 1) |
                        ((conf->MFRAC[i] >> 17) & 0x1);
  }

  for (int i = 0; i < NR_CH; i++) {
    conf_bytes[4 + i] = (conf->MFRAC[i] >> 9);
  }

  for (int i = 0; i < NR_CH; i++) {
    conf_bytes[8 + i] = (conf->MFRAC[i] >> 1);
  }

  for (int i = 0; i < NR_CH; i++) {
    conf_bytes[12 + i] = ((conf->MFRAC[i] & 0x1) << 7) | conf->N[i];
  }

  conf_bytes[16] = 0;
  conf_bytes[17] = 0;
  conf_bytes[18] =
      (conf->ADC_ENA << 7) | (conf->nPLL_BYP << 5) | (conf->FSEL << 3);
  conf_bytes[19] = 0;

  for (int i = 0; i < NR_CH; i++) {
    conf_bytes[20 + i] = (conf->P[i] << 6) |
                         (((conf->MINT[i] >> 5) & 0x1) << 5) |
                         (conf->DSM[i] << 3) | (conf->DG[i] << 2) |
                         (conf->DSM_ENA[i] << 1) | (conf->LF[i]);
  }
}

void idt8nxq001_conf_print(const struct idt8nxq001_conf *conf) {

  alt_printf("IDT8NXQ001 config:\n");

  alt_printf("  MINT     :");
  for (int i = 0; i < NR_CH; i++) {
    alt_printf(" %x", conf->MINT[i]);
  }
  alt_printf("\n");

  alt_printf("  MFRAC    :");
  for (int i = 0; i < NR_CH; i++) {
    alt_printf(" %x", conf->MFRAC[i]);
  }
  alt_printf("\n");

  alt_printf("  N        :");
  for (int i = 0; i < NR_CH; i++) {
    alt_printf(" %x", conf->N[i]);
  }
  alt_printf("\n");

  alt_printf("  P        :");
  for (int i = 0; i < NR_CH; i++) {
    alt_printf(" %x", conf->P[i]);
  }
  alt_printf("\n");

  // DG not printed
  // DSM not printed

  alt_printf("  DSM_ENA  :");
  for (int i = 0; i < NR_CH; i++) {
    alt_printf(" %x", conf->DSM_ENA[i]);
  }
  alt_printf("\n");

  alt_printf("  LF       :");
  for (int i = 0; i < NR_CH; i++) {
    alt_printf(" %x", conf->LF[i]);
  }
  alt_printf("\n");

  alt_printf("  CP       :");
  for (int i = 0; i < NR_CH; i++) {
    alt_printf(" %x", conf->CP[i]);
  }
  alt_printf("\n");

  alt_printf("  FSEL     : %x\n", conf->FSEL);
  alt_printf("  nPLL_BYP : %x\n", conf->nPLL_BYP);
  alt_printf("  ADC_ENA  : %x\n", conf->ADC_ENA);
}

void idt8nxq001_set_freq(struct idt8nxq001_conf *conf, unsigned int ch_sel,
                         enum IDT8NXQ001_FREQ freq) {
  conf->DSM_ENA[ch_sel] = 0;
  conf->DSM[ch_sel] = 0x3;
  conf->LF[ch_sel] = 1;
  conf->DG[ch_sel] = 1;

  const struct idt8nxq001_freq_conf *freq_conf = &idt8nxq001_freq_confs[freq];
  conf->MINT[ch_sel] = freq_conf->MINT;
  conf->MFRAC[ch_sel] = freq_conf->MFRAC;
  conf->N[ch_sel] = freq_conf->N;
  conf->P[ch_sel] = freq_conf->P;
  conf->DSM_ENA[ch_sel] = freq_conf->DSM_ENA;

  // CP depends on DSA_ENA
  conf->CP[ch_sel] = freq_conf->DSM_ENA ? 0 : 0x3;
}

void idt8nxq001_set_fsel(struct idt8nxq001_conf *conf, uint8_t fsel) {
  conf->FSEL = fsel;
}
