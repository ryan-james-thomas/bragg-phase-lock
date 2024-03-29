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
#define MEM_LOC 0x40000000
#define DATA_LOC1 0x00000028
#define DATA_LOC2 0x0000002C
#define DATA_LOC3 0x00000030
#define DATA_LOC4 0x00000034
#define DATA_LOC5 0x00000038
#define FIFO_LOC 0x00000024
 
int main(int argc, char **argv)
{
  int fd;		//File identifier
  int numSamples;	//Number of samples to collect
  int dataSize;   //Size of actual data array
  void *cfg;		//A pointer to a memory location.  The * indicates that it is a pointer - it points to a location in memory
  char *name = "/dev/mem";	//Name of the memory resource

  uint32_t i, incr = 0;
  uint8_t saveType = 2;
  uint8_t saveStreams = 0;
  uint32_t tmp;
  uint32_t *data;
  uint8_t startFlag = 0;
  uint8_t debugFlag = 0;
  FILE *ptr;

  clock_t start, stop;

  /*
   * Parse the input arguments
   */
  int c;
  while ((c = getopt(argc,argv,"n:t:psdbf")) != -1) {
    switch (c) {
      case 'n':
        numSamples = atoi(optarg);
        break;
      case 't':
        saveType = atoi(optarg);
        break;
      case 'p':
        saveStreams += 0b1;
        break;
      case 's':
        saveStreams += 0b10;
        break;
      case 'd':
        saveStreams += 0b100;
        break;
      case 'b':
        startFlag = 1;
        break;
      case 'f':
        debugFlag = 1;
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

  uint8_t saveFactor = (saveStreams & 1) + ((saveStreams & 0b10) >> 1) + ((saveStreams & 0b100) >> 2) +  ((saveStreams & 0b1000) >> 3) +  ((saveStreams & 0b10000) >> 4);
  // printf("Save factor: %d\n",saveFactor);
  dataSize = saveFactor*numSamples;

  if (saveType == 2) {
    ptr = fopen("SavedData.bin","wb");
  } else {
    data = (uint32_t *) malloc(dataSize * sizeof(uint32_t));
    if (!data) {
      printf("Error allocating memory");
      return -1;
    }
  }
  

  //This returns a file identifier corresponding to the memory, and allows for reading and writing.  O_RDWR is just a constant
  if((fd = open(name, O_RDWR)) < 0) {
    perror("open");
    return 1;
  }

  /*mmap maps the memory location 0x40000000 to the pointer cfg, which "points" to that location in memory.*/
//  cfg = mmap(0,MAP_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,MEM_LOC);
  cfg = mmap(0,MAP_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,MEM_LOC);

  //Disable FIFO
  *((uint32_t *)(cfg + FIFO_LOC)) = 0;
//  printf("FIFO Disabled!\n");
  //Reset FIFO
  *((uint32_t *)(cfg + 0)) = (1 << 2);
//  printf("FIFO Reset!\n");
  usleep(1000);
  //Enable FIFO
  *((uint32_t *)(cfg + FIFO_LOC)) = 1;
  if (startFlag == 1) {
    *((uint32_t *)(cfg + 0)) = (1 << 1);
  }
//  printf("FIFO Enabled!\n");
  //Record data
  if (saveType == 1 | saveType == 2) {
    start = clock();
  }
  
  if (saveType != 2) {
    for (i = 0;i<dataSize;i += saveFactor) {
      incr = 0;
      if (saveStreams & 0b1) {
        *(data + i + incr++) = *((uint32_t *)(cfg + DATA_LOC1));
      }
      if (saveStreams & 0b10) {
        *(data + i + incr++) = *((uint32_t *)(cfg + DATA_LOC2));
      }
      if (saveStreams & 0b100) {
        *(data + i + incr++) = *((uint32_t *)(cfg + DATA_LOC3));
      }
      if (saveStreams & 0b1000) {
        *(data + i + incr++) = *((uint32_t *)(cfg + DATA_LOC4));
      }
      if (saveStreams & 0b10000) {
        *(data + i + incr++) = *((uint32_t *)(cfg + DATA_LOC5));
      }
    }
  } else {
    for (i = 0;i<dataSize;i += saveFactor) {
      if (saveStreams & 0b1) {
        tmp = *((uint32_t *)(cfg + DATA_LOC1));
        fwrite(&tmp,4,1,ptr);
      }
      if (saveStreams & 0b10) {
        tmp = *((uint32_t *)(cfg + DATA_LOC2));
        fwrite(&tmp,4,1,ptr);
      }
      if (saveStreams & 0b100) {
        tmp = *((uint32_t *)(cfg + DATA_LOC3));
        fwrite(&tmp,4,1,ptr);
      }
      if (saveStreams & 0b1000) {
        tmp = *((uint32_t *)(cfg + DATA_LOC4));
        fwrite(&tmp,4,1,ptr);
      }
      if (saveStreams & 0b10000) {
        tmp = *((uint32_t *)(cfg + DATA_LOC5));
        fwrite(&tmp,4,1,ptr);
      }
    }
  }
  
  //Disable FIFO
  *((uint32_t *)(cfg + FIFO_LOC)) = 0;
  if ((saveType == 1 | saveType == 2) & debugFlag) {
    stop = clock();
    printf("Execution time: %.3f ms\n",(double)(stop - start)/CLOCKS_PER_SEC*1e3);
    printf("Time per read: %.3f us\n",(double)(stop - start)/CLOCKS_PER_SEC/(double)(numSamples)*1e6);
  }

  if (saveType == 0) {
    for (i = 0;i<dataSize;i++) {
        printf("%08x\n",*(data + i));
    }
    free(data);
  } else if (saveType == 1) {
    ptr = fopen("SavedData.bin","wb");
    fwrite(data,4,(size_t)(dataSize),ptr);
    fclose(ptr);
    free(data);
  } else if (saveType == 2) {
    fclose(ptr);
  }

  //Unmap cfg from pointing to the previous location in memory
  munmap(cfg, MAP_SIZE);
  return 0;	//C functions should have a return value - 0 is the usual "no error" return value
}
