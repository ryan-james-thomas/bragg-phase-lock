classdef PhaseLockClient < handle
    properties
        client
        host
    end
    
    properties(SetAccess = protected)
        headerLength
        header
        recvMessage
        recvDone
        bytesRead
    end
    
    properties(Constant)
        TCP_PORT = 6666;
%         HOST_ADDRESS = '127.0.0.1';
        HOST_ADDRESS = '172.22.250.94';
    end
    
    methods
        function self = PhaseLockClient(host)
            if nargin==1
                self.host = host;
            else
                self.host = self.HOST_ADDRESS;
            end
            self.initRead;
        end
        
        function open(self)
%             self.client = tcpclient(self.host,self.TCP_PORT,'Timeout',5,'ConnectTimeout',5);
            r = instrfindall('RemoteHost',self.host,'RemotePort',self.TCP_PORT);
            if isempty(r)
                self.client = tcpip(self.host,self.TCP_PORT,'byteOrder','littleEndian');
                self.client.InputBufferSize = 2^20;
                self.client.OutputBufferSize = 2^20;
                fopen(self.client);
            elseif strcmpi(r.Status,'closed')
                self.client = r;
                self.client.InputBufferSize = 2^20;
                self.client.OutputBufferSize = 2^20;
                fopen(self.client);
            else
                self.client = r;
            end
                
        end
        
        function close(self)
            if ~isempty(self.client) && isvalid(self.client) && strcmpi(self.client,'open')
                fclose(self.client);
            end
            delete(self.client);
            self.client = [];
        end
        
        function delete(self)
            try
                self.close;
            catch
                disp('Error deleting client');
            end
        end
        
        function initRead(self)
            self.headerLength = [];
            self.header = [];
            self.recvMessage = [];
            self.recvDone = false;
            self.bytesRead = 0;
        end
        
        function self = write(self,data,varargin)
            if mod(numel(varargin),2)~=0
                error('Variable arguments must be in name/value pairs');
            end
            if numel(data) == 0
                data = 0;
            end
            self.open;
            try
                msg.length = numel(data);

                for nn=1:2:numel(varargin)
                    msg.(varargin{nn}) = varargin{nn+1};
                end

                self.initRead;
                msg = jsonencode(msg);
                len = uint16(numel(msg));

                data = data(:)';
                msg_write = [typecast(len,'uint8'),uint8(msg),typecast(uint32(data),'uint8')];
                fwrite(self.client,msg_write,'uint8');
                
                jj = 1;
                while ~self.recvDone
                    self.read;
                    pause(10e-3);
                    if jj>2e3
                        error('Timeout reading data');
                    else
                        jj = jj+1;
                    end
                end
                self.close
            catch e
                self.close;
                rethrow(e);
            end
        end
        
        function read(self)
            if isempty(self.headerLength)
                self.processProtoHeader();
            end
            
            if isempty(self.header)
                self.processHeader();
            end
            
            if isfield(self.header,'length') && ~self.recvDone
                self.processMessage();
            end
        end
    end
    
    methods(Access = protected)       
        function processProtoHeader(self)
            if self.client.BytesAvailable>=2 && self.client.BytesAvailable > 0
                self.headerLength = fread(self.client,1,'uint16');
            end
        end
        
        function processHeader(self)
            if ~isempty(self.headerLength) && self.client.BytesAvailable>=self.headerLength && self.client.BytesAvailable > 0
                tmp = fread(self.client,self.headerLength,'uint8');
                self.header = jsondecode(char(tmp)');
                if ~isfield(self.header,'length')
                    self.recvDone = true;
                end
            end
        end
        
        function processMessage(self)
            if self.bytesRead < self.header.length && self.client.BytesAvailable > 0
                bytesToRead = self.client.BytesAvailable;
%                 fprintf(1,'Bytes to read: %d\n',bytesToRead);
                tmp = uint8(fread(self.client,bytesToRead,'uint8'));
%                 fprintf(1,'Bytes read: %d\n',numel(tmp));
                self.recvMessage = [self.recvMessage;tmp];
                self.bytesRead = numel(self.recvMessage);
%                 fprintf(1,'Total bytes read: %d\n',self.bytesRead);
            end
            
            if self.bytesRead >= self.header.length
                self.recvDone = true;
                self.recvMessage = typecast(self.recvMessage,'uint32');
            end
        end
    end
   
    
end