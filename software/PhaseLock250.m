classdef PhaseLock250 < PhaseLockAbstract
    %PhaseLock250 is an instance of the PhaseLockAbstract class designed
    %for interfacing with the phase lock design for the SIGNALlab board
    %which has a 250 MHz clock (hence the 250!).
    %
    %   One of the main differences, other than the clock rate, is that the
    %   SIGNALlab has programmable attenuators and gain values which can be
    %   set using the 'settings' property, which is an instance of the
    %   IOSettings class.
    %
    %   This design also stores ADC values for debugging purposes, and
    %   these can be retrieved using the getRAM() method.
    %
    properties(SetAccess = immutable)
        %% IO settings
        settings    %I/O settings as IOsettings object
        %% Debugging signals
        numSamples  %Number of samples to store in RAM
        lastSample  %Last sample stored in RAM
        adc
    end
    
    properties(SetAccess = protected)
        %% R/W registers
        numSamplesReg       %Register for number of samples
        lastSampleReg       %Register for the last sample
        adcReg
    end
    
    properties(Constant)
        CLK = 250e6;                    %Clock frequency of the board
    end
    
    methods
        function self = PhaseLock250(varargin)
            %PhaseLock250 Constructor for this class.
            %
            % SELF = PhaseLock250(HOST_ADDRESS) constructs a
            % PhaseLock250 object using the given HOST_ADDRESS for
            % connecting to the remote server.  HOST_ADDRESS can be
            % neglected, in which case the default HOST_ADDRESS is used
            %
            self = self@PhaseLockAbstract(varargin{:});
            %
            % Create the IOSettings object
            %
            self.settings = IOSettings(self);
            %
            % Debugging registers
            %
            self.numSamplesReg = DeviceRegister('38',self.conn);
            self.lastSampleReg = DeviceRegister('01000024',self.conn);
            self.adcReg = DeviceRegister('01000028',self.conn);
            %
            % Debugging signals
            %
            self.numSamples = DeviceParameter([0,13],self.numSamplesReg)...
                .setLimits('lower',0,'upper',2^14 - 1);
            self.lastSample = DeviceParameter([0,31],self.lastSampleReg);
            self.adc = DeviceParameter([0,15],self.adcReg,'int16')...
                .setFunctions('from',@(x) self.convertADC(x,'volt',1));
            self.adc(2) = DeviceParameter([16,31],self.adcReg,'int16')...
                .setFunctions('from',@(x) self.convertADC(x,'volt',2));
        end
        
        function self = setDefaults(self)
            %SETDEFAULTS Sets the default values
            setDefaults@PhaseLockAbstract;
            self.settings.setDefaults;
            self.settings.coupling = {'ac','ac'};
            %
            % Debugging signals
            %
            self.numSamples.set(16e3);
            
        end
        
        function self = fetch(self)
            %FETCH Retrieves all current register values and parses them
            %for parameters
            
            fetch@PhaseLockAbstract;
            %Read registers
            self.numSamplesReg.read;
            self.lastSampleReg.read;
            self.adcReg.read;
            %Read parameters
            self.numSamples.get;
            self.lastSample.get;
            self.adc(1).get;
            self.adc(2).get;
        end
        
        function r = convertDAC(self,v,direction,ch)
            %CONVERTDAC Converts DAC values from integers to volts or from
            %volts to integers
            %
            %   R = SELF.CONVERTDAC(V,DIRECTION) converts value V in the
            %   direction given by DIRECTION, either 'int' or 'volt'
            %
            g = (self.settings.convert_gain(ch) == 0)*1 + (self.settings.convert_gain(ch) == 1)*5;
            if strcmpi(direction,'int')
                r = v/(g*2)*(2^(self.DAC_WIDTH - 1) - 1);
            elseif strcmpi(direction,'volt')
                r = (g*2)*v/(2^(self.DAC_WIDTH - 1) - 1);
            end
        end
        
        function r = convertADC(self,v,direction,ch)
            %CONVERTADC Converts ADC values from integers to volts or from
            %volts to integers
            %
            %   R = SELF.CONVERTADC(V,DIRECTION) converts value V in the
            %   direction given by DIRECTION, either 'int' or 'volt'
            %
            g = (self.settings.convert_attenuation(ch) == 0)*1.1 + (self.settings.convert_attenuation(ch) == 1)*20;
            if strcmpi(direction,'int')
                r = v/(g)*(2^(self.ADC_WIDTH + 1) - 1);
            elseif strcmpi(direction,'volt')
                r = (g)*v/(2^(self.ADC_WIDTH  + 1) - 1);
            end
        end
        
        function [d,t] = getRAM(self,numSamples)
            %GETRAM Acquires and retrieves ADC data from the block memory
            %
            %   [D,T] = SELF.GETRAM(NUMSAMPLES) retrieves NUMSAMPLES
            %   samples from the block memory and converts it into data D
            %   and times T.  If NUMSAMPLES is not provided, the method
            %   retrieves the last sample address written to the device
            %
            
            %
            % Trigger acquisition
            %
            self.trigReg.set(1,[4,4]).write;
            self.trigReg.set(0,[4,4]);
            pause(1e-3);
            %
            % Get last sample
            %
            if nargin < 2
%                 self.conn.keepAlive = true;
                self.lastSample.read;
%                 self.conn.keepAlive = false;
                numSamples = self.lastSample.value;
            end
            self.conn.write(0,'mode','command','cmd',...
                {'./fetchRAM',sprintf('%d',round(numSamples))},...
                'return_mode','file');
            raw = typecast(self.conn.recvMessage,'uint8');
            
            d = self.convertRAMData(raw);
            for nn = 1:size(d,2)
                d(:,nn) = self.convertADC(d(:,nn),'volt',nn);
            end
            dt = self.CLK^-1;
            t = dt*(0:(size(d,1)-1));
        end
        
        function disp(self)
            %DISP Displays information about the current PhaseLockAbstract
            %object
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
            self.numSamplesReg.print('Num. Samples. Reg',strwidth);
            self.lastSampleReg.print('Memory register',strwidth);
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
            fprintf(1,'\t ----------------------------------\n');
            fprintf(1,'\t Debugging parameters\n');
            self.numSamples.print('Number of samples',strwidth,'%d');
            self.lastSample.print('Samples collected',strwidth,'%d');
            self.adc(1).print('ADC 1',strwidth,'%.3f');
            self.adc(2).print('ADC 2',strwidth,'%.3f');
        end
        
        
    end

    
end