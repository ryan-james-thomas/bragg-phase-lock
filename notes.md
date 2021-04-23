# Notes

The storage mechanism for the timing controller should act a lot more like a FIFO buffer than a random-access memory since we access the memory in sequential order. The buffer should support first-word fall-through, so that the first thing written to the buffer is available immediately when a start trigger is seen.

Data should be stored in three-word chunks.  So a *single* instruction should consist of three separate data words:
  1. The duration of the instruction.
  2. The frequency tuning word for the frequency difference.
  3. The phase control word
Since the tuning and phase words are 27 bits in the design for the DDS blocks, all words can be 27 bits (or 28, as it's the next byte boundary).  A 27 bit duration corresponds to a maximum *single* delay of 1.07 s, and for atom interferometers this is probably sufficient.  Honestly, though, we can probably go to 32 bits and it won't make a big difference on the resource use.

The one problem with FIFO buffers is that we basically can't go back to the first word without writing to the buffer again.  This is annoying, as the memory is not persistent and the data has to be uploaded every time, but it's also not insurmountable.  The data can be stored in memory on the CPU side of the Zynq chip, and the run() command in the gravimeter interface can also send an upload command to the Red Pitaya when the sequence starts.

Having a FIFO avoids having to preload data.  Instead, what we want to have is a module that handles getting data in, but mostly out, of the buffer.  When this module sees a read trigger, it should read the next three instructions in memory...actually, this still has the problem of preloading data since only the first word of the FIFO will be present.  We can get around this by either having one FIFO with an extended data width or three FIFOs each with the same number of instructions.  

Nevertheless, the current values of the duration, FTW, and POW should always be present on the outputs of the module.  On receipt of a read trigger it will load the next three instructions.  When the timing controller issues that read instruction it should immediately store the current words and then use them as instructions.  So this involves presenting the current FTW and POW on the outputs of the TimingController module, and then going into a waiting state for the duration of the instruction.  The timing controller process terminates when the FIFO indicates that it is empty and the last instruction finishes.