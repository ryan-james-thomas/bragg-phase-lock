# from bitstring import BitArray
# import serial
import time
import types
import subprocess
import warnings

MEM_ADDR = 0x40000000

def write(data,header):
    if len(data) > 0 and len(data) <= 2:
        addr = MEM_ADDR + data[0]
        if header["mode"] == "write":
            cmd = ['monitor',format(addr),'0x' + '{:0>8x}'.format(data[1])]
        elif header["mode"] == "read":
            cmd = ['monitor',format(addr)]
        elif header["mode"] == "fetch data":
            cmd = ['./fetchData',format(header["numFetch"]),format(header["fetchType"])]
        elif header["mode"] == "acquire phase":
            cmd = ['./saveData',format(header["numSamples"]),format(header["saveType"]),format(header["saveStreams"]),format(header["startFlag"])]

        if ("print" in header) and (header["print"]):
            print("Command: ",cmd)
        result = subprocess.run(cmd,stdout=subprocess.PIPE)
        
    elif len(data) > 2:
        addr = MEM_ADDR + data[0]
        for i in range(1,len(data)):
            cmd = ['monitor',format(addr),'0x' + '{:0>8x}'.format(data[i])]
            if ("print" in header) and (header["print"]):
                print("Command: ",cmd)
            result = subprocess.run(cmd,stdout=subprocess.PIPE)
            if result.returncode != 0:
                break
    
    
    if result.returncode != 0:
        response = {"err":True,"errMsg":"Bus error","data":[]}
    else:
        response = {"err":False,"errMsg":""}
        if len(result.stdout) > 0:
            response["data"] = result.stdout.decode('ascii').rstrip().split("\n")
        else:
            response["data"] = []

    return response
        


    
        
