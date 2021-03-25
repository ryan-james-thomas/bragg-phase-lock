//These are libraries which contain useful functions
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

#define MAP_SIZE 262144UL
#define MEM_LOC 0x40000000
#define DATA_LOC 0x00000020
#define FIFO_LOC 0x0000001C
 
int main(int argc, char **argv)
{
  int fd;		//File identifier
  int numSamples;	//Number of samples to collect
  void *cfg;		//A pointer to a memory location.  The * indicates that it is a pointer - it points to a location in memory
  char *name = "/dev/mem";	//Name of the memory resource

  uint32_t i = 0;
  uint8_t saveType = 0;

  clock_t start, stop;


/*The following if-else statement parses the input arguments.
argc is the number of arguments.  argv is a 2D array of characters.
argv[0] is the function name, and argv[n] is the n'th input argument*/
  if (argc == 2) {
    numSamples = atoi(argv[1]);	//atof converts the character array argv[1] to a floating point number
    saveType = 0;
  } else if (argc == 3) {
    numSamples = atoi(argv[1]);	//atof converts the character array argv[1] to a floating point number
    saveType = atoi(argv[2]);;
  } else  {
    printf("You must supply at least one argument!\n");
    return 0;
  }

  uint32_t *data = malloc(numSamples * sizeof(uint32_t));
  if (!data) {
    printf("Error allocating memory");
    return -1;
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
//  printf("FIFO Enabled!\n");
  //Record data
  if (saveType == 1) {
    start = clock();
  }
 
  for (i = 0;i<numSamples;i++) {
//    tmp = *((uint32_t *)(cfg2));
    *(data + i) = *((uint32_t *)(cfg + DATA_LOC));
//    *(data + i) = i;
    // data[i] = *((uint32_t *)(cfg + (i << 2)));
//     printf("%08x\n",*(data + i));
  }
  //Disable FIFO
//  *((uint32_t *)(cfg + FIFO_LOC)) = 0;
  if (saveType == 1) {
    stop = clock();
    printf("FIFO Disabled!\n");
    printf("Execution time: %.3f ms\n",(double)(stop - start)/CLOCKS_PER_SEC*1e3);
    printf("Time per read: %.3f us\n",(double)(stop - start)/CLOCKS_PER_SEC/(double)(numSamples)*1e6);
  }
  
  if (saveType == 0) {
    for (i = 0;i<numSamples;i++) {
        printf("%08x\n",*(data + i));
    }
  } else if (saveType == 1) {
    FILE *ptr;
    ptr = fopen("SavedData.bin","wb");
    fwrite(data,4,(size_t)numSamples,ptr);
    fclose(ptr);
  }

  //Unmap cfg from pointing to the previous location in memory
  free(data);
  munmap(cfg, MAP_SIZE);
  return 0;	//C functions should have a return value - 0 is the usual "no error" return value
}