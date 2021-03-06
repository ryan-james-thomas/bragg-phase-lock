classdef PhaseLock < handle
    properties
        t
        data
    end
    
    properties(SetAccess = immutable)
        conn        %ConnectionClient object for communicating with device
        %
        % Top-level properties
        %
        shift       %Shift right by this
        useSetDemod %True to use a fixed demodulation frequency, false to use shifted value
        useManual   %True to use manual values, false to use timing controller values
        useTCDemod  %True to use the TC df output as the OUT1 frequency and demod freq, for testing
        %
        % Frequency parameters
        %
        f0          %Center frequency
        df          %Difference frequency
        demod       %Demodulation frequency
        amp         %Amplitude
        %
        % Phase calculation parameters
        %
        cicRate     %Log2(CIC rate reduction)
        %
        % Phase control parameters
        %
        phasec      %Manual control phase
        enableFB    %Enable feedback
        polarity    %Feedback polarity
        Kp          %Proportional gain
        Ki          %Integral gain
        Kd          %Derivative gain
        divisor     %Overall divisor
        
    end
    
    properties(SetAccess = protected)
        %
        % R/W registers
        %
        trigReg             %Trigger register
        topReg              %Top-level register
        freqOffsetReg       %Register for common DDS frequency
        freqDiffReg         %Register for difference between DDS frequencies
        freqDemodReg        %Fixed demodulation frequency
        phaseControlSigReg  %Register for the phase control signal
        phaseCalcReg        %Register for calculating phase from ADC data
        phaseControlReg     %Register for PI control settings
        phaseGainReg        %Register for PI gain settings
        %
        % Read-only register
        %
        auxReg
        %
        % Write-only register
        %
        timingReg
    end
    
    properties(Constant)
        CLK = 125e6;                    %Clock frequency of the board
        HOST_ADDRESS = '192.168.1.109'; %Default socket server address
        DDS_WIDTH = 27;                 %Bit width of the DDS phase inputs
        CORDIC_WIDTH = 24;              %Bit width of the measured phase
        AMP_WIDTH = 12;                 %Bit width of amplitude scaling
    end
    
    methods
        function self = PhaseLock(varargin)
            if numel(varargin)==1
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
            self.amp = DeviceParameter([20,31],self.topReg)...
                .setLimits('lower',0,'upper',1)...
                .setFunctions('to',@(x) x*(2^self.AMP_WIDTH - 1),'from',@(x) x/(2^self.AMP_WIDTH - 1));
            %
            % Phase calculation
            %
            self.cicRate = DeviceParameter([0,7],self.phaseCalcReg)...
                .setLimits('lower',7,'upper',11)...
                .setFunctions('to',@(x) x,'from',@(x) x);
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
        
        function self = setDefaults(self,varargin)
            %
            % Top-level parameters
            %
            self.shift.set(3);
            self.useSetDemod.set(0);
            self.useManual.set(1);
            self.useTCDemod.set(0);
            %
            % Frequency parameters
            %
            self.f0.set(35);
            self.df.set(0.125);
            self.demod.set(1);
            self.amp.set(1);
            %
            % Phase calculation
            %
            self.cicRate.set(10);
            %
            % Phase control
            %
            self.phasec.set(0);
            self.enableFB.set(0);
            self.polarity.set(0);
            self.Kp.set(50);
            self.Ki.set(140);
            self.Kd.set(0);
            self.divisor.set(11);
        end
        
        function self = check(self)

        end
        
        function self = upload(self)
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
            self.f0.get;
            self.df.get;
            self.demod.get;
            self.amp.get;
            self.cicRate.get;
            self.phasec.get;
            
            self.enableFB.get;
            self.polarity.get;
            self.Kp.get;
            self.Ki.get;
            self.Kd.get;
            self.divisor.get;
        end
        
        function data = readOnly(self)
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
            %tc_amp
            self.auxReg.addr = '0100000C';
            self.auxReg.read;
            data.tc_amp = double(self.auxReg.value)/(2^self.AMP_WIDTH - 1);
            %tc_pow
            self.auxReg.addr = '01000010';
            self.auxReg.read;
            data.tc_pow = double(typecast(self.auxReg.value,'int32'))/2^(self.CORDIC_WIDTH-3)*pi;
            %tc_flags
            self.auxReg.addr = '01000014';
            self.auxReg.read;
            data.tc_flags = dec2bin(self.auxReg.value,8);
            %phase_c
            self.auxReg.addr = '01000018';
            self.auxReg.read;
            data.phasec = double(typecast(self.auxReg.value,'int32'))/2^(self.CORDIC_WIDTH-3)*pi;
            %Debug
            self.auxReg.addr = '0100001C';
            self.auxReg.read;
            data.debug = dec2bin(self.auxReg.value,8);
        end
        
        function self = start(self)
            self.trigReg.set(1,[1,1]).write;
            self.trigReg.set(0,[1,1]);
        end
        
        function self = resetTC(self)
            self.trigReg.set(1,[3,3]).write;
            self.trigReg.set(0,[3,3]);
        end
        
        function self = updateCIC(self)
            self.trigReg.set(1,[0,0]).write;
            self.trigReg.set(0,[0,0]);
        end
        
        function r = dt(self)
            r = 2^self.cicRate.value/self.CLK;
        end
        
        function [Kp,Ki,Kd] = calcRealGains(self)
            Kp = self.Kp.value/2^self.divisor.value;
            Ki = self.Ki.value/(2^self.divisor.value*self.dt);
            Kd = self.Kd.value*self.dt/2^self.divisor.value;
        end
        
        function self = getPhaseData(self,numSamples,saveFlags,startFlag,saveType)
            if nargin < 3
                saveFlags = '-p';
            end
            if nargin < 4 || startFlag == 0
                startFlag = '';
            else
                startFlag = '-b';
            end
            
            if nargin < 5
                saveType = 2;
            end
            
            self.conn.write(0,'mode','acquire phase','numSamples',numSamples,...
                'saveStreams',saveFlags,'saveType',0,'startFlag',startFlag,...
                'saveType',saveType);
            raw = typecast(self.conn.recvMessage,'uint8');
            d = self.convertData(raw,'phase',saveFlags);
            self.data = d;
            self.t = 1/self.CLK*2^self.cicRate.value*(0:(numSamples-1));
        end
        
        function uploadTiming(self,t,ph,amp,freq,flags)
            t = t(:);
            ph = ph(:);
            amp = amp(:);
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
            
            addr = self.timingReg.addr;
            d = zeros(4*numel(dt)+1,1,'uint32');
            d(1) = uint32(addr);
            mm = 2;
            for nn = 1:numel(dt)
                d(mm) = typecast(ph(nn),'uint32');
                mm = mm + 1;
                d(mm) = typecast(freq(nn),'uint32');
                mm = mm + 1;
                d(mm) = typecast(amp(nn),'uint32');
                mm = mm + 1;
                d(mm) = typecast(dt(nn),'uint32');
                d(mm) = d(mm) + bitshift(flags(nn),27);
                mm = mm + 1;
            end
            self.resetTC;
            self.conn.write(d);
        end
        
        function disp(self)
            strwidth = 36;
            fprintf(1,'PhaseLock object with properties:\n');
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
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Frequency Parameters\n');
            self.f0.print('Common frequency',strwidth,'%.2f','MHz');
            self.df.print('Frequency difference',strwidth,'%.3f','MHz');
            self.demod.print('Demodulation frequency',strwidth,'%.3f','MHz');
            self.amp.print('Amplitude',strwidth,'%.3f','V');
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Phase calculation parameters\n');
            self.cicRate.print('CIC Rate',strwidth,'%d');
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
    end
    
end