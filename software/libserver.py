import sys
import selectors
import json
import io
import struct

import appcontroller


class Message:
    def __init__(self,selector,sock,addr):
        self.selector = selector
        self.sock = sock
        self.addr = addr
        self._recv_buffer = b""
        self._send_buffer = b""
        self.read_serial = None
        self.header_len = None
        self.header = None
        self.msg_len = None
        self.msg = None
        self.fpga_response = None
        self.response = None
        self.response_created = False

    def _set_selector_events_mask(self,mode):
        #Sets the selector's event mask to r, w, or rw/wr
        if mode == "r":
            events = selectors.EVENT_READ
        elif mode == "w":
            events = selectors.EVENT_WRITE
        elif mode == "rw" or mode == "wr":
            events = selectors.EVENT_WRITE | selectors.EVENT_READ
        else:
            # raise ValueError(f"Invalid events mask mode {repr(mode)}.")
            raise ValueError("Invalid events mask mode {}".format(repr(mode)))
        self.selector.modify(self.sock,events,data=self)

    def _read(self):
        #Internal read function, reads up to 4096 bytes from socket
        try:
            #Socket should be ready to read
            data = self.sock.recv(4096)
        except BlockingIOError:
            #Resource temporarily unavailable
            pass
        else:
            if data:
                #If valid data is received, add it to recv buffer
                self._recv_buffer += data
            else:
                #If false, then the client has disconnected
                raise RuntimeError("Peer closed.")

    def _write(self):
        #Internal write function
        if self._send_buffer:
            #If there is valid data in the send buffer
            try:
                #Should be ready to write
                sent = self.sock.send(self._send_buffer)    #sent is the number of bytes sent
            except BlockingIOError:
                #Resource temporarily unavailable
                pass
            else:
                self._send_buffer = self._send_buffer[sent:]    #Retains only data from index sent to end of array of bytes
                print("Bytes sent: %d, Bytes Remaining: %d" % (sent, len(self._send_buffer)))
                #Close when the buffer is empty - binary data is true if not empty
                if sent and not self._send_buffer:
                    self.close()

    def read(self):
        #This function is called repeatedly by socket event loop. Processes header and message data
        self._read()

        #First step is to process header length
        if self.header_len is None:
            self.process_proto_header()

        #Second step is to process the header
        if self.msg_len is None:
            self.process_header()

        #Last step is to process the message
        if self.msg is None:
            self.process_request()

    def write(self):
        #This function is called repeatedly until a response is ready to be sent
        #If message has been received
        if self.msg:
            #If the response hasn't been created (None is converted into boolean False)
            if not self.response_created:
                self.create_response()
        self._write()

    def close(self):
        #Closes the socket connection
        print("Closing connection (%s, %s)" % self.addr)
        try:
            self.selector.unregister(self.sock)
        except Exception as e:
            # print(f"Error: selector.unregister() exception for",f"{self.addr}: {repr(e)}")
            print("Errpr: selector.unregister() exception for {}: {}".format(self.addr,repr(e)))
        finally:
            #Delete reference to socket object for garbage collection
            self.sock = None

    def process_proto_header(self):
        #This function retrieves the header from the message
        proto_len = 2
        if len(self._recv_buffer) >= proto_len:
            self.header_len = struct.unpack("<H",self._recv_buffer[:proto_len])[0]
            self._recv_buffer = self._recv_buffer[proto_len:]


    def process_header(self):
        #This function processes the header
        if len(self._recv_buffer) >= self.header_len:
            # print("Header is",self._recv_buffer[:hdr_len])
            # hdr = int.from_bytes(struct.unpack("<c",self._recv_buffer[:1])[0],'little')
            self.header = json.loads(self._recv_buffer[:self.header_len].decode('ascii'))
            self.msg_len = 4*self.header["length"]

            print("Header:")
            print(self.header)
            self._recv_buffer = self._recv_buffer[self.header_len:]

    def process_request(self):
        #Processes the message
        if len(self._recv_buffer) >= self.msg_len:
            self.msg = self._recv_buffer[:self.msg_len]
            pmsg = []
            for d in struct.iter_unpack("<I",self._recv_buffer[:self.msg_len]):
                pmsg.append(d[0])
            if ("print" in self.header) and (self.header["print"]):
                print("Message:",self.msg)
                print("\n".join("%08x"%item for item in pmsg))
            
            self._recv_buffer = self._recv_buffer[self.msg_len:]
            
            #Write data using io-controller
            self.fpga_response = appcontroller.write(pmsg,self.header)
            print("Message written to server")
            #At end of reading of data, set class to write mode
            self._set_selector_events_mask("w")

    
    def create_response(self):
        self.fpga_response["length"] = 4*len(self.fpga_response["data"])
        data = self.fpga_response.pop("data");#self.fpga_response["data"]
        # del(self.fpga_response["data"])
        json_str = json.dumps(self.fpga_response)
        print(json_str)
        tmp = json_str.encode('ascii')
        self._send_buffer = struct.pack("<H",len(tmp)) + tmp
        for d in data:
            # print(format(int(d,16)))
            self._send_buffer += struct.pack("<I",int(d,16))
        self.response_created = True
        

            
    def process_events(self,mask):
        if mask & selectors.EVENT_READ:
            self.read()
        if mask & selectors.EVENT_WRITE:
            self.write()
