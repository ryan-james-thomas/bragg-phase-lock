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
#define WRITE_LOC 0x00000034
 
int main(int argc, char **argv)
{
  int fd;		//File identifier
  int numSamples;	//Number of samples to collect
  void *cfg;		//A pointer to a memory location.  The * indicates that it is a pointer - it points to a location in memory
  char *name = "/dev/mem";	//Name of the memory resource
  char *filename = "data-to-write.bin";

  uint32_t i;
  uint32_t tmp;
  FILE *ptr;

  clock_t start, stop;


/*The following if-else statement parses the input arguments.
argc is the number of arguments.  argv is a 2D array of characters.
argv[0] is the function name, and argv[n] is the n'th input argument*/
  if (argc == 2) {
    numSamples = atoi(argv[1]);
  } else {
    printf("Need to supply the number of data points to write!\n");
    return 0;
  }
  

  //This returns a file identifier corresponding to the memory, and allows for reading and writing.  O_RDWR is just a constant
  if((fd = open(name, O_RDWR)) < 0) {
    perror("open");
    return 1;
  }

  //This returns a file identifier corresponding to the file with data
  FILE* fdata = fopen(filename,"rb");
  if (!fdata) {
      perror("Cannot open data file!");
      return 1;
  }

  /*mmap maps the memory location 0x40000000 to the pointer cfg, which "points" to that location in memory.*/
//  cfg = mmap(0,MAP_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,MEM_LOC);
  cfg = mmap(0,MAP_SIZE,PROT_READ|PROT_WRITE,MAP_SHARED,fd,MEM_LOC);

  for (i = 0;i < numSamples;i++) {
      fread(&tmp,sizeof(uint32_t),1,fdata);
      *((uint32_t *)(cfg + WRITE_LOC)) = tmp;
  }
  fclose(fdata);

  //Unmap cfg from pointing to the previous location in memory
  munmap(cfg, MAP_SIZE);
  return 0;	//C functions should have a return value - 0 is the usual "no error" return value
}
