classdef IOSettings < handle
    properties
        attenuation
        gain
        coupling
    end
    
    properties(SetAccess = immutable)
        parent
    end
    
    methods
        function self = IOSettings(parent)
            self.parent = parent;
            self.setDefaults;
        end
        
        function self = setDefaults(self)
            self.attenuation = {'low','low'};
            self.gain = {'low','low'};
            self.coupling = {'dc','dc'};
        end
        
        function r = convert_attenuation(self,ch)
            r = self.convert(self.attenuation);
            if nargin > 1
                r = r(ch);
            end
        end
        
        function r = convert_gain(self,ch)
            r = self.convert(self.gain);
            if nargin > 1
                r = r(ch);
            end
        end
        
        function r = convert_coupling(self,ch)
            r = self.convert(self.coupling);
            if nargin > 1
                r = r(ch);
            end
        end
        
        function self = write(self)
            for nn = 1:numel(self.attenuation)
                self.parent.conn.write(0,'mode','command','cmd',...
                    {'./setGain','-i','-p',sprintf('%d',nn),'-v',sprintf('%d',self.convert(self.attenuation{nn}))});
                
            end
            
            for nn = 1:numel(self.gain)
                self.parent.conn.write(0,'mode','command','cmd',...
                    {'./setGain','-o','-p',sprintf('%d',nn),'-v',sprintf('%d',self.convert(self.gain{nn}))});
            end
            
            for nn = 1:numel(self.coupling)
                self.parent.conn.write(0,'mode','command','cmd',...
                    {'./setGain','-c','-p',sprintf('%d',nn),'-v',sprintf('%d',self.convert(self.coupling{nn}))});
            end
        end
        
        function varargout = print(self,width)
            s{1} = sprintf(['% ',num2str(width),'s: %s\n'],'Input atten. [1]',self.attenuation{1});
            s{2} = sprintf(['% ',num2str(width),'s: %s\n'],'Input atten. [2]',self.attenuation{2});
            s{3} = sprintf(['% ',num2str(width),'s: %s\n'],'Output gain [1]',self.gain{1});
            s{4} = sprintf(['% ',num2str(width),'s: %s\n'],'Output gain [2]',self.gain{2});
            s{5} = sprintf(['% ',num2str(width),'s: %s\n'],'Input coupling [1]',self.coupling{1});
            s{6} = sprintf(['% ',num2str(width),'s: %s\n'],'Input coupling [2]',self.coupling{2});
            ss = '';
            for nn = 1:numel(s)
                ss = [ss,s{nn}]; %#ok<AGROW>
            end
            
            if nargout == 0
                fprintf(1,ss);
            else
                varargout{1} = ss;
            end
        end
    end
    
    methods(Static)
        function r = convert(s)
            if iscell(s) && numel(s) > 1
                for nn = 1:numel(s)
                    r(nn,1) = IOSettings.convert(s{nn}); %#ok<AGROW>
                end
            else
                if strcmpi(s,'low') || strcmpi(s,'dc')
                    r = 0;
                elseif strcmpi(s,'high') || strcmpi(s,'ac')
                    r = 1;
                else
                    error('String must be either ''low'', ''high'', ''ac'', or ''dc''');
                end
            end
        end
    end
end