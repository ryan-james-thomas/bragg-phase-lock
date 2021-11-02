classdef DeviceParameter < handle
    %DEVICEPARAMETER Class defining a parameter in the device
    properties
        bits        %Bit range in the device
        upperLimit  %Upper limit on value
        lowerLimit  %Lower limit on value
        type        %Data type of the parameter
    end
    
    properties(SetAccess = protected)
        regs                %Array of registers associated with this parameter
        value               %Human-readable value in real units
        intValue            %Integer value written for FPGA
        toIntegerFunction   %Function converting real values to integer values
        fromIntegerFunction %Function converting integer values to real values
    end
    
    methods
        function self = DeviceParameter(bits,regIn,type)
            %DEVICEPARAMETER Constructs an instance of the class
            %
            %   SELF = DEVICEPARAMETER(BITS,REGIN) uses the bit range BITS
            %   and input registers REGIN to define the parameter.  When
            %   REGIN is only one register (of type DEVICEREGISTER) then
            %   BITS should be a two-element vector.  When REGIN is
            %   of size N, then BITS should be an Nx2 matrix
            %
            %   SELF = DEVICEPARAMETER(__,TYPE) sets the data type of the
            %   parameter.  Can be 'uint32', 'int32', or 'int16'
            %
            
            self.regs = regIn;
            self.bits = bits;
            
            if size(self.bits,1) ~= numel(self.regs)
                error('Number of registers must be the same as the number of bit ranges');
            end
            %
            % Default conversion functions just pass the value
            %
            self.toIntegerFunction = @(x) x;
            self.fromIntegerFunction = @(x) x;
            
            if nargin < 3
                self.type = 'uint32';
            elseif strcmp(type,'int32') || strcmp(type,'uint32') || strcmp(type,'int16')
                self.type = type;
            else
                error('Type must be either ''uint32'', ''int32'', or ''int16''!');
            end
            
            if numel(self.regs) > 1 && ~strcmpi(self.type,'uint32')
                error('When the number of registers is larger than 1, type must be ''uint32''!');
            end
        end
        
        function set.bits(self,bits)
            %SET.BITS Sets the bit ranges
            if mod(numel(bits),2) ~= 0 || any(bits(:) < 0) || any(bits(:) > 31) || size(bits,2) > 2
                error('Bits must be a 2-element vector with values in [0,31] or an Nx2 matrix with values in [0,31]');
            elseif numel(bits) == 2 && numel(self.regs) > 1 %#ok<MCSUP>
                error('If the number of associated registers is larger than 1 then bits must be an Nx2 matrix with values in [0,31]');
            else
                if numel(bits) == 2
                    self.bits = sort(bits(:)'); %#ok<TRSRT>
                else
                    self.bits = bits;
                end
            end  
        end
        
        function N = numbits(self)
            %NUMBITS Returns the number of bits associated with this
            %parameter
            N = sum(abs(diff(self.bits,1,2)),1) + 1;
        end
        
        function self = setFunctions(self,varargin)
            %SETFUNCTIONS Sets the toInteger and fromInteger functions for
            %converting physical values to integer values
            %
            %   SETFUNCTIONS(SELF,NAME,VALUE,...) sets the functions
            %   according to name/value pairs.  Allowed names are 'TO' or
            %   'FROM' corresponding to functions that convert to an
            %   integer value or from an integer value
            
            %Check register inputs
            if mod(numel(varargin),2) ~= 0
                error('You must specify functions as name/value pairs!');
            end
            
            for nn = 1:2:numel(varargin)
                if ~isa(varargin{nn+1},'function_handle')
                    error('Functions must be passed as function handles!');
                end
                s = lower(varargin{nn});
                switch s
                    case 'to'
                        self.toIntegerFunction = varargin{nn+1};
                    case 'from'
                        self.fromIntegerFunction = varargin{nn+1};
                end
            end
        end
        
        function self = setLimits(self,varargin)
            %SETLIMITS Sets the upper and lower limits on the physical
            %value
            %
            %   SETLIMITS(SELF,NAME,VALUE,...) sets the limits on this
            %   parameter according to name/value pairs.  Allowed names are
            %   'upper' and 'lower'.
            
            %Check register inputs
            if mod(numel(varargin),2)~=0
                error('You must specify functions as name/value pairs!');
            end
            
            for nn=1:2:numel(varargin)
                s = lower(varargin{nn});
                switch s
                    case 'lower'
                        self.lowerLimit = varargin{nn+1};
                    case 'upper'
                        self.upperLimit = varargin{nn+1};
                end
            end
        end
        
        function r = toInteger(self,varargin)
            %TOINTEGER Converts the arguments to an integer
            r = self.toIntegerFunction(varargin{:});
            try
                r = round(r);
            catch
                
            end
        end
        
        function r = fromInteger(self,varargin)
            %FROMINTEGER Converts the arguments from an integer
            r = self.fromIntegerFunction(varargin{:});
        end
        
        function self = checkLimits(self,v)
            %CHECKLIMITS Checks the limits on the set value
            if ~isempty(self.lowerLimit) && isnumeric(self.lowerLimit) && (v < self.lowerLimit)
                error('Value is lower than the lower limit!');
            end
            
            if ~isempty(self.upperLimit) && isnumeric(self.upperLimit) && (v > self.upperLimit)
                error('Value is higher than the upper limit!');
            end
            
        end
        
        function self = set(self,v,varargin)
            %SET Sets the physical value of the parameter and converts it
            %to an integer as well
            %
            %   SET(SELF,VALUE) Sets the parameter to the value given by
            %   VALUE.  Converts to the integer representation and sets the
            %   appropriate bits in the registers
            %
            
            %
            % Check limits first, then convert to integer and check that
            % the value will fit in the registers
            %
            if ~ischar(v) && ~isstring(v)
                self.checkLimits(v);
            end
            tmp = self.toInteger(v,varargin{:});
            if log2(double(tmp)) > self.numbits
                error('Value will not fit in bit range with %d bits',self.numbits);
            end
            %
            % Set the value and the integer value
            %
            self.value = v;
            self.intValue = tmp;
            %
            % Convert that integer value to the appropriate data type and
            % type cast it to a uint32 value
            %
            if islogical(self.intValue)
                self.intValue = uint32(self.intValue);
            elseif strcmpi(self.type,'int32')
                self.intValue = typecast(int32(self.intValue),'uint32');
            elseif strcmpi(self.type,'int16')
                self.intValue = uint32(typecast(int16(self.intValue),'uint16'));
            end
            %
            % Set the appropriate register values
            %
            if numel(self.regs) == 1
                self.regs.set(self.intValue,self.bits);
            else
                tmp = uint64(self.intValue);
                for nn=1:numel(self.regs)
                    self.regs(nn).set(tmp,self.bits(nn,:));
                    tmp = bitshift(tmp,-abs(diff(self.bits(nn,:)))-1);
                end
            end
        end
        
        function r = get(self,varargin)
            %GET Gets the physical value of the parameter from the integer
            %value
            %
            %   R = GET(SELF) Returns the physical value of the parameter
            %   associated with DEVICEPARAMETER SELF

            if numel(self.regs) == 1
                %
                % When there is only one register, read the data from the
                % register according to the parameter data type
                %
                self.intValue = self.regs.get(self.bits);
                if strcmpi(self.type,'int32')
                    v = typecast(self.intValue,'int32');
                elseif strcmpi(self.type,'uint32')
                    v = typecast(self.intValue,'uint32');
                elseif strcmpi(self.type,'int16')
                    v = typecast(uint16(self.intValue),'int16');
                end
            else
                %
                % When there is more than one register, read the data from
                % the registers in a loop
                %
                tmp = uint64(0);
                for nn=numel(self.regs):-1:2
                    tmp = tmp + bitshift(uint64(self.regs(nn).get(self.bits(nn,:))),abs(diff(self.bits(nn-1,:)))+1);
                end
                tmp = tmp + uint64(self.regs(1).get(self.bits(1,:)));
                self.intValue = tmp;
            end
            self.value = self.fromInteger(double(v),varargin{:});
            r = self.value;
        end
        
        function self = read(self)
            %READ Reads data from the device through the action of the
            %DEVICEREGISTER read() method
            
            if numel(self) == 1
                for nn=1:numel(self.regs)
                    self.regs(nn).read;
                end
                self.get;
            else
                for nn=1:numel(self)
                    self(nn).read;
                end
            end
        end
        
        function self = write(self)
            %WRITE writes the parameter to the device via the
            %DEVICEREGISTER write() method
            if numel(self) == 1
                for nn=1:numel(self.regs)
                    self.regs(nn).write;
                end
            else
                for nn=1:numel(self)
                    self(nn).write;
                end
            end
        end
        
        function s = print(self,name,width,formatstr,units)
            %PRINT Prints the parameter value and name
            %
            %   STR = PRINT(SELF,NAME,WIDTH,FORMATSTR,UNITS) returns a
            %   string STR with the name and value of the parameter that is
            %   WIDTH wide.  UNITS is optional.  If no return argument is
            %   desired then the result is printed to the command line
            if nargin < 5
                s = sprintf(['% ',num2str(width),'s: ',formatstr,'\n'],name,self.value);
            else
                s = sprintf(['% ',num2str(width),'s: ',formatstr,' %s\n'],name,self.value,units);
            end
            if nargout == 0
                fprintf(1,s);
            end
        end
        
        function disp(self)
            if numel(self) == 1
                fprintf(1,'\t DeviceParameter with properties:\n');
                if size(self.bits,1) == 1
                    fprintf(1,'\t\t            Bit range: [%d,%d]\n',self.bits(1),self.bits(2));
                else
                    for nn=1:size(self.bits,1)
                        fprintf(1,'\t\t  Bit range for reg %d: [%d,%d]\n',nn-1,self.bits(nn,1),self.bits(nn,2)); 
                    end
                end
                if isnumeric(self.value) && numel(self.value)==1
                    fprintf(1,'\t\t       Physical value: %.4g\n',self.value);
                elseif isnumeric(self.value) && numel(self.value)<=10
                    fprintf(1,'\t\t       Physical value: [%s]\n',strtrim(sprintf('%.4g ',self.value)));
                elseif isnumeric(self.value) && numel(self.value)>10
                    fprintf(1,'\t\t       Physical value: [%dx%d %s]\n',size(self.value),class(self.value));
                elseif ischar(self.value)
                    fprintf(1,'\t\t       Physical value: %s\n',self.value);
                end
                if numel(self.intValue)==1
                    fprintf(1,'\t\t        Integer value: %d\n',self.intValue);
                elseif numel(self.value)<=10
                    fprintf(1,'\t\t        Integer value: [%s]\n',strtrim(sprintf('%d ',self.intValue)));
                elseif numel(self.value)>10
                    fprintf(1,'\t\t        Integer value: [%dx%d %s]\n',size(self.value),class(self.value));
                end
                if ~isempty(self.lowerLimit) && isnumeric(self.lowerLimit)
                    fprintf(1,'\t\t          Lower limit: %.4g\n',self.lowerLimit);
                end
                if ~isempty(self.upperLimit) && isnumeric(self.upperLimit)
                    fprintf(1,'\t\t          Upper limit: %.4g\n',self.upperLimit);
                end

                if ~isempty(self.toIntegerFunction)
                    fprintf(1,'\t\t   toInteger Function: %s\n',func2str(self.toIntegerFunction));
                end
                if ~isempty(self.fromIntegerFunction)
                    fprintf(1,'\t\t fromInteger Function: %s\n',func2str(self.fromIntegerFunction));
                end
            else
                for nn=1:numel(self)
                    self(nn).disp();
                    fprintf(1,'\n');
                end
            end
        end
        
    end
    
end