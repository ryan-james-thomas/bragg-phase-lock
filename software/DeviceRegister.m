classdef DeviceRegister < handle
    %DEVICEREGISTER Defines a class representing registers inside the
    %device
    properties
        addr    %The address of the register as a uint32 integer
        value   %The value of the register as a uint32 integer
    end
    
    properties(Access = protected)
        conn    %A CONNECTIONCLIENT object to use for writing/reading data
    end
    
    properties(Constant)
        ADDR_OFFSET = uint32(hex2dec('40000000'));  %Offset of all addresses
        MAX_ADDR = uint32(hex2dec('3fffffff'));     %Maximum address relative to offset
    end
    
    methods
        function self = DeviceRegister(addr,conn)
            %DEVICEREGISTER Constructs an object
            %
            %   SELF = DEVICEREGISTER(ADDR,CONN) creates an object with
            %   associated address and connection object.  The value of the
            %   register is initialized to 0
            
            if nargin > 0
                self.addr = addr;
                self.value = uint32(0);
                if nargin > 1
                    self.conn = conn;
                end
            end
        end
    
        function set.addr(self,addr)
            %SET.ADDR Sets the address
            if ischar(addr)
                addr = hex2dec(addr);
            end

            if addr<0 || addr>self.MAX_ADDR
                error('Address is out of range [%08x,%08x]',0,self.MAX_ADDR);
            else
                self.addr = uint32(addr);
            end
        end
        
        function self = set(self,v,bits)
            %SET Sets the value of the register in a given bit range
            %
            %   SELF = SET(SELF,V,BITS) Changes the value of the register
            %   SELF in the bit range given by BITS to V.
            tmp = self.value;
            mask = intmax('uint32');
            mask = bitshift(bitshift(mask,bits(2)-bits(1)+1-32),bits(1));
            v = bitshift(uint32(v),bits(1));
            self.value = bitor(bitand(tmp,bitcmp(mask)),v);
        end
        
        function v = get(self,bits)
            %GET Returns the value of the register in a given bit range
            %
            %   V = GET(SELF,BITS) returns the value V of the register SELF
            %   for bit range BITS (a 2 element vector) 
            mask = intmax('uint32');
            mask = bitshift(bitshift(mask,bits(2)-bits(1)+1-32),bits(1));
            v = bitshift(bitand(self.value,mask),-bits(1));
        end
        
        function self = write(self)
            %WRITE Writes the value of the register to the device
            if numel(self) == 1
                data = [self.addr,self.value];
                self.conn.write(data,'mode','write');
            else
                for nn=1:numel(self)
                    self(nn).write;
                end
            end
        end
        
        function r = getWriteData(self)
            %GETWRITEDATA Returns the data to write
            %
            %   R = GETWRITEDATA(SELF) Returns the data to be written R for
            %   register SELF
            if numel(self) == 1
                r = [self.addr,self.value];
            else
                r = zeros(numel(self),2);
                for nn = 1:numel(self)
                    r(nn,:) = self(nn).getWriteData;
                end
            end
        end
        
        function r = getReadData(self)
            %GETREADDATA Returns the data sent to the server to initiate a
            %read operation
            %
            %   R = GETREADDATA(SELF) Returns the data as R for register
            %   SELF
            if numel(self) == 1
                r = self.addr;
            else
                r = zeros(numel(self),1);
                for nn = 1:numel(self)
                    r(nn,1) = self(nn).getReadData;
                end
            end
        end
        
        function self = read(self)
            %READ Reads the register value from the server/device
            %
            %   SELF = READ(SELF) reads the register value and stores it in
            %   the object SELF
            if numel(self) == 1
                self.conn.write(self.addr,'mode','read');
                self.value = self.conn.recvMessage;
            else
                for nn=1:numel(self)
                    self(nn).read;
                end
            end
        end
        
        function varargout = print(self,name,width)
            %PRINT Prints a string describing the register value and
            %
            %   PRINT(SELF,NAME,WIDTH) prints a string describing the
            %   register with NAME having a width WIDTH
            
            if numel(self) == 1
                s = sprintf(['% ',num2str(width),'s: %08x\n'],name,self.value);
            else
                for nn = 1:numel(self)
                    labelNew = sprintf('%s(%d)',name,nn-1);
                    s{nn} = self(nn).print(labelNew,width); %#ok<AGROW>
                end
            end
            
            if iscell(s)
                str = '';
                for nn = 1:numel(s)
                    str = [str,s{nn}]; %#ok<AGROW>
                end
            else
                str = s;
            end
            
            if nargout == 0
                fprintf(1,'%s',str);
            else
                varargout{1} = str;
            end
        end
    
    end
    
end