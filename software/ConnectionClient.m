classdef ConnectionClient < handle
    %CONNECTIONCLIENT Class for handling client connections with a remote
    %server.
    properties
        client              %This is the MATLAB object representing the client connection
        host                %This is the hostname/IP address of the server
        port                %This is the TCP/IP port of the server
        keepAlive           %Tells the class to keep the connection alive (true/false)
        timeout             %Timeout for receiving data in seconds
    end
    
    properties(SetAccess = protected)
        headerLength        %Length of header in bytes
        header              %Header information
        recvMessage         %Received message
        recvDone            %Flag to indicate when a message has been completely received
        bytesRead           %Number of bytes that have been read
    end
    
    properties(Constant)
        TCP_PORT = 6666;                %Default TCP/IP Port
        HOST_ADDRESS = '192.168.1.103'; %Default TCP/IP address
    end
    
    methods
        function self = ConnectionClient(host,port,keepAlive)
            %CONNECTIONCLIENT Constructs a class of the same name.
            %
            %   SELF = CONNECTIONCLIENT() uses default HOST and PORT and
            %   sets KEEPALIVE to FALSE
            %
            %   SELF = CONNECTIONCLIENT(HOST) uses the provided HOST
            %
            %   SELF = CONNECTIONCLIENT(__,PORT) uses the provided PORT
            %   number
            %
            %   SELF = CONNECTIONCLIENT(__,KEEPALIVE) sets the internal
            %   KEEPALIVE parameter
            if nargin < 1
                self.host = self.HOST_ADDRESS;
            else
                self.host = host;
            end
            
            if nargin < 2
                self.port = self.TCP_PORT;
            else
                self.port = port;
            end
            
            if nargin < 3
                self.keepAlive = false;
            else
                self.keepAlive = keepAlive;
            end

            self.initRead;
            self.timeout = 20;
        end
        
        function open(self)
            %OPEN Opens a TCP/IP connection to the remote server
            %
            %   OPEN(SELF) opens the connection associated with current
            %   CONNECTIONCLIENT object SELF
            
            %
            % Look for existing connections
            %
            r = instrfindall('RemoteHost',self.host,'RemotePort',self.port);
            if isempty(r)
                %
                % If no connections exist, create that connection
                %
                self.client = tcpip(self.host,self.port,'byteOrder','littleEndian');
                self.client.InputBufferSize = 2^20;
                fopen(self.client);
            elseif strcmpi(r.Status,'closed')
                %
                % If a connection exists but it is closed, set the buffer
                % size correctly and then open it
                %
                self.client = r;
                self.client.InputBufferSize = 2^20;
                fopen(self.client);
            else
                %
                % Otherwise set the client parameter to that connection
                %
                self.client = r;
            end
                
        end
        
        function close(self)
            % CLOSE Closes the client connection
            %
            %   CLOSE(SELF) closes the client connection for current
            %   CONNECTIONCLIENT object SELF
            if ~isempty(self.client) && isvalid(self.client) && strcmpi(self.client,'open')
                fclose(self.client);
            end
            delete(self.client);
            self.client = [];
        end
        
        function delete(self)
            %DELETE Deletes the current object. Closes the connection first
            try
                self.close;
            catch
                disp('Error deleting client');
            end
        end
        
        function initRead(self)
            %INITREAD initializes the read properties to empty/default
            %states
            self.headerLength = [];
            self.header = [];
            self.recvMessage = [];
            self.recvDone = false;
            self.bytesRead = 0;
        end
        
        function self = write(self,data,varargin)
            %WRITE Writes data and headers to the remote server
            %
            %   WRITE(SELF,DATA) writes the DATA using CONNECTIONCLIENT
            %   object SELF.  Data is an array of UINT32 values
            %
            %   WRITE(__,'NAME','VALUE',...) additionally writes header
            %   values corresponding to name/value pairs.  Any number of
            %   name/value pairs can be written
            %
            %   The message format is a 2-byte proto-header which indicates
            %   how long the header information is.  This is followed by
            %   the header data.  The header has to contain a 'length'
            %   parameter which tells the server how long the data payload
            %   is.  The data payload follows the header
            
            %
            % Check input headers
            %
            if mod(numel(varargin),2) ~= 0
                error('Variable arguments must be in name/value pairs');
            end
            %
            % Some data always needs to be written
            %
            if numel(data) == 0
                data = 0;
            end
            %
            % Make sure the connection is open
            %
            if ~self.keepAlive || isempty(self.client)
                self.open;
            end
            %
            % Use a try/catch statement to make sure the connection always
            % gets closed nicely
            %
            try
                %
                % This is the header information.  It must contain a
                % parameter indicating the length of the data payload
                %
                msghdr.length = numel(data);
                %
                % Loop through header names and values
                %
                for nn=1:2:numel(varargin)
                    msghdr.(varargin{nn}) = varargin{nn+1};
                end
                %
                % Tell the server to keep the connection alive
                %
                msghdr.keep_alive = self.keepAlive;
                %
                % Initialize the read variables
                self.initRead;
                %
                % Encode the message header as a JSON-formatted string.
                % 'len' is now the length of the header as a uint16 number
                %
                msghdr = jsonencode(msghdr);
                len = uint16(numel(msghdr));
                %
                % Write the message to the server.  Message is (header
                % length), (header), (data).
                data = data(:)';
                msg_write = [typecast(len,'uint8'),uint8(msghdr),typecast(uint32(data),'uint8')];
                fwrite(self.client,msg_write,'uint8');
                %
                % Wait for new data.  The wait is done this way because the
                % normal timeout doesn't really work that well.  
                %
                jj = 1;
                while ~self.recvDone
                    self.read;
                    pause(10e-3);
                    if jj > floor(self.timeout/10e-3)
                        error('Timeout reading data');
                    else
                        jj = jj+1;
                    end
                end
                %
                % Close the connection if it's not supposed to be kept
                % alive
                %
                if ~self.keepAlive
                    self.close;
                end
            catch e
                %
                % If there is an error, close the connection and then
                % rethrow the error
                %
                self.close;
                rethrow(e);
            end
        end
        
        function read(self)
            %READ Reads data from the server.  Message is assumed to arrive
            %in the same format as the WRITE method writes to the server
            
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
            %PROCESSPROTOHEADER Reads data corresponding to the
            %proto-header (which indicates the length of the proper header)
            %when enough bytes are available.
            if self.client.BytesAvailable >= 2 && self.client.BytesAvailable > 0
                self.headerLength = fread(self.client,1,'uint16');
            end
        end
        
        function processHeader(self)
            %PROCESSHEADER Reads the header data from the message
            if ~isempty(self.headerLength) && self.client.BytesAvailable >= self.headerLength && self.client.BytesAvailable > 0
                tmp = fread(self.client,self.headerLength,'uint8');
                self.header = jsondecode(char(tmp)');
                if ~isfield(self.header,'length')
                    %
                    % If there is no "length" parameter, there is no data
                    % payload and reception is done
                    %
                    self.recvDone = true;
                end
            end
        end
        
        function processMessage(self)
            %PROCESSMESSAGE Reads the data payload from the message
            if self.bytesRead < self.header.length && self.client.BytesAvailable > 0
                bytesToRead = self.client.BytesAvailable;
                tmp = uint8(fread(self.client,bytesToRead,'uint8'));
                self.recvMessage = [self.recvMessage;tmp];
                self.bytesRead = numel(self.recvMessage);
            end
            
            if self.bytesRead >= self.header.length
                self.recvDone = true;
                self.recvMessage = typecast(self.recvMessage,'uint32');
            end
        end
    end
   
    
end