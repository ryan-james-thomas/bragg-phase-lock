//These are libraries which contain useful functions
#include <ctype.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <math.h>
#include <time.h>

#define MAP_SIZE 262144UL
#define DATA_LOC 0x42000000
 
int main(int argc, char **argv)
{
    int fd;		                //File identifier
    int numSamples;	          //Number of samples to collect
    void *cfg;		            //A pointer to a memory location.  The * indicates that it is a pointer - it points to a location in memory
    char *name = "/dev/mem";	//Name of the memory resource

    uint32_t i, incr = 0;
    uint32_t tmp;
    uint32_t *data;
    FILE *ptr;

    /*
    * Parse the input arguments
    */
    if (argc < 2) {
        numSamples = 100;
    } else {
        numSamples = atoi(argv[1]);
    }


    data = (uint32_t *) malloc(numSamples * sizeof(uint32_t));
    if (!data) {
        printf("Error allocating memory");
        return -1;
    }
    //This returns a file identifier corresponding to the memory, and allows for reading and writing.  O_RDWR is just a constant
    if((fd = open(name, O_RDWR)) < 0) {
        perror("open");
        return 1;
    }
    /*
    * mmap maps the memory location 0x40000000 to the pointer cfg, which "points" to that location in memory.
    */
    cfg = mmap(0,MAP_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,DATA_LOC);
    for (i = 0;i<numSamples;i++) {
      *(data + i) = *((uint32_t *)(cfg + (i << 2)));
    }
    /*
     * Save then free data
     */
    ptr = fopen("SavedData.bin","wb");
    fwrite(data,4,(size_t)(numSamples),ptr);
    fclose(ptr);
    free(data);

    //Unmap cfg from pointing to the previous location in memory
    munmap(cfg, MAP_SIZE);
    return 0;	//C functions should have a return value - 0 is the usual "no error" return value
}
