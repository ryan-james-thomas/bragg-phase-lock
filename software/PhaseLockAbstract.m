classdef (Abstract) PhaseLockAbstract < handle
    %PhaseLockAbstract is an abstract class for interfacing with the phase
    %lock design on either the STEMlab or SIGNALlab boards.
    %
    % Parameters that can be controlled on the FPGA are represented by the
    % DeviceParameter class, and registers are represented by the
    % DeviceRegister class.  
    properties
        t           %Time data
        data        %Data retrieved from the FPGA
    end
    
    properties(SetAccess = immutable)
        conn        %ConnectionClient object for communicating with device

        %% Top-level properties        
        shift       %Shift left by this
        useSetDemod %True to use a fixed demodulation frequency, false to use shifted value
        useManual   %True to use manual values, false to use timing controller values
        useTCDemod  %True to use the TC df output as the OUT1 frequency and demod freq, for testing
        disableExtTrig %Set to true to disable the external trigger
        %% Frequency parameters
        f0          %Center frequency
        df          %Difference frequency
        demod       %Demodulation frequency
        amp         %Amplitude
        %% Phase calculation parameters
        cicRate     %Log2(CIC rate reduction)
        cicShift    %Number of bits to shift right by after filtering
        %% Phase control parameters
        phasec      %Manual control phase
        enableFB    %Enable feedback
        polarity    %Feedback polarity
        Kp          %Proportional gain
        Ki          %Integral gain
        Kd          %Derivative gain
        divisor     %Overall divisor

    end
    
    properties(SetAccess = protected)
        %% R/W registers
        trigReg             %Trigger register
        topReg              %Top-level register
        freqOffsetReg       %Register for common DDS frequency
        freqDiffReg         %Register for difference between DDS frequencies
        freqDemodReg        %Fixed demodulation frequency
        phaseControlSigReg  %Register for the phase control signal
        phaseCalcReg        %Register for calculating phase from ADC data
        phaseControlReg     %Register for PI control settings
        phaseGainReg        %Register for PI gain settings
        numSamplesReg       %Register for number of samples
        lastSampleReg       %Register for the last sample
        adcReg
        %% Read-only register
        auxReg              %Auxiliary register for debugging signals
        %% Write-only register
        timingReg           %Register for writing timing contro
    end
    
    properties(Constant)
