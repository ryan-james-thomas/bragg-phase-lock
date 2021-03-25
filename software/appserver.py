import sys
import socket
import selectors
import traceback
import subprocess

import libserver

sel = selectors.DefaultSelector()

def acceptWrapper(sock):
    conn, addr = sock.accept()
    print("Client (%s, %s) connected" % addr)
    conn.setblocking(False)
    message = libserver.Message(sel,conn,addr)
    sel.register(conn,selectors.EVENT_READ,data=message)

# host = "127.0.0.1"
r = subprocess.run(['./get_ip.sh'],stdout=subprocess.PIPE)
host = r.stdout.decode('ascii').rstrip()
port = 6666
lsock = socket.socket(socket.AF_INET,socket.SOCK_STREAM)
lsock.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR, 1)
lsock.bind((host,port))
lsock.listen()
print("Listening on", (host,port))
lsock.setblocking(False)
sel.register(lsock,selectors.EVENT_READ,data=None)

try:
    while True:
        events = sel.select(timeout=None)
        for key,mask in events:
            if key.data is None:
                acceptWrapper(key.fileobj)
            else:
                message = key.data
                try:
                    message.process_events(mask)
                except Exception:
                    # print("main: error: exception for",f"{message.addr}:\n{traceback.format_exc()}")
                    # print("Exception caught")
                    # print("Exception caught")
                    # print(message.addr)
                    # print(traceback.format_exc())
                    print("main: error: exception for {}:\n{}".format(message.addr,traceback.format_exc()))
                    message.close()

except KeyboardInterrupt:
    print("Caught keyboard interrupt, exiting")
finally:
    sel.close()
