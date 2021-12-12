# from bitstring import BitArray
# import serial
import time
import types
import subprocess
import warnings
import struct

MEM_ADDR = 0x40000000

def write(data,header):
    #
    # Get memory address and create response
    #
    addr = MEM_ADDR + data[0]
    response = {"err":False,"errMsg":"","data":b''}
    #
    # Switch between different modes of operation
    #
    if header["mode"] == "write":
        # Write data to registers
        cmd = ['monitor',format(addr),'0x' + '{:0>8x}'.format(data[1])]
    elif header["mode"] == "read":
        # Read data from registers
        cmd = ['monitor',format(addr)]
    elif header["mode"] == "set output gain":
        # Set the output gain
        cmd = ['./setGain','-o','-p',format(header['port']),'-v',format(header['value'])]
    elif header["mode"] == "set input gain":
        # Set the input attenuation
        cmd = ['./setGain','-i','-p',format(header['port']),'-v',format(header['value'])]
    elif header["mode"] == "set coupling":
        # Set the input coupling
        cmd = ['./setGain','-c','-p',format(header['port']),'-v',format(header['value'])]
    elif header["mode"] == "fetch ram":
        # Fetch data from the block memories for debugging
        cmd = ['./fetchRAM',format(header["numSamples"])]
    elif header["mode"] == "acquire phase":
        # Acquire calculated phase data
        cmd = ['./saveData','-n',format(header["numSamples"]),'-t',format(header["saveType"]),format(header["saveStreams"]),format(header["startFlag"])]
    elif header["mode"] == "write data":
        # Write data to the timing controller
        fid = open("data-to-write.bin","wb")
        newData = []
        for i in range(1,len(data)):
            fid.write(struct.pack("<I",data[i]))
        fid.close()
        cmd = ['./writeFile',format(len(data) - 1)]

    #
    # Print debugging information and then run the command
    #
    if ("print" in header) and (header["print"]):
        print("Command: ",cmd)
    result = subprocess.run(cmd,stdout=subprocess.PIPE)
    #
    # Parse the result
    #
    if result.returncode == 0:
        #
        # When there is no error
        #
        if (("return_mode" in header) == False) or header["return_mode"] == "terminal":
            #
            # Read the data from the terminal as text and then convert it
            # into binary
            #
            data = result.stdout.decode('ascii').rstrip()
            if len(data) > 0:
                buf = struct.pack("<I",int(data,16))
            else:
                buf = b''
            response["data"] += buf

        elif header["return_mode"] == "file":
            #
            # Read data from the standard saved data file as binary
            #
            fid = open("SavedData.bin","rb")
            response["data"] = fid.read()
            fid.close()
    else:
        #
        # When there's an error, indicate to the client that an error occurred
        #
        response = {"err":True,"errMsg":"Bus error","data":[]}


    return response
        


    
        