%         CLK = 250e6;                    %Clock frequency of the board
        HOST_ADDRESS = '192.168.1.109'; %Default socket server address
        DDS_WIDTH = 27;                 %Bit width of the DDS phase inputs
        CORDIC_WIDTH = 24;              %Bit width of the measured phase
        AMP_WIDTH = 12;                 %Bit width of amplitude scaling
        DAC_WIDTH = 14;                 %Bit width of DAC
        ADC_WIDTH = 14;                 %Bit width of ADC
    end
    
    properties(Constant,Abstract)
        CLK                             %Clock frequency of the board
    end
    
    methods
        function self = PhaseLockAbstract(varargin)
            %PhaseLockAbstract Constructor for this abstract class.
            %
            % SELF = PhaseLockAbstract(HOST_ADDRESS) constructs a
            % PhaseLockAbstract object using the given HOST_ADDRESS for
            % connecting to the remote server.  HOST_ADDRESS can be
            % neglected, in which case the default HOST_ADDRESS is used
            if numel(varargin) == 1
                self.conn = ConnectionClient(varargin{1});
            else
                self.conn = ConnectionClient(self.HOST_ADDRESS);
            end

            % R/W registers
            self.trigReg = DeviceRegister('0',self.conn);
            self.topReg = DeviceRegister('4',self.conn);
            %
            % Freq generation registers
            %
            self.freqOffsetReg = DeviceRegister('8',self.conn);
            self.freqDiffReg = DeviceRegister('C',self.conn);
            self.freqDemodReg = DeviceRegister('10',self.conn);
            %
            % Phase control/calculation registers
            %
            self.phaseControlSigReg = DeviceRegister('14',self.conn);
            self.phaseCalcReg = DeviceRegister('18',self.conn);
            self.phaseControlReg = DeviceRegister('1C',self.conn);
            self.phaseGainReg = DeviceRegister('20',self.conn);
            %
            % Read-only registers
            %
            self.auxReg = DeviceRegister('01000000',self.conn);
            %
            % Write-only registers
            %
            self.timingReg = DeviceRegister('00000034',self.conn);
            %
            % Top-level parameters
            %
            self.shift = DeviceParameter([0,3],self.topReg)...
                .setLimits('lower',0,'upper',15)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.useSetDemod = DeviceParameter([4,4],self.topReg)...
                .setLimits('lower',0,'upper',1);
            self.useManual = DeviceParameter([5,5],self.topReg)...
                .setLimits('lower',0,'upper',1);
            self.useTCDemod = DeviceParameter([6,6],self.topReg)...
                .setLimits('lower',0,'upper',1);
            self.disableExtTrig = DeviceParameter([7,7],self.topReg)...
                .setLimits('lower',0,'upper',1);            
            %
            % Frequency generation
            %
            self.f0 = DeviceParameter([0,26],self.freqOffsetReg)...
                .setLimits('lower',0,'upper',50)...
                .setFunctions('to',@(x) x*1e6/self.CLK*2^self.DDS_WIDTH,'from',@(x) x/2^self.DDS_WIDTH*self.CLK/1e6);
            self.df = DeviceParameter([0,26],self.freqDiffReg)...
                .setLimits('lower',0,'upper',50)...
                .setFunctions('to',@(x) x*1e6/self.CLK*2^self.DDS_WIDTH,'from',@(x) x/2^self.DDS_WIDTH*self.CLK/1e6);
            self.demod = DeviceParameter([0,26],self.freqDemodReg)...
                .setLimits('lower',0,'upper',2^27)...
                .setFunctions('to',@(x) x*1e6/self.CLK*2^self.DDS_WIDTH,'from',@(x) x/2^self.DDS_WIDTH*self.CLK/1e6);
            self.amp = DeviceParameter([8,19],self.topReg)...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x*(2^self.AMP_WIDTH - 1),'from',@(x) x/(2^self.AMP_WIDTH - 1));
            self.amp(2) = DeviceParameter([20,31],self.topReg)...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x*(2^self.AMP_WIDTH - 1),'from',@(x) x/(2^self.AMP_WIDTH - 1));
            %
            % Phase calculation
            %
            self.cicRate = DeviceParameter([0,7],self.phaseCalcReg)...
                .setLimits('lower',7,'upper',11)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.cicShift = DeviceParameter([8,15],self.phaseCalcReg)...
                .setLimits('lower',0,'upper',255);
            %
            % Phase control signal
            %
            self.phasec = DeviceParameter([0,31],self.phaseControlSigReg)...
                .setLimits('lower',-pi,'upper',pi)...
                .setFunctions('to',@(x) typecast(int32(x/pi*2^(self.CORDIC_WIDTH-3)),'uint32'),'from',@(x) x/2^(self.CORDIC_WIDTH-3)*pi);
            %
            % Phase control parameters
            %
            self.polarity = DeviceParameter([0,0],self.phaseControlReg)...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.enableFB = DeviceParameter([1,1],self.phaseControlReg)...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            %
            % Phase controller gains
            %
            self.Kp = DeviceParameter([0,7],self.phaseGainReg)...
                .setLimits('lower',0,'upper',255)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.Ki = DeviceParameter([8,15],self.phaseGainReg)...
                .setLimits('lower',0,'upper',255)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.Kd = DeviceParameter([16,23],self.phaseGainReg)...
                .setLimits('lower',0,'upper',255)...
                .setFunctions('to',@(x) x,'from',@(x) x);
            self.divisor = DeviceParameter([24,31],self.phaseGainReg)...
                .setLimits('lower',0,'upper',255)...
                .setFunctions('to',@(x) x,'from',@(x) x);
        end
        
        function self = setDefaults(self)
            %SETDEFAULTS Sets the default values
            
            %
            % Top-level parameters
            %
            self.shift.set(3);
            self.useSetDemod.set(0);
            self.useManual.set(1);
            self.useTCDemod.set(0);
            self.disableExtTrig.set(0);
            %
            % Frequency parameters
            %
            self.f0.set(40);
            self.df.set(0.125);
            self.demod.set(1);
            self.amp(1).set(0);
            self.amp(2).set(0);
            %
            % Phase calculation
            %
            self.cicRate.set(10);
            self.cicShift.set(30);
            %
            % Phase control
            %
            self.phasec.set(0);
            self.enableFB.set(0);
            self.polarity.set(1);
            self.Kp.set(50);
            self.Ki.set(140);
            self.Kd.set(0);
            self.divisor.set(11);            
        end
        
        function self = check(self)

        end
        
        function self = upload(self)
            %UPLOAD Uploads all registers and sends an update CIC rate flag
            %to the device at the end
            self.check;
            self.topReg.write;
            self.freqOffsetReg.write;
            self.freqDiffReg.write;
            self.freqDemodReg.write;
            self.phaseControlSigReg.write;
            self.phaseCalcReg.write;
            self.phaseControlReg.write;
            self.phaseGainReg.write;
            self.updateCIC;
        end
        
        function self = fetch(self)
            %FETCH Retrieves all current register values and parses them
            %for parameters
            
            %Read registers
            self.topReg.read;
            self.freqOffsetReg.read;
            self.freqDiffReg.read;
            self.freqDemodReg.read;
            self.phaseControlSigReg.read;
            self.phaseCalcReg.read;
            self.phaseControlReg.read;
            self.phaseGainReg.read;
            %Read parameters
            self.shift.get;
            self.useSetDemod.get;
            self.useManual.get;
            self.useTCDemod.get;
            self.disableExtTrig.get;
            self.f0.get;
            self.df.get;
            self.demod.get;
            self.amp.get;
            self.cicRate.get;
            self.cicShift.get;
            self.phasec.get;
            
            self.enableFB.get;
            self.polarity.get;
            self.Kp.get;
            self.Ki.get;
            self.Kd.get;
            self.divisor.get;
        end
        
        function data = readOnly(self)
            %READONLY Reads the read-only registers and returns a data
            %structure with their values
            %
            %   DATA = SELF.READONLY() Returns data structure DATA with
            %   read-only parameters
            %df
            self.auxReg.addr = '01000000';
            self.auxReg.read;
            data.df = double(self.auxReg.value)/2^self.DDS_WIDTH*125;
            %dfmod_i
            self.auxReg.addr = '01000004';
            self.auxReg.read;
            data.dfmod_i = double(self.auxReg.value)/2^self.DDS_WIDTH*125;
            %tc_df
            self.auxReg.addr = '01000008';
            self.auxReg.read;
            data.tc_df = double(self.auxReg.value)/2^self.DDS_WIDTH*125;
            %tc_amp(1)
            self.auxReg.addr = '0100000C';
            self.auxReg.read;
            data.tc_amp(1) = double(self.auxReg.value)/(2^self.AMP_WIDTH - 1);
            %tc_amp(2)
            self.auxReg.addr = '01000010';
            self.auxReg.read;
            data.tc_amp(2) = double(self.auxReg.value)/(2^self.AMP_WIDTH - 1);
            %tc_pow
            self.auxReg.addr = '01000014';
            self.auxReg.read;
            data.tc_pow = double(typecast(self.auxReg.value,'int32'))/2^(self.CORDIC_WIDTH-3)*pi;
            %tc_flags
            self.auxReg.addr = '01000018';
            self.auxReg.read;
            data.tc_flags = dec2bin(self.auxReg.value,8);
            %phase_c
            self.auxReg.addr = '0100001C';
            self.auxReg.read;
            data.phasec = double(typecast(self.auxReg.value,'int32'))/2^(self.CORDIC_WIDTH-3)*pi;
            %Debug
            self.auxReg.addr = '01000020';
            self.auxReg.read;
            d = dec2bin(self.auxReg.value,32);
            data.debug = d(32 - (3:-1:0));
            data.last = bin2dec(d(32 - (15:-1:4)));
            data.addr = bin2dec(d(32 - (27:-1:16)));
        end
        
        function self = start(self)
            %START Sends a software start trigger to the FPGA.
            self.trigReg.set(1,[1,1]).write;
            self.trigReg.set(0,[1,1]);
        end
        
        function self = resetTC(self)
            %RESETTC Resets the timing controller. This is needed before
            %upload because the timing controller assumes all new data
            %should be appended to existing data
            self.trigReg.set(1,[3,3]).write;
            self.trigReg.set(0,[3,3]);
        end
        
        function self = updateCIC(self)
            %UPDATECIC Sends a trigger to update the CIC rate for the phase
            %calculation
            self.trigReg.set(1,[0,0]).write;
            self.trigReg.set(0,[0,0]);
        end
        
        function r = convertDAC(self,v,direction,~)
            %CONVERTDAC Converts DAC values from integers to volts or from
            %volts to integers
            %
            %   R = SELF.CONVERTDAC(V,DIRECTION) converts value V in the
            %   direction given by DIRECTION, either 'int' or 'volt'
            %
            g = 1;
            if strcmpi(direction,'int')
                r = v/(g*2)*(2^(self.DAC_WIDTH - 1) - 1);
            elseif strcmpi(direction,'volt')
                r = (g*2)*v/(2^(self.DAC_WIDTH - 1) - 1);
            end
        end
        
        function r = convertADC(self,v,direction,~)
            %CONVERTADC Converts ADC values from integers to volts or from
            %volts to integers
            %
            %   R = SELF.CONVERTADC(V,DIRECTION) converts value V in the
            %   direction given by DIRECTION, either 'int' or 'volt'
            %
            if strcmpi(direction,'int')
                r = v/(g)*(2^(self.ADC_WIDTH + 1) - 1);
            elseif strcmpi(direction,'volt')
                r = (g)*v/(2^(self.ADC_WIDTH  + 1) - 1);
            end
        end
        
        function r = dt(self)
            %DT Computes the time step between updates from the CIC filter
            %
            %   R = SELF.DT() returns the CIC time step
            r = 2^self.cicRate.value/self.CLK;
        end
        
        function [Kp,Ki,Kd] = calcRealGains(self)
            %CALCREALGAINS Calculates the continuous-equivalent values of
            %the PID gains
            %
            %   [Kp,Ki,Kd] = SELF.CALCREALGAINS() returns proportional,
            %   integral, and derivative gains Kp, Ki, and Kd.
            Kp = self.Kp.value/2^self.divisor.value;
            Ki = self.Ki.value/(2^self.divisor.value*self.dt);
            Kd = self.Kd.value*self.dt/2^self.divisor.value;
        end
        
        function self = getPhaseData(self,numSamples,saveFlags,startFlag,saveType)
            %GETPHASEDATA Retrieves recorded phase data from the phase lock
            %
            %   Phase data is stored in the DATA property of the class, and
            %   timing information in the T property.
            %
            %   SELF.GETPHASEDATA(NUMSAMPLES) Returns NUMSAMPLES samples of
            %   only the directly measured phase.  The timing controller is
            %   not triggered prior to retrieving data.
            %
            %   SELF.GETPHASEDATA(__,SAVEFLAGS) gets phase data according
            %   the save flags, which are formatted as standard GNU flags.
            %   Use -p for the directly measured phase, -s for the
            %   phase-unwrapped re-summed phase, and -d for the phase that
            %   is applied to the DDS.  These can be combined as -psd or
            %   -ps or any such combination.
            %
            %   SELF.GETPHASEDATA(__,STARTFLAG) Set to 1 to trigger the
            %   timing controller prior to phase acquisition.  Set to 0 to
            %   not trigger.
            %
            %   SELF.GETPHASEDATA(__,SAVETYPE) Method for saving data in
            %   the C program running on the device.  Set to 0 to print
            %   data to terminal. Set to 1 to save to RAM before writing to
            %   a file and then sending over TCP/IP, and set to 2 to save
            %   directly to a file before sending over TCP/IP.  Default is
            %   1, and this likely never needs to change.
            %
            if nargin < 3
                saveFlags = '-p';
            end
            if nargin < 4 || startFlag == 0
                startFlag = '';
            else
                startFlag = '-b';
            end
            
            if nargin < 5
                saveType = 1;
            end
            
            self.conn.write(0,'mode','command','cmd',...
                {'./saveData','-n',sprintf('%d',round(numSamples)),'-t',sprintf('%d',saveType),saveFlags,startFlag},...
                'return_mode','file');
            raw = typecast(self.conn.recvMessage,'uint8');
            d = self.convertData(raw,'phase',saveFlags);
            self.data = d;
            self.t = 1/self.CLK*2^self.cicRate.value*(0:(numSamples-1));
        end
        
        function uploadTiming(self,t,ph,amp,freq,flags)
            %UPLOADTIMING Uploads timing controller data to the FPGA
            %
            %   SELF.UPLOADTIMING(T,PH,AMP,FREQ) Uploads timing data given
            %   by times T (in seconds), phase PH in radians, DDS scale
            %   factors AMP as an numel(T) x 2 array of values between 0
            %   and 1, and frequency FREQ as the frequency difference
            %   between the two DDS in MHz.
            %
            %   SELF.UPLOADTIMING(__,FLAGS) Additionally uploads flags
            %   FLAGS to the device.  FLAGS is a 4 bit signal in the timing
            %   controller.  Bit 0 of FLAGS enables the PID controller when
            %   high and disables when low.  Bit 1 of FLAGS holds the
            %   PID controller when high and resumes the PID controller
            %   when low.
            %
            t = t(:);
            ph = ph(:);
            if size(amp,2) ~= 2
                error('Amplitudes must be supplied as an Nx2 array!');
            end
            freq = freq(:);
            if nargin < 6
                flags = zeros(numel(freq),1);
            else
                flags = flags(:);
            end
            
            dt = uint32([round(diff(t)*self.CLK);1000]);
            ph = int32(ph/pi*2^(self.CORDIC_WIDTH-3));
            amp = uint32(amp*(2^self.AMP_WIDTH - 1));
            freq = uint32(freq*1e6/self.CLK*2^self.DDS_WIDTH);
            flags = uint32(flags);
            %
            % Duplicate last instruction but with a delay of 0, indicating
            % that the timing controller should stop
            %
            dt(end + 1) = 0;
            ph(end + 1) = ph(end);
            amp(end + 1,:) = amp(end,:);
            freq(end + 1) = freq(end);
            flags(end + 1) = flags(end);
            
            addr = self.timingReg.addr;
            d = zeros(4*numel(dt)+1,1,'uint32');
            d(1) = uint32(addr);
            mm = 2;
            for nn = 1:numel(dt)
                d(mm) = typecast(ph(nn),'uint32');
                mm = mm + 1;
                d(mm) = typecast(freq(nn),'uint32');
                mm = mm + 1;
                d(mm) = bitshift(typecast(amp(nn,2),'uint32'),12) + typecast(amp(nn,1),'uint32');
                mm = mm + 1;
                d(mm) = typecast(dt(nn),'uint32');
                d(mm) = d(mm) + bitshift(flags(nn),28);
                mm = mm + 1;
            end
            self.resetTC;
            self.conn.write(d,'mode','command','cmd',...
                {'./writeFile',sprintf('%d',round(numel(d) - 1))});
        end
        
        function disp(self)
            %DISP Displays information about the current PhaseLockAbstract
            %object
            strwidth = 36;
            fprintf(1,'PhaseLockAbstract object with properties:\n');
            fprintf(1,'\t Registers\n');
            self.topReg.print('topReg',strwidth);
            self.freqOffsetReg.print('freqOffsetReg',strwidth);
            self.freqDiffReg.print('freqDiffReg',strwidth);
            self.freqDemodReg.print('freqDemodReg',strwidth);
            self.phaseControlSigReg.print('phaseControlSigReg',strwidth);
            self.phaseCalcReg.print('phaseCalcReg',strwidth);
            self.phaseControlReg.print('phaseControlReg',strwidth);
            self.phaseGainReg.print('phaseGainReg',strwidth);
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Top-level parameters\n');
            self.shift.print('Freq. difference shift',strwidth,'%d');
            self.useSetDemod.print('Use fixed demod freq.',strwidth,'%d');
            self.useManual.print('Use manual',strwidth,'%d');
            self.useTCDemod.print('Use TC demod.',strwidth,'%d');
            self.disableExtTrig.print('Disable ext. trig.',strwidth,'%d');
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Frequency Parameters\n');
            self.f0.print('Common frequency',strwidth,'%.2f','MHz');
            self.df.print('Frequency difference',strwidth,'%.3f','MHz');
            self.demod.print('Demodulation frequency',strwidth,'%.3f','MHz');
            self.amp(1).print('Amplitude 1',strwidth,'%.3f','V');
            self.amp(2).print('Amplitude 2',strwidth,'%.3f','V');
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Phase calculation parameters\n');
            self.cicRate.print('CIC Rate',strwidth,'%d');
            self.cicShift.print('CIC Shift',strwidth,'%d');
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Phase control parameters\n');
            self.phasec.print('Control phase',strwidth,'%.3f','rad');
            self.enableFB.print('Enable feedback',strwidth,'%d');
            self.polarity.print('Control polarity',strwidth,'%d');
            self.Kp.print('Proportional gain',strwidth,'%d');
            self.Ki.print('Integral gain',strwidth,'%d');
            self.Kd.print('Derivative gain',strwidth,'%d');
            self.divisor.print('Overall divisor',strwidth,'%d');  
        end
        
        
    end
    
    methods(Static)
        function d = loadData(filename,dt,flags)
            %LOADDATA Loads a binary file and returns phase and timing data
            %
            %   D = LOADDATA(FILENAME,DT,FLAGS) Loads the file FILENAME
            %   with time step DT and flags FLAGS which indicate how to
            %   convert the saved data into phase values. If FILENAME is
            %   not given it is assumed to be SavedData.bin
            %
            if nargin == 0 || isempty(filename)
                filename = 'SavedData.bin';
            end
            
            %Load data
            fid = fopen(filename,'r');
            fseek(fid,0,'eof');
            fsize = ftell(fid);
            frewind(fid);
            x = fread(fid,fsize,'uint8');
            fclose(fid);
            
            d = PhaseLock.convertData(x,'phase',flags);
            if ~isempty(d.ph)
                N = numel(d.ph);
            elseif ~isempty(d.act)
                N = numel(d.act);
            elseif ~isempty(d.dds)
                N = numel(d.dds);
            end
            d.t = dt*(0:(N-1))';
        end
        
        function varargout = convertData(raw,method,flags)
            %CONVERTDATA Converts raw binary data into real values.
            %
            %   V = CONVERTDATA(RAW,'voltage') converts raw binary data RAW
            %   into voltages V
            %
            %   PH = CONVERTDATA(RAW,'phase',FLAGS) converts RAW binary
            %   data RAW into phase structure PH based on FLAGS.  FLAGS is
            %   a 3-bit value where each bit indicates what phases are
            %   included in the raw data.  Bit 0: measured phase. Bit 1:
            %   unwrapped, re-summed phase. Bit 2: actuator/DDS phase.
            %
            if nargin < 3 || isempty(flags)
                streams = 1;
            else
                streams = 0;
                if contains(flags,'p')
                    streams = streams + 1;
                end
                
                if contains(flags,'s')
                    streams = streams + 2;
                end
                
                if contains(flags,'d')
                    streams = streams + 4;
                end
            end
            raw = raw(:);
            Nraw = numel(raw);
            bits = bitget(streams,1:7);
            numStreams = sum(bits);
            d = zeros(Nraw/(numStreams*4),numStreams,'uint32');
            
            raw = reshape(raw,4*numStreams,Nraw/(4*numStreams));
            for nn = 1:numStreams
                d(:,nn) = typecast(uint8(reshape(raw((nn-1)*4+(1:4),:),4*size(d,1),1)),'uint32');
            end
            
            switch lower(method)
                case 'voltage'
                    v = double(d)/2^12;
                    varargout{1} = v;
                case 'phase'
                    data.ph = [];
                    data.sum = [];
                    data.dds = [];
                    if bits(1)
                        data.ph = double(typecast(d(:,1),'int32'))/2^(PhaseLock.CORDIC_WIDTH-3)*pi;
                    end
                    if bits(2)
                        idx = sum(bits(1:2));
