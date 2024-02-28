// Amazon FPGA Hardware Development Kit
//
// Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>
#include <unistd.h>

#ifdef SV_TEST
   #include "fpga_pci_sv.h"
#else
   #include <fpga_pci.h>
   #include <fpga_mgmt.h>
   #include <utils/lcd.h>
#endif

#include <utils/sh_dpi_tasks.h>

/* Constants determined by the CL */
/* a set of register offsets; this CL has only one */
/* these register addresses should match the addresses in */
/* /aws-fpga/hdk/cl/examples/common/cl_common_defines.vh */
/* SV_TEST macro should be set if SW/HW co-simulation should be enabled */

#define START_ADDR       UINT64_C(0x00000500)
#define CTR_CUTOFF_ADDR  UINT64_C(0x00000600)
#define CTR_MAX_ADDR     UINT64_C(0x00000700)
#define PHASE_ADDR       UINT64_C(0x00001000)
#define WEIGHT_ADDR_BASE UINT64_C(0x01000000)

/* use the stdout logger for printing debug information  */
#ifndef SV_TEST
const struct logger *logger = &logger_stdout;
/*
 * pci_vendor_id and pci_device_id values below are Amazon's and avaliable to use for a given FPGA slot. 
 * Users may replace these with their own if allocated to them by PCI SIG
 */
static uint16_t pci_vendor_id = 0x1D0F; /* Amazon PCI Vendor ID */
static uint16_t pci_device_id = 0xF000; /* PCI Device ID preassigned by Amazon for F1 applications */

/*
 * check if the corresponding AFI for hello_world is loaded
 */
int check_afi_ready(int slot_id);

void usage(char* program_name) {
    printf("usage: %s [--slot <slot-id>][<poke-value>]\n", program_name);
}

uint32_t byte_swap(uint32_t value);
 
#endif

/*
 * An example to attach to an arbitrary slot, pf, and bar with register access.
 */
int peek_poke_example(uint32_t value, int slot_id, int pf_id, int bar_id);

uint32_t byte_swap(uint32_t value) {
    uint32_t swapped_value = 0;
    int b;
    for (b = 0; b < 4; b++) {
        swapped_value |= ((value >> (b * 8)) & 0xff) << (8 * (3-b));
    }
    return swapped_value;
}

#ifdef SV_TEST
//For cadence and questa simulators the main has to return some value
# ifdef INT_MAIN
int test_main(uint32_t *exit_code)
# else 
void test_main(uint32_t *exit_code)
# endif 
#else 
int main(int argc, char **argv)
#endif
{
    //The statements within SCOPE ifdef below are needed for HW/SW co-simulation with VCS
    #ifdef SCOPE
      svScope scope;
      scope = svGetScopeFromName("tb");
      svSetScope(scope);
    #endif

    uint32_t value = 0xefbeadde;
    int slot_id = 0;
    int rc;
    
#ifndef SV_TEST
    // Process command line args
    {
        int i;
        int value_set = 0;
        for (i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--slot")) {
                i++;
                if (i >= argc) {
                    printf("error: missing slot-id\n");
                    usage(argv[0]);
                    return 1;
                }
                sscanf(argv[i], "%d", &slot_id);
            } else if (!value_set) {
                sscanf(argv[i], "%x", &value);
                value_set = 1;
            } else {
                printf("error: Invalid arg: %s", argv[i]);
                usage(argv[0]);
                return 1;
            }
        }
    }
#endif

    /* initialize the fpga_mgmt library */
    rc = fpga_mgmt_init();
    fail_on(rc, out, "Unable to initialize the fpga_mgmt library");

#ifndef SV_TEST
    rc = check_afi_ready(slot_id);
    fail_on(rc, out, "AFI not ready");
#endif

    
    /* Accessing the CL registers via AppPF BAR0, which maps to sh_cl_ocl_ AXI-Lite bus between AWS FPGA Shell and the CL*/

    printf("===== Starting with peek_poke_example =====\n");
    rc = peek_poke_example(value, slot_id, FPGA_APP_PF, APP_PF_BAR0);
    fail_on(rc, out, "peek-poke example failed");


#ifndef SV_TEST
    return rc;
    
out:
    return 1;
#else

out:
   #ifdef INT_MAIN
   *exit_code = 0;
   return 0;
   #else 
   *exit_code = 0;
   #endif
#endif
}

/* As HW simulation test is not run on a AFI, the below function is not valid */
#ifndef SV_TEST

int check_afi_ready(int slot_id) {
   struct fpga_mgmt_image_info info = {0}; 
   int rc;

   /* get local image description, contains status, vendor id, and device id. */
   rc = fpga_mgmt_describe_local_image(slot_id, &info,0);
   fail_on(rc, out, "Unable to get AFI information from slot %d. Are you running as root?",slot_id);

   /* check to see if the slot is ready */
   if (info.status != FPGA_STATUS_LOADED) {
     rc = 1;
     fail_on(rc, out, "AFI in Slot %d is not in READY state !", slot_id);
   }

   printf("AFI PCI  Vendor ID: 0x%x, Device ID 0x%x\n",
          info.spec.map[FPGA_APP_PF].vendor_id,
          info.spec.map[FPGA_APP_PF].device_id);

   /* confirm that the AFI that we expect is in fact loaded */
   if (info.spec.map[FPGA_APP_PF].vendor_id != pci_vendor_id ||
       info.spec.map[FPGA_APP_PF].device_id != pci_device_id) {
     printf("AFI does not show expected PCI vendor id and device ID. If the AFI "
            "was just loaded, it might need a rescan. Rescanning now.\n");

     rc = fpga_pci_rescan_slot_app_pfs(slot_id);
     fail_on(rc, out, "Unable to update PF for slot %d",slot_id);
     /* get local image description, contains status, vendor id, and device id. */
     rc = fpga_mgmt_describe_local_image(slot_id, &info,0);
     fail_on(rc, out, "Unable to get AFI information from slot %d",slot_id);

     printf("AFI PCI  Vendor ID: 0x%x, Device ID 0x%x\n",
            info.spec.map[FPGA_APP_PF].vendor_id,
            info.spec.map[FPGA_APP_PF].device_id);

     /* confirm that the AFI that we expect is in fact loaded after rescan */
     if (info.spec.map[FPGA_APP_PF].vendor_id != pci_vendor_id ||
         info.spec.map[FPGA_APP_PF].device_id != pci_device_id) {
       rc = 1;
       fail_on(rc, out, "The PCI vendor id and device of the loaded AFI are not "
               "the expected values.");
     }
   }
    
   return rc;
 out:
   return 1;
}

#endif

/*
 * An example to attach to an arbitrary slot, pf, and bar with register access.
 */
int peek_poke_example(uint32_t value, int slot_id, int pf_id, int bar_id) {
    int rc;
    /* pci_bar_handle_t is a handler for an address space exposed by one PCI BAR on one of the PCI PFs of the FPGA */

    pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

    
    /* attach to the fpga, with a pci_bar_handle out param
     * To attach to multiple slots or BARs, call this function multiple times,
     * saving the pci_bar_handle to specify which address space to interact with in
     * other API calls.
     * This function accepts the slot_id, physical function, and bar number
     */
#ifndef SV_TEST
    rc = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
    fail_on(rc, out, "Unable to attach to the AFI on slot id %d", slot_id);
#endif

    /////////////////////////////////////////////
    /// Interface for Ising machine
    /////////////////////////////////////////////
    
    /* write counter configuration */
    printf("Writing 0x%08x to CTR_CUTOFF_ADDR register (0x%016lx)\n", 0x40000000, CTR_CUTOFF_ADDR);
    rc = fpga_pci_poke(pci_bar_handle, CTR_CUTOFF_ADDR, 0x40000000);
    fail_on(rc, out, "Unable to write to the fpga !");

    printf("Writing 0x%08x to CTR_MAX_ADDR register (0x%016lx)\n", 0x80000000, CTR_MAX_ADDR);
    rc = fpga_pci_poke(pci_bar_handle, CTR_MAX_ADDR, 0x80000000);
    fail_on(rc, out, "Unable to write to the fpga !");

    /* write weights */
    printf("Writing weights!\n");

    rc = fpga_pci_poke(pci_bar_handle, 0x01002000, 0x00000001); //AB
    fail_on(rc, out, "Unable to write AB to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, 0x01008000, 0x00000001); //AE
    fail_on(rc, out, "Unable to write AE to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, 0x0100E000, 0x00004000); //AF
    fail_on(rc, out, "Unable to write AF to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, 0x01004004, 0x00000001); //BC
    fail_on(rc, out, "Unable to write BC to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, 0x01006004, 0x00000001); //BD
    fail_on(rc, out, "Unable to write BD to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, 0x0100E004, 0x00004000); //BF
    fail_on(rc, out, "Unable to write BF to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, 0x01006008, 0x00000001); //CD
    fail_on(rc, out, "Unable to write CD to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, 0x0100E008, 0x00004000); //CF
    fail_on(rc, out, "Unable to write CF to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, 0x0100800C, 0x00000001); //DE
    fail_on(rc, out, "Unable to write DE to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, 0x0100E00C, 0x00004000); //DF
    fail_on(rc, out, "Unable to write DF to the fpga !");
    rc = fpga_pci_poke(pci_bar_handle, 0x0100E010, 0x00004000); //EF
    fail_on(rc, out, "Unable to write DF to the fpga !");

    printf("Checking weights!\n");
    rc = fpga_pci_peek(pci_bar_handle, 0x01002000, &value);
    if(value != 0x00000001) {printf("ERROR: AB: 0x%x\n", value);}
    rc = fpga_pci_peek(pci_bar_handle, 0x01008000, &value);
    if(value != 0x00000001) {printf("ERROR: AE: 0x%x\n", value);}
    rc = fpga_pci_peek(pci_bar_handle, 0x0100E000, &value);
    if(value != 0x00004000) {printf("ERROR: AF: 0x%x\n", value);}
    rc = fpga_pci_peek(pci_bar_handle, 0x01004004, &value);
    if(value != 0x00000001) {printf("ERROR: BC: 0x%x\n", value);}
    rc = fpga_pci_peek(pci_bar_handle, 0x01006004, &value);
    if(value != 0x00000001) {printf("ERROR: BD: 0x%x\n", value);}
    rc = fpga_pci_peek(pci_bar_handle, 0x0100E004, &value);
    if(value != 0x00004000) {printf("ERROR: BF: 0x%x\n", value);}
    rc = fpga_pci_peek(pci_bar_handle, 0x01006008, &value);
    if(value != 0x00000001) {printf("ERROR: CD: 0x%x\n", value);}
    rc = fpga_pci_peek(pci_bar_handle, 0x0100E008, &value);
    if(value != 0x00004000) {printf("ERROR: CF: 0x%x\n", value);}
    rc = fpga_pci_peek(pci_bar_handle, 0x0100800C, &value);
    if(value != 0x00000001) {printf("ERROR: DE: 0x%x\n", value);}
    rc = fpga_pci_peek(pci_bar_handle, 0x0100E00C, &value);
    if(value != 0x00004000) {printf("ERROR: DF: 0x%x\n", value);}
    rc = fpga_pci_peek(pci_bar_handle, 0x0100E010, &value);
    if(value != 0x00004000) {printf("ERROR: EF: 0x%x\n", value);}

    /* write to start ising machine */
    printf("Writing 0x%08x to START_ADDR register (0x%016lx)\n", 1, START_ADDR);
    rc = fpga_pci_poke(pci_bar_handle, START_ADDR, 1);
    fail_on(rc, out, "Unable to write to the fpga !");

    /* wait a sec */
    sleep(1);

    printf("==========\n");
    /* read out ising machine result */
    rc = fpga_pci_peek(pci_bar_handle, PHASE_ADDR + 28, &value);
    fail_on(rc, out, "Unable to read read from the fpga !");
    printf("-----\n");
    printf("A : 0x%x\n", value);
    printf("ex: 0x8000\n");

    rc = fpga_pci_peek(pci_bar_handle, PHASE_ADDR + 24, &value);
    fail_on(rc, out, "Unable to read read from the fpga !");
    printf("-----\n");
    printf("B : 0x%x\n", value);
    printf("ex: 0x0\n");

    rc = fpga_pci_peek(pci_bar_handle, PHASE_ADDR + 20, &value);
    fail_on(rc, out, "Unable to read read from the fpga !");
    printf("-----\n");
    printf("C : 0x%x\n", value);
    printf("ex: 0x8000\n");

    rc = fpga_pci_peek(pci_bar_handle, PHASE_ADDR + 16, &value);
    fail_on(rc, out, "Unable to read read from the fpga !");
    printf("-----\n");
    printf("D : 0x%x\n", value);
    printf("ex: 0x8000\n");

    rc = fpga_pci_peek(pci_bar_handle, PHASE_ADDR + 12, &value);
    fail_on(rc, out, "Unable to read read from the fpga !");
    printf("-----\n");
    printf("E : 0x%x\n", value);
    printf("ex: 0x0\n");

    rc = fpga_pci_peek(pci_bar_handle, PHASE_ADDR + 0, &value);
    fail_on(rc, out, "Unable to read read from the fpga !");
    printf("-----\n");
    printf("Lo: 0x%x\n", value);
    printf("ex: 0x1\n");

    /* write to stop ising machine */
    printf("Writing 0x%08x to START_ADDR register (0x%016lx)\n", 0, START_ADDR);
    rc = fpga_pci_poke(pci_bar_handle, START_ADDR, 0);
    fail_on(rc, out, "Unable to write to the fpga !");
 
    
    /////////////////////////////////////////////
    /// Done!
    /////////////////////////////////////////////
out:
    /* clean up */
    if (pci_bar_handle >= 0) {
        rc = fpga_pci_detach(pci_bar_handle);
        if (rc) {
            printf("Failure while detaching from the fpga.\n");
        }
    }

    /* if there is an error code, exit with status 1 */
    return (rc != 0 ? 1 : 0);
}

#ifdef SV_TEST
/*This function is used transfer string buffer from SV to C.
  This function currently returns 0 but can be used to update a buffer on the 'C' side.*/
int send_rdbuf_to_c(char* rd_buf)
{
   return 0;
}

#endif
