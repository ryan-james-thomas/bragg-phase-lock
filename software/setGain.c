#include <ctype.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>             //This header is needed for getopt()
#include "rp.h"                 //This header is the Red Pitaya API
#include "rp-i2c-max7311-c.h"   //This header accesses functions for I2C control

#define SET_OUTPUT_GAIN 0       //Flag indicating that the program is setting output gain
#define SET_INPUT_GAIN 1        //Flag indicating that the program is setting the input gain
#define SET_INPUT_COUPLING 2    //Flag indicating that the program is setting the input coupling

int main(int argc, char **argv) {

    char port;      //Port to write to
    char value;     //Value to write
    char flag = 0;  //Output (0) or input (1)
    int status, ch;

    /**
     * Parse input options.  Flags -i, -o, and -c tell the program to set
     * the input attenuation, output gain, and input coupling, respectively.
     * Only one can be set at a time.  -p <value = 1,2> is the channel/port to 
     * set, and -v <value = 0,1> is the value to set.
     */
    int c;
    while ((c = getopt(argc,argv,"p:v:ioc")) != -1) {
        switch (c) {
            case 'p':
                port = atoi(optarg);
                break;
            case 'v':
                value = atoi(optarg);
                break;
            case 'i':
                flag = SET_INPUT_GAIN;
                break;
            case 'o':
                flag = SET_OUTPUT_GAIN;
                break;
            case 'c':
                flag = SET_INPUT_COUPLING;
                break;
            case '?':
                if (isprint (optopt))
                    fprintf (stderr, "Unknown option `-%c'.\n", optopt);
                else
                    fprintf (stderr,
                            "Unknown option character `\\x%x'.\n",
                            optopt);
                return 1;
            default:
                abort();
                break;
        }
    }
    /**
     * Set port/channel to pre-defined constant value understood
     * by the API
     */
    switch (port) {
        case 1:
            port = RP_CH_1;
            break;
        case 2:
            port = RP_CH_2;
            break;
        default:
            fprintf(stderr,"Port must be either 1 or 2!\n");
            return 1;
    }

    /*
     * The examples use rp_Init(), but this resets all systems to
     * their default values.  We just need to initialize the API
     * so we use InitReset(false) which does not reset things.
     * This should be safe to use with other FPGA images
     */
    if (rp_InitReset(false) != RP_OK) {
        fprintf(stderr,"RP API initialization failed!\n");
        return 1;
    }

    /**
     * Set the attenuation, gain, or coupling according to options.
     * The functions used belong to the i2c header
     */
    switch (flag) {
        case SET_INPUT_GAIN:
            ch = (port == RP_CH_1 ? RP_MAX7311_IN1 : RP_MAX7311_IN2);
            int att = (value == 0 ? RP_ATTENUATOR_1_1 : RP_ATTENUATOR_1_20);
            status = rp_setAttenuator_C(ch,att);
            break;
        
        case SET_OUTPUT_GAIN:
            ch = (port == RP_CH_1 ? RP_MAX7311_OUT1 : RP_MAX7311_OUT2);
            status = rp_setGainOut_C(ch,value == 0 ? RP_GAIN_2V : RP_GAIN_10V);
            break;

        case SET_INPUT_COUPLING:
            ch = (port == RP_CH_1 ? RP_MAX7311_IN1 : RP_MAX7311_IN2);
            status = rp_setAC_DC_C(ch,value == 0 ? RP_DC_MODE : RP_AC_MODE);
            break;

        default:
            fprintf(stderr,"Unknown option\n");
            rp_Release();
            return 1;
    }

    if (status != RP_OK) {
        fprintf(stderr,"Error setting parameter\n");
        rp_Release();
        return 1;
    } else {
        rp_Release();
        return 0;
    }
}