%                         data.act = unwrap(double(d(:,idx))/2^(PhaseLock.CORDIC_WIDTH-3)*pi);
                        data.sum = double(typecast(d(:,idx),'int32'))/2^(PhaseLock.CORDIC_WIDTH-3)*pi;
                    end
                    if bits(3)
                        idx = sum(bits(1:3));   
                        data.dds = unwrap(double(d(:,idx))/2^PhaseLock.DDS_WIDTH*2*pi);
                    end
                    varargout{1} = data;
                otherwise
                    error('Data type unsupported!');
            end
        end
        
        function v = convertRAMData(raw,c)
            %CONVERTRAMDATA Converts raw data into proper int16/double format
            %
            %   V = CONVERTDATA(RAW) Unpacks raw data from uint8 values to
            %   a pair of double values for each measurement
            %
            %   V = CONVERTDATA(RAW,C) uses conversion factor C in the
            %   conversion
            
            if nargin < 2
                c = 1;
            end
            
            Nraw = numel(raw);
            d = zeros(Nraw/4,2,'int16');
            
            mm = 1;
            for nn = 1:4:Nraw
                d(mm,1) = typecast(uint8(raw(nn + (0:1))),'int16');
                d(mm,2) = typecast(uint8(raw(nn + (2:3))),'int16');
                mm = mm + 1;
            end
            
            v = double(d)*c;
        end
    end
    
end