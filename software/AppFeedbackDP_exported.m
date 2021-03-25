classdef AppFeedbackDP_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        TabGroup                        matlab.ui.container.TabGroup
        SettingsTab                     matlab.ui.container.Tab
        EnableDispersivePulsesCheckBox  matlab.ui.control.CheckBox
        EnableFeedbackCheckBox          matlab.ui.control.CheckBox
        EnableNormalisationCheckBox     matlab.ui.control.CheckBox
        UseManualMWPulsesCheckBox       matlab.ui.control.CheckBox
        DispersivePulseSettingsPanel    matlab.ui.container.Panel
        PulseWidthsEditFieldLabel       matlab.ui.control.Label
        PulseWidthsEditField            matlab.ui.control.NumericEditField
        PulsePeriodsEditFieldLabel      matlab.ui.control.Label
        PulsePeriodsEditField           matlab.ui.control.NumericEditField
        EOMDelaysEditFieldLabel         matlab.ui.control.Label
        EOMDelaysEditField              matlab.ui.control.NumericEditField
        SamplingSettingsPanel           matlab.ui.container.Panel
        AcqDelaysEditFieldLabel         matlab.ui.control.Label
        AcqDelaysEditField              matlab.ui.control.NumericEditField
        SamplesPerPulseSpinnerLabel     matlab.ui.control.Label
        SamplesPerPulseSpinner          matlab.ui.control.Spinner
        Log2OfAvgsSpinnerLabel          matlab.ui.control.Label
        Log2OfAvgsSpinner               matlab.ui.control.Spinner
        StartofSummationSpinnerLabel    matlab.ui.control.Label
        StartofSummationSpinner         matlab.ui.control.Spinner
        StartofSubractionSpinnerLabel   matlab.ui.control.Label
        StartofSubractionSpinner        matlab.ui.control.Spinner
        SumSubwidthSpinnerLabel         matlab.ui.control.Label
        SumSubwidthSpinner              matlab.ui.control.Spinner
        ShutterDelaysEditFieldLabel     matlab.ui.control.Label
        ShutterDelaysEditField          matlab.ui.control.NumericEditField
        FeedbackSettingsPanel           matlab.ui.container.Panel
        MaxMWPulsesEditFieldLabel       matlab.ui.control.Label
        MaxMWPulsesEditField            matlab.ui.control.NumericEditField
        TargetSignalEditFieldLabel      matlab.ui.control.Label
        TargetSignalEditField           matlab.ui.control.NumericEditField
        SignalToleranceEditFieldLabel   matlab.ui.control.Label
        SignalToleranceEditField        matlab.ui.control.NumericEditField
        MicrowaveSettingsPanel          matlab.ui.container.Panel
        MWPulseWidthsEditFieldLabel     matlab.ui.control.Label
        MWPulseWidthsEditField          matlab.ui.control.NumericEditField
        MWPulsePeriodsEditFieldLabel    matlab.ui.control.Label
        MWPulsePeriodsEditField         matlab.ui.control.NumericEditField
        ManualMWPulsesSpinnerLabel      matlab.ui.control.Label
        ManualMWPulsesSpinner           matlab.ui.control.Spinner
        FetchSettingsButton             matlab.ui.control.Button
        UploadSettingsButton            matlab.ui.control.Button
        SetDefaultsButton               matlab.ui.control.Button
        FetchDataButton                 matlab.ui.control.Button
        ReadonlyPanel                   matlab.ui.container.Panel
        NumberofSamplesCollectedEditFieldLabel  matlab.ui.control.Label
        NumberofSamplesCollectedEditField  matlab.ui.control.NumericEditField
        NumberofPulsesCollectedEditFieldLabel  matlab.ui.control.Label
        NumberofPulsesCollectedEditField  matlab.ui.control.NumericEditField
        NumberofPowerPulsesCollectedEditFieldLabel  matlab.ui.control.Label
        NumberofPowerPulsesCollectedEditField  matlab.ui.control.NumericEditField
        ResetButton                     matlab.ui.control.Button
        StartButton                     matlab.ui.control.Button
        CalculatedValuesPanel           matlab.ui.container.Panel
        EffectivesamplerateHzEditFieldLabel  matlab.ui.control.Label
        EffectivesamplerateHzEditField  matlab.ui.control.NumericEditField
        SamplesPulseWidthEditFieldLabel  matlab.ui.control.Label
        SamplesPulseWidthEditField      matlab.ui.control.NumericEditField
        SamplesPulsePeriodEditFieldLabel  matlab.ui.control.Label
        SamplesPulsePeriodEditField     matlab.ui.control.NumericEditField
        ManualOutputsPanel              matlab.ui.container.Panel
        UseManualValuesButton           matlab.ui.control.StateButton
        DPPulseButton                   matlab.ui.control.StateButton
        ShutterButton                   matlab.ui.control.StateButton
        MWPulseButton                   matlab.ui.control.StateButton
        EOMButton                       matlab.ui.control.StateButton
        NumberofPulsesSpinnerLabel      matlab.ui.control.Label
        NumberofPulsesSpinner           matlab.ui.control.Spinner
        RawDataTab                      matlab.ui.container.Tab
        UIAxes                          matlab.ui.control.UIAxes
        UIAxes4                         matlab.ui.control.UIAxes
        SignalTab                       matlab.ui.container.Tab
        UIAxes2                         matlab.ui.control.UIAxes
        DisplayPowerButton              matlab.ui.control.StateButton
        NormalisedDataTab               matlab.ui.container.Tab
        UIAxes3                         matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        displayPower % Description
    end
    
    properties (Access = public)
        fb      DPFeedback      % DPFeedback Object
        pwr     DPPower         % DPPower Object
    end
    
    methods (Access = private)
        
        function results = updateFields(app)
            app.EnableDispersivePulsesCheckBox.Value = app.fb.enableDP.value;
            app.EnableFeedbackCheckBox.Value = app.fb.enableFB.value;
            app.EnableNormalisationCheckBox.Value = app.fb.normalise.value;
            app.UseManualMWPulsesCheckBox.Value = app.fb.enableManualMW.value;
            
            app.PulseWidthsEditField.Value = app.fb.width.value;
            app.PulsePeriodsEditField.Value = app.fb.period.value;
            app.NumberofPulsesSpinner.Value = app.fb.numpulses.value;
            app.EOMDelaysEditField.Value = app.fb.eomDelay.value;
            
            app.ShutterDelaysEditField.Value = app.fb.shutterDelay.value;
            app.AcqDelaysEditField.Value = app.fb.delay.value;
            app.SamplesPerPulseSpinner.Value = app.fb.samplesPerPulse.value;
            app.Log2OfAvgsSpinner.Value = app.fb.log2Avgs.value;
            app.StartofSummationSpinner.Value = app.fb.sumStart.value;
            app.StartofSubractionSpinner.Value = app.fb.subStart.value;
            app.SumSubwidthSpinner.Value = app.fb.sumWidth.value;
            
            app.MaxMWPulsesEditField.Value = app.fb.maxMWPulses.value;
            app.TargetSignalEditField.Value = app.fb.quadTarget.value;
            app.SignalToleranceEditField.Value = app.fb.quadTol.value;
            app.ManualMWPulsesSpinner.Value = app.fb.mwNumPulses.value;
            app.MWPulseWidthsEditField.Value = app.fb.mwPulseWidth.value;
            app.MWPulsePeriodsEditField.Value = app.fb.mwPulsePeriod.value;
            
            
            app.NumberofSamplesCollectedEditField.Value = app.fb.samplesCollected.value;
            app.NumberofPulsesCollectedEditField.Value = app.fb.pulsesCollected.value;
            app.NumberofPowerPulsesCollectedEditField.Value = app.pwr.numpulses.value;
            
            app.EffectivesamplerateHzEditField.Value = app.fb.CLK*2^(-app.fb.log2Avgs.value);
            app.SamplesPulsePeriodEditField.Value = app.fb.period.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
            app.SamplesPulseWidthEditField.Value = app.fb.width.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
            
            app.UseManualValuesButton.Value = logical(app.fb.manualFlag.value);
            app.DPPulseButton.Value = logical(app.fb.pulseDPMan.value);
            app.ShutterButton.Value = logical(app.fb.shutterDPMan.value);
            app.MWPulseButton.Value = logical(app.fb.pulseMWMan.value);
            app.EOMButton.Value = logical(app.fb.eomMan.value);
            
            results = 0;
        end
        
        function plotData(app)
            cla(app.UIAxes);
            plot(app.UIAxes,1:app.fb.samplesPerPulse.value,app.fb.rawI,'b.-');
            hold(app.UIAxes,'on');
            plot(app.UIAxes,1:app.fb.samplesPerPulse.value,app.fb.rawQ,'r.-');
            yy = ylim(app.UIAxes);
            plot(app.UIAxes,app.fb.sumStart.value*[1,1],yy,'k--','linewidth',2);
            plot(app.UIAxes,(app.fb.sumStart.value+app.fb.sumWidth.value)*[1,1],yy,'k--','linewidth',2);
            plot(app.UIAxes,app.fb.subStart.value*[1,1],yy,'k--','linewidth',2);
            plot(app.UIAxes,(app.fb.subStart.value+app.fb.sumWidth.value)*[1,1],yy,'k--','linewidth',2);
            hold(app.UIAxes,'off');
%             legend(app.UIAxes,'Raw I','Raw Q');
            xlabel(app.UIAxes,'Samples');ylabel(app.UIAxes,'Value');
            
            cla(app.UIAxes4);
            if app.fb.normalise.value
                plot(app.UIAxes4,1:app.pwr.samplesPerPulse.value,app.pwr.rawI,'.-');
                hold(app.UIAxes4,'on');
    %             plot(app.UIAxes4,1:app.pwr.samplesPerPulse.value,app.pwr.rawQ,'.-');
                yy = ylim(app.UIAxes4);
                plot(app.UIAxes4,app.pwr.sumStart.value*[1,1],yy,'k--','linewidth',2);
                plot(app.UIAxes4,(app.pwr.sumStart.value+app.fb.sumWidth.value)*[1,1],yy,'k--','linewidth',2);
                plot(app.UIAxes4,app.pwr.subStart.value*[1,1],yy,'k--','linewidth',2);
                plot(app.UIAxes4,(app.pwr.subStart.value+app.pwr.sumWidth.value)*[1,1],yy,'k--','linewidth',2);
                hold(app.UIAxes4,'off');
    %             legend(app.UIAxes,'Raw I','Raw Q');
                xlabel(app.UIAxes4,'Samples');ylabel(app.UIAxes4,'Value');
            end
            
            cla(app.UIAxes2);
            plot(app.UIAxes2,app.fb.tPulse,app.fb.data,'.-');
            if app.displayPower
                hold(app.UIAxes2,'on');
                plot(app.UIAxes2,app.pwr.tPulse,app.pwr.signal,'.-');
                legend(app.UIAxes2,'I','Q','P');
                hold(app.UIAxes2,'off');
            else
                legend(app.UIAxes2,'I','Q');
            end
            xlabel(app.UIAxes2,'Time [s]');ylabel(app.UIAxes2,'Value');
            
            
            cla(app.UIAxes3);
            if app.fb.normalise.value && numel(app.fb.signal)==numel(app.pwr.signal)
                plot(app.UIAxes3,app.fb.tPulse,app.fb.signal./app.pwr.signal,'.-');
            else
                plot(app.UIAxes3,app.fb.tPulse,app.fb.signal,'.-');
            end
            xlabel(app.UIAxes3,'Time [s]');ylabel(app.UIAxes3,'Signal');
            legend(app.UIAxes3,'Signal');
        end
    end
    

    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, fb, pwr)
            if nargin < 2
                app.fb = DPFeedback;
                app.pwr = DPPower;
                app.fb.setDefaults;
                app.pwr.setDefaults;
            elseif nargin < 3
                app.fb = fb;
                app.pwr = DPPower;
            elseif nargin >= 3
                app.fb = fb;
                app.pwr = pwr;
            end
            app.updateFields;
        end

        % Value changed function: EnableDispersivePulsesCheckBox
        function EnableDispersivePulsesCheckBoxValueChanged(app, event)
            value = app.EnableDispersivePulsesCheckBox.Value;
            app.fb.enableDP.set(logical(value));
        end

        % Value changed function: EnableFeedbackCheckBox
        function EnableFeedbackCheckBoxValueChanged(app, event)
            value = app.EnableFeedbackCheckBox.Value;
            app.fb.enableFB.set(logical(value));
        end

        % Value changed function: EnableNormalisationCheckBox
        function EnableNormalisationCheckBoxValueChanged(app, event)
            value = app.EnableNormalisationCheckBox.Value;
            app.fb.normalise.set(logical(value));
        end

        % Value changed function: UseManualMWPulsesCheckBox
        function UseManualMWPulsesCheckBoxValueChanged(app, event)
            value = app.UseManualMWPulsesCheckBox.Value;
            app.fb.enableManualMW.set(logical(value));
        end

        % Value changed function: PulseWidthsEditField
        function PulseWidthsEditFieldValueChanged(app, event)
            value = app.PulseWidthsEditField.Value;
            app.fb.width.set(value);
            app.SamplesPulseWidthEditField.Value = app.fb.width.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
        end

        % Value changed function: PulsePeriodsEditField
        function PulsePeriodsEditFieldValueChanged(app, event)
            value = app.PulsePeriodsEditField.Value;
            app.fb.period.set(value);
            app.SamplesPulsePeriodEditField.Value = app.fb.period.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
        end

        % Value changed function: NumberofPulsesSpinner
        function NumberofPulsesSpinnerValueChanged(app, event)
            value = app.NumberofPulsesSpinner.Value;
            app.fb.numpulses.set(value);
        end

        % Value changed function: AcqDelaysEditField
        function AcqDelaysEditFieldValueChanged(app, event)
            value = app.AcqDelaysEditField.Value;
            app.fb.delay.set(value);
        end

        % Value changed function: SamplesPerPulseSpinner
        function SamplesPerPulseSpinnerValueChanged(app, event)
            value = app.SamplesPerPulseSpinner.Value;
            app.fb.samplesPerPulse.set(value);
            app.pwr.samplesPerPulse.set(value);
        end

        % Value changed function: Log2OfAvgsSpinner
        function Log2OfAvgsSpinnerValueChanged(app, event)
            value = app.Log2OfAvgsSpinner.Value;
            app.fb.log2Avgs.set(value);
            app.pwr.log2Avgs.set(value);
            app.EffectivesamplerateHzEditField.Value = app.fb.CLK*2^(-app.fb.log2Avgs.value);
            app.SamplesPulsePeriodEditField.Value = app.fb.period.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
            app.SamplesPulseWidthEditField.Value = app.fb.width.value*app.fb.CLK*2^(-app.fb.log2Avgs.value);
        end

        % Value changed function: StartofSummationSpinner
        function StartofSummationSpinnerValueChanged(app, event)
            value = app.StartofSummationSpinner.Value;
            app.fb.sumStart.set(value);
            app.pwr.sumStart.set(value);
        end

        % Value changed function: StartofSubractionSpinner
        function StartofSubractionSpinnerValueChanged(app, event)
            value = app.StartofSubractionSpinner.Value;
            app.fb.subStart.set(value);
            app.pwr.subStart.set(value);
        end

        % Value changed function: SumSubwidthSpinner
        function SumSubwidthSpinnerValueChanged(app, event)
            value = app.SumSubwidthSpinner.Value;
            app.fb.sumWidth.set(value);
            app.pwr.sumWidth.set(value);
        end

        % Value changed function: MaxMWPulsesEditField
        function MaxMWPulsesEditFieldValueChanged(app, event)
            value = app.MaxMWPulsesEditField.Value;
            app.fb.maxMWPulses.set(value);
        end

        % Value changed function: TargetSignalEditField
        function TargetSignalEditFieldValueChanged(app, event)
            value = app.TargetSignalEditField.Value;
            app.fb.quadTarget.set(value);
        end

        % Value changed function: SignalToleranceEditField
        function SignalToleranceEditFieldValueChanged(app, event)
            value = app.SignalToleranceEditField.Value;
            app.fb.quadTol.set(value);
        end

        % Value changed function: MWPulseWidthsEditField
        function MWPulseWidthsEditFieldValueChanged(app, event)
            value = app.MWPulseWidthsEditField.Value;
            app.fb.mwPulseWidth.set(value);
        end

        % Value changed function: MWPulsePeriodsEditField
        function MWPulsePeriodsEditFieldValueChanged(app, event)
            value = app.MWPulsePeriodsEditField.Value;
            app.fb.mwPulsePeriod.set(value);
        end

        % Value changed function: ManualMWPulsesSpinner
        function ManualMWPulsesSpinnerValueChanged(app, event)
            value = app.ManualMWPulsesSpinner.Value;
            app.fb.mwNumPulses.set(value);
        end

        % Button pushed function: FetchSettingsButton
        function FetchSettingsButtonPushed(app, event)
            app.fb.fetch;
            app.pwr.fetch;
            
            app.updateFields;
        end

        % Button pushed function: UploadSettingsButton
        function UploadSettingsButtonPushed(app, event)
            app.fb.upload;
            app.pwr.upload;
        end

        % Button pushed function: SetDefaultsButton
        function SetDefaultsButtonPushed(app, event)
            app.fb.setDefaults;
            app.pwr.setDefaults;
            app.pwr.copyfb(app.fb);
            
            app.updateFields;
        end

        % Button pushed function: FetchDataButton
        function FetchDataButtonPushed(app, event)
            app.fb.getRaw.getProcessed;
            app.pwr.getRaw.getProcessed(app.fb.period.value);
            
            app.updateFields;
            
            app.plotData;
        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
            app.fb.reset;
            app.pwr.reset;
        end

        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
            app.pwr.reset;
            app.fb.start;
        end

        % Value changed function: ShutterDelaysEditField
        function ShutterDelaysEditFieldValueChanged(app, event)
            value = app.ShutterDelaysEditField.Value;
            app.fb.shutterDelay.set(value);
        end

        % Value changed function: UseManualValuesButton
        function UseManualValuesButtonValueChanged(app, event)
            value = app.UseManualValuesButton.Value;
            app.fb.manualFlag.set(value).write;
        end

        % Value changed function: DPPulseButton
        function DPPulseButtonValueChanged(app, event)
            value = app.DPPulseButton.Value;
            app.fb.pulseDPMan.set(value).write;
        end

        % Value changed function: ShutterButton
        function ShutterButtonValueChanged(app, event)
            value = app.ShutterButton.Value;
            app.fb.shutterDPMan.set(value).write;
        end

        % Value changed function: MWPulseButton
        function MWPulseButtonValueChanged(app, event)
            value = app.MWPulseButton.Value;
            app.fb.pulseMWMan.set(value).write;
        end

        % Value changed function: DisplayPowerButton
        function DisplayPowerButtonValueChanged(app, event)
            value = app.DisplayPowerButton.Value;
            app.displayPower = value;
            app.plotData;
        end

        % Value changed function: EOMButton
        function EOMButtonValueChanged(app, event)
            value = app.EOMButton.Value;
            app.fb.eomMan.set(value).write;
        end

        % Value changed function: EOMDelaysEditField
        function EOMDelaysEditFieldValueChanged(app, event)
            value = app.EOMDelaysEditField.Value;
            app.fb.eomDelay.set(value);
        end
    end

    % App initialization and construction
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure
            app.UIFigure = uifigure;
            app.UIFigure.Position = [100 100 863 667];
            app.UIFigure.Name = 'UI Figure';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [1 1 863 667];

            % Create SettingsTab
            app.SettingsTab = uitab(app.TabGroup);
            app.SettingsTab.Title = 'Settings';

            % Create EnableDispersivePulsesCheckBox
            app.EnableDispersivePulsesCheckBox = uicheckbox(app.SettingsTab);
            app.EnableDispersivePulsesCheckBox.ValueChangedFcn = createCallbackFcn(app, @EnableDispersivePulsesCheckBoxValueChanged, true);
            app.EnableDispersivePulsesCheckBox.Text = 'Enable Dispersive Pulses';
            app.EnableDispersivePulsesCheckBox.Position = [15 611 158 22];

            % Create EnableFeedbackCheckBox
            app.EnableFeedbackCheckBox = uicheckbox(app.SettingsTab);
            app.EnableFeedbackCheckBox.ValueChangedFcn = createCallbackFcn(app, @EnableFeedbackCheckBoxValueChanged, true);
            app.EnableFeedbackCheckBox.Text = 'Enable Feedback';
            app.EnableFeedbackCheckBox.Position = [15 576 115 22];

            % Create EnableNormalisationCheckBox
            app.EnableNormalisationCheckBox = uicheckbox(app.SettingsTab);
            app.EnableNormalisationCheckBox.ValueChangedFcn = createCallbackFcn(app, @EnableNormalisationCheckBoxValueChanged, true);
            app.EnableNormalisationCheckBox.Text = 'Enable Normalisation';
            app.EnableNormalisationCheckBox.Position = [15 540 136 22];

            % Create UseManualMWPulsesCheckBox
            app.UseManualMWPulsesCheckBox = uicheckbox(app.SettingsTab);
            app.UseManualMWPulsesCheckBox.ValueChangedFcn = createCallbackFcn(app, @UseManualMWPulsesCheckBoxValueChanged, true);
            app.UseManualMWPulsesCheckBox.Text = 'Use Manual MW Pulses';
            app.UseManualMWPulsesCheckBox.Position = [15 504 150 22];

            % Create DispersivePulseSettingsPanel
            app.DispersivePulseSettingsPanel = uipanel(app.SettingsTab);
            app.DispersivePulseSettingsPanel.Title = 'Dispersive Pulse Settings';
            app.DispersivePulseSettingsPanel.Position = [8 346 246 146];

            % Create PulseWidthsEditFieldLabel
            app.PulseWidthsEditFieldLabel = uilabel(app.DispersivePulseSettingsPanel);
            app.PulseWidthsEditFieldLabel.HorizontalAlignment = 'right';
            app.PulseWidthsEditFieldLabel.Position = [26 98 86 22];
            app.PulseWidthsEditFieldLabel.Text = 'Pulse Width [s]';

            % Create PulseWidthsEditField
            app.PulseWidthsEditField = uieditfield(app.DispersivePulseSettingsPanel, 'numeric');
            app.PulseWidthsEditField.ValueChangedFcn = createCallbackFcn(app, @PulseWidthsEditFieldValueChanged, true);
            app.PulseWidthsEditField.Position = [117 98 100 22];

            % Create PulsePeriodsEditFieldLabel
            app.PulsePeriodsEditFieldLabel = uilabel(app.DispersivePulseSettingsPanel);
            app.PulsePeriodsEditFieldLabel.HorizontalAlignment = 'right';
            app.PulsePeriodsEditFieldLabel.Position = [16 67 90 22];
            app.PulsePeriodsEditFieldLabel.Text = 'Pulse Period [s]';

            % Create PulsePeriodsEditField
            app.PulsePeriodsEditField = uieditfield(app.DispersivePulseSettingsPanel, 'numeric');
            app.PulsePeriodsEditField.ValueChangedFcn = createCallbackFcn(app, @PulsePeriodsEditFieldValueChanged, true);
            app.PulsePeriodsEditField.Position = [117 67 100 22];

            % Create EOMDelaysEditFieldLabel
            app.EOMDelaysEditFieldLabel = uilabel(app.DispersivePulseSettingsPanel);
            app.EOMDelaysEditFieldLabel.HorizontalAlignment = 'right';
            app.EOMDelaysEditFieldLabel.Position = [19 5 83 22];
            app.EOMDelaysEditFieldLabel.Text = 'EOM Delay [s]';

            % Create EOMDelaysEditField
            app.EOMDelaysEditField = uieditfield(app.DispersivePulseSettingsPanel, 'numeric');
            app.EOMDelaysEditField.ValueChangedFcn = createCallbackFcn(app, @EOMDelaysEditFieldValueChanged, true);
            app.EOMDelaysEditField.Position = [117 5 100 22];

            % Create SamplingSettingsPanel
            app.SamplingSettingsPanel = uipanel(app.SettingsTab);
            app.SamplingSettingsPanel.Title = 'Sampling Settings';
            app.SamplingSettingsPanel.Position = [9 70 245 268];

            % Create AcqDelaysEditFieldLabel
            app.AcqDelaysEditFieldLabel = uilabel(app.SamplingSettingsPanel);
            app.AcqDelaysEditFieldLabel.HorizontalAlignment = 'right';
            app.AcqDelaysEditFieldLabel.Position = [43 178 76 22];
            app.AcqDelaysEditFieldLabel.Text = 'Acq Delay [s]';

            % Create AcqDelaysEditField
            app.AcqDelaysEditField = uieditfield(app.SamplingSettingsPanel, 'numeric');
            app.AcqDelaysEditField.ValueChangedFcn = createCallbackFcn(app, @AcqDelaysEditFieldValueChanged, true);
            app.AcqDelaysEditField.Position = [134 178 100 22];

            % Create SamplesPerPulseSpinnerLabel
            app.SamplesPerPulseSpinnerLabel = uilabel(app.SamplingSettingsPanel);
            app.SamplesPerPulseSpinnerLabel.HorizontalAlignment = 'right';
            app.SamplesPerPulseSpinnerLabel.Position = [13 147 108 22];
            app.SamplesPerPulseSpinnerLabel.Text = 'Samples Per Pulse';

            % Create SamplesPerPulseSpinner
            app.SamplesPerPulseSpinner = uispinner(app.SamplingSettingsPanel);
            app.SamplesPerPulseSpinner.ValueChangedFcn = createCallbackFcn(app, @SamplesPerPulseSpinnerValueChanged, true);
            app.SamplesPerPulseSpinner.Position = [136 147 100 22];

            % Create Log2OfAvgsSpinnerLabel
            app.Log2OfAvgsSpinnerLabel = uilabel(app.SamplingSettingsPanel);
            app.Log2OfAvgsSpinnerLabel.HorizontalAlignment = 'right';
            app.Log2OfAvgsSpinnerLabel.Position = [33 113 88 22];
            app.Log2OfAvgsSpinnerLabel.Text = 'Log2 # Of Avgs';

            % Create Log2OfAvgsSpinner
            app.Log2OfAvgsSpinner = uispinner(app.SamplingSettingsPanel);
            app.Log2OfAvgsSpinner.ValueChangedFcn = createCallbackFcn(app, @Log2OfAvgsSpinnerValueChanged, true);
            app.Log2OfAvgsSpinner.Position = [136 113 100 22];

            % Create StartofSummationSpinnerLabel
            app.StartofSummationSpinnerLabel = uilabel(app.SamplingSettingsPanel);
            app.StartofSummationSpinnerLabel.HorizontalAlignment = 'right';
            app.StartofSummationSpinnerLabel.Position = [13 77 108 22];
            app.StartofSummationSpinnerLabel.Text = 'Start of Summation';

            % Create StartofSummationSpinner
            app.StartofSummationSpinner = uispinner(app.SamplingSettingsPanel);
            app.StartofSummationSpinner.ValueChangedFcn = createCallbackFcn(app, @StartofSummationSpinnerValueChanged, true);
            app.StartofSummationSpinner.Position = [136 77 100 22];

            % Create StartofSubractionSpinnerLabel
            app.StartofSubractionSpinnerLabel = uilabel(app.SamplingSettingsPanel);
            app.StartofSubractionSpinnerLabel.HorizontalAlignment = 'right';
            app.StartofSubractionSpinnerLabel.Position = [16 42 105 22];
            app.StartofSubractionSpinnerLabel.Text = 'Start of Subraction';

            % Create StartofSubractionSpinner
            app.StartofSubractionSpinner = uispinner(app.SamplingSettingsPanel);
            app.StartofSubractionSpinner.ValueChangedFcn = createCallbackFcn(app, @StartofSubractionSpinnerValueChanged, true);
            app.StartofSubractionSpinner.Position = [136 42 100 22];

            % Create SumSubwidthSpinnerLabel
            app.SumSubwidthSpinnerLabel = uilabel(app.SamplingSettingsPanel);
            app.SumSubwidthSpinnerLabel.HorizontalAlignment = 'right';
            app.SumSubwidthSpinnerLabel.Position = [35 8 86 22];
            app.SumSubwidthSpinnerLabel.Text = 'Sum/Sub width';

            % Create SumSubwidthSpinner
            app.SumSubwidthSpinner = uispinner(app.SamplingSettingsPanel);
            app.SumSubwidthSpinner.ValueChangedFcn = createCallbackFcn(app, @SumSubwidthSpinnerValueChanged, true);
            app.SumSubwidthSpinner.Position = [136 8 100 22];

            % Create ShutterDelaysEditFieldLabel
            app.ShutterDelaysEditFieldLabel = uilabel(app.SamplingSettingsPanel);
            app.ShutterDelaysEditFieldLabel.HorizontalAlignment = 'right';
            app.ShutterDelaysEditFieldLabel.Position = [25 210 94 22];
            app.ShutterDelaysEditFieldLabel.Text = 'Shutter Delay [s]';

            % Create ShutterDelaysEditField
            app.ShutterDelaysEditField = uieditfield(app.SamplingSettingsPanel, 'numeric');
            app.ShutterDelaysEditField.ValueChangedFcn = createCallbackFcn(app, @ShutterDelaysEditFieldValueChanged, true);
            app.ShutterDelaysEditField.Position = [134 210 100 22];

            % Create FeedbackSettingsPanel
            app.FeedbackSettingsPanel = uipanel(app.SettingsTab);
            app.FeedbackSettingsPanel.Title = 'Feedback Settings';
            app.FeedbackSettingsPanel.Position = [291 375 231 117];

            % Create MaxMWPulsesEditFieldLabel
            app.MaxMWPulsesEditFieldLabel = uilabel(app.FeedbackSettingsPanel);
            app.MaxMWPulsesEditFieldLabel.HorizontalAlignment = 'right';
            app.MaxMWPulsesEditFieldLabel.Position = [7 68 102 22];
            app.MaxMWPulsesEditFieldLabel.Text = 'Max # MW Pulses';

            % Create MaxMWPulsesEditField
            app.MaxMWPulsesEditField = uieditfield(app.FeedbackSettingsPanel, 'numeric');
            app.MaxMWPulsesEditField.ValueChangedFcn = createCallbackFcn(app, @MaxMWPulsesEditFieldValueChanged, true);
            app.MaxMWPulsesEditField.Position = [124 68 100 22];

            % Create TargetSignalEditFieldLabel
            app.TargetSignalEditFieldLabel = uilabel(app.FeedbackSettingsPanel);
            app.TargetSignalEditFieldLabel.HorizontalAlignment = 'right';
            app.TargetSignalEditFieldLabel.Position = [33 37 76 22];
            app.TargetSignalEditFieldLabel.Text = 'Target Signal';

            % Create TargetSignalEditField
            app.TargetSignalEditField = uieditfield(app.FeedbackSettingsPanel, 'numeric');
            app.TargetSignalEditField.ValueChangedFcn = createCallbackFcn(app, @TargetSignalEditFieldValueChanged, true);
            app.TargetSignalEditField.Position = [124 37 100 22];

            % Create SignalToleranceEditFieldLabel
            app.SignalToleranceEditFieldLabel = uilabel(app.FeedbackSettingsPanel);
            app.SignalToleranceEditFieldLabel.HorizontalAlignment = 'right';
            app.SignalToleranceEditFieldLabel.Position = [15 3 94 22];
            app.SignalToleranceEditFieldLabel.Text = 'Signal Tolerance';

            % Create SignalToleranceEditField
            app.SignalToleranceEditField = uieditfield(app.FeedbackSettingsPanel, 'numeric');
            app.SignalToleranceEditField.ValueChangedFcn = createCallbackFcn(app, @SignalToleranceEditFieldValueChanged, true);
            app.SignalToleranceEditField.Position = [124 3 100 22];

            % Create MicrowaveSettingsPanel
            app.MicrowaveSettingsPanel = uipanel(app.SettingsTab);
            app.MicrowaveSettingsPanel.Title = 'Microwave Settings';
            app.MicrowaveSettingsPanel.Position = [291 230 244 122];

            % Create MWPulseWidthsEditFieldLabel
            app.MWPulseWidthsEditFieldLabel = uilabel(app.MicrowaveSettingsPanel);
            app.MWPulseWidthsEditFieldLabel.HorizontalAlignment = 'right';
            app.MWPulseWidthsEditFieldLabel.Position = [12 40 110 22];
            app.MWPulseWidthsEditFieldLabel.Text = 'MW Pulse Width [s]';

            % Create MWPulseWidthsEditField
            app.MWPulseWidthsEditField = uieditfield(app.MicrowaveSettingsPanel, 'numeric');
            app.MWPulseWidthsEditField.ValueChangedFcn = createCallbackFcn(app, @MWPulseWidthsEditFieldValueChanged, true);
            app.MWPulseWidthsEditField.Position = [137 40 100 22];

            % Create MWPulsePeriodsEditFieldLabel
            app.MWPulsePeriodsEditFieldLabel = uilabel(app.MicrowaveSettingsPanel);
            app.MWPulsePeriodsEditFieldLabel.HorizontalAlignment = 'right';
            app.MWPulsePeriodsEditFieldLabel.Position = [8 9 114 22];
            app.MWPulsePeriodsEditFieldLabel.Text = 'MW Pulse Period [s]';

            % Create MWPulsePeriodsEditField
            app.MWPulsePeriodsEditField = uieditfield(app.MicrowaveSettingsPanel, 'numeric');
            app.MWPulsePeriodsEditField.ValueChangedFcn = createCallbackFcn(app, @MWPulsePeriodsEditFieldValueChanged, true);
            app.MWPulsePeriodsEditField.Position = [137 9 100 22];

            % Create ManualMWPulsesSpinnerLabel
            app.ManualMWPulsesSpinnerLabel = uilabel(app.MicrowaveSettingsPanel);
            app.ManualMWPulsesSpinnerLabel.HorizontalAlignment = 'right';
            app.ManualMWPulsesSpinnerLabel.Position = [3 68 119 22];
            app.ManualMWPulsesSpinnerLabel.Text = 'Manual # MW Pulses';

            % Create ManualMWPulsesSpinner
            app.ManualMWPulsesSpinner = uispinner(app.MicrowaveSettingsPanel);
            app.ManualMWPulsesSpinner.ValueChangedFcn = createCallbackFcn(app, @ManualMWPulsesSpinnerValueChanged, true);
            app.ManualMWPulsesSpinner.Position = [137 68 100 22];

            % Create FetchSettingsButton
            app.FetchSettingsButton = uibutton(app.SettingsTab, 'push');
            app.FetchSettingsButton.ButtonPushedFcn = createCallbackFcn(app, @FetchSettingsButtonPushed, true);
            app.FetchSettingsButton.Position = [294 140 100 22];
            app.FetchSettingsButton.Text = 'Fetch Settings';

            % Create UploadSettingsButton
            app.UploadSettingsButton = uibutton(app.SettingsTab, 'push');
            app.UploadSettingsButton.ButtonPushedFcn = createCallbackFcn(app, @UploadSettingsButtonPushed, true);
            app.UploadSettingsButton.Position = [412 140 100 22];
            app.UploadSettingsButton.Text = 'Upload Settings';

            % Create SetDefaultsButton
            app.SetDefaultsButton = uibutton(app.SettingsTab, 'push');
            app.SetDefaultsButton.ButtonPushedFcn = createCallbackFcn(app, @SetDefaultsButtonPushed, true);
            app.SetDefaultsButton.Position = [294 174 100 22];
            app.SetDefaultsButton.Text = 'Set Defaults';

            % Create FetchDataButton
            app.FetchDataButton = uibutton(app.SettingsTab, 'push');
            app.FetchDataButton.ButtonPushedFcn = createCallbackFcn(app, @FetchDataButtonPushed, true);
            app.FetchDataButton.Position = [294 100 100 22];
            app.FetchDataButton.Text = 'Fetch Data';

            % Create ReadonlyPanel
            app.ReadonlyPanel = uipanel(app.SettingsTab);
            app.ReadonlyPanel.Title = 'Read-only';
            app.ReadonlyPanel.Position = [199 504 323 122];

            % Create NumberofSamplesCollectedEditFieldLabel
            app.NumberofSamplesCollectedEditFieldLabel = uilabel(app.ReadonlyPanel);
            app.NumberofSamplesCollectedEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofSamplesCollectedEditFieldLabel.Position = [37 77 165 22];
            app.NumberofSamplesCollectedEditFieldLabel.Text = 'Number of Samples Collected';

            % Create NumberofSamplesCollectedEditField
            app.NumberofSamplesCollectedEditField = uieditfield(app.ReadonlyPanel, 'numeric');
            app.NumberofSamplesCollectedEditField.Position = [217 77 100 22];

            % Create NumberofPulsesCollectedEditFieldLabel
            app.NumberofPulsesCollectedEditFieldLabel = uilabel(app.ReadonlyPanel);
            app.NumberofPulsesCollectedEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofPulsesCollectedEditFieldLabel.Position = [48 42 154 22];
            app.NumberofPulsesCollectedEditFieldLabel.Text = 'Number of Pulses Collected';

            % Create NumberofPulsesCollectedEditField
            app.NumberofPulsesCollectedEditField = uieditfield(app.ReadonlyPanel, 'numeric');
            app.NumberofPulsesCollectedEditField.Position = [217 42 100 22];

            % Create NumberofPowerPulsesCollectedEditFieldLabel
            app.NumberofPowerPulsesCollectedEditFieldLabel = uilabel(app.ReadonlyPanel);
            app.NumberofPowerPulsesCollectedEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofPowerPulsesCollectedEditFieldLabel.Position = [9 10 193 22];
            app.NumberofPowerPulsesCollectedEditFieldLabel.Text = 'Number of Power Pulses Collected';

            % Create NumberofPowerPulsesCollectedEditField
            app.NumberofPowerPulsesCollectedEditField = uieditfield(app.ReadonlyPanel, 'numeric');
            app.NumberofPowerPulsesCollectedEditField.Position = [217 10 100 22];

            % Create ResetButton
            app.ResetButton = uibutton(app.SettingsTab, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.Position = [412 100 100 22];
            app.ResetButton.Text = 'Reset';

            % Create StartButton
            app.StartButton = uibutton(app.SettingsTab, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.Position = [412 174 100 22];
            app.StartButton.Text = 'Start';

            % Create CalculatedValuesPanel
            app.CalculatedValuesPanel = uipanel(app.SettingsTab);
            app.CalculatedValuesPanel.Title = 'Calculated Values';
            app.CalculatedValuesPanel.Position = [534 504 306 122];

            % Create EffectivesamplerateHzEditFieldLabel
            app.EffectivesamplerateHzEditFieldLabel = uilabel(app.CalculatedValuesPanel);
            app.EffectivesamplerateHzEditFieldLabel.HorizontalAlignment = 'right';
            app.EffectivesamplerateHzEditFieldLabel.Position = [38 72 142 22];
            app.EffectivesamplerateHzEditFieldLabel.Text = 'Effective sample rate [Hz]';

            % Create EffectivesamplerateHzEditField
            app.EffectivesamplerateHzEditField = uieditfield(app.CalculatedValuesPanel, 'numeric');
            app.EffectivesamplerateHzEditField.Position = [195 72 100 22];

            % Create SamplesPulseWidthEditFieldLabel
            app.SamplesPulseWidthEditFieldLabel = uilabel(app.CalculatedValuesPanel);
            app.SamplesPulseWidthEditFieldLabel.HorizontalAlignment = 'right';
            app.SamplesPulseWidthEditFieldLabel.Position = [50 43 130 22];
            app.SamplesPulseWidthEditFieldLabel.Text = '# Samples Pulse Width';

            % Create SamplesPulseWidthEditField
            app.SamplesPulseWidthEditField = uieditfield(app.CalculatedValuesPanel, 'numeric');
            app.SamplesPulseWidthEditField.Position = [195 43 100 22];

            % Create SamplesPulsePeriodEditFieldLabel
            app.SamplesPulsePeriodEditFieldLabel = uilabel(app.CalculatedValuesPanel);
            app.SamplesPulsePeriodEditFieldLabel.HorizontalAlignment = 'right';
            app.SamplesPulsePeriodEditFieldLabel.Position = [46 10 134 22];
            app.SamplesPulsePeriodEditFieldLabel.Text = '# Samples Pulse Period';

            % Create SamplesPulsePeriodEditField
            app.SamplesPulsePeriodEditField = uieditfield(app.CalculatedValuesPanel, 'numeric');
            app.SamplesPulsePeriodEditField.Position = [195 10 100 22];

            % Create ManualOutputsPanel
            app.ManualOutputsPanel = uipanel(app.SettingsTab);
            app.ManualOutputsPanel.Title = 'Manual Outputs';
            app.ManualOutputsPanel.Position = [549 307 136 185];

            % Create UseManualValuesButton
            app.UseManualValuesButton = uibutton(app.ManualOutputsPanel, 'state');
            app.UseManualValuesButton.ValueChangedFcn = createCallbackFcn(app, @UseManualValuesButtonValueChanged, true);
            app.UseManualValuesButton.Text = 'Use Manual Values';
            app.UseManualValuesButton.Position = [6 131 119 22];

            % Create DPPulseButton
            app.DPPulseButton = uibutton(app.ManualOutputsPanel, 'state');
            app.DPPulseButton.ValueChangedFcn = createCallbackFcn(app, @DPPulseButtonValueChanged, true);
            app.DPPulseButton.Text = 'DP Pulse';
            app.DPPulseButton.Position = [6 103 100 22];

            % Create ShutterButton
            app.ShutterButton = uibutton(app.ManualOutputsPanel, 'state');
            app.ShutterButton.ValueChangedFcn = createCallbackFcn(app, @ShutterButtonValueChanged, true);
            app.ShutterButton.Text = 'Shutter';
            app.ShutterButton.Position = [6 72 100 22];

            % Create MWPulseButton
            app.MWPulseButton = uibutton(app.ManualOutputsPanel, 'state');
            app.MWPulseButton.ValueChangedFcn = createCallbackFcn(app, @MWPulseButtonValueChanged, true);
            app.MWPulseButton.Text = 'MW Pulse';
            app.MWPulseButton.Position = [6 42 100 22];

            % Create EOMButton
            app.EOMButton = uibutton(app.ManualOutputsPanel, 'state');
            app.EOMButton.ValueChangedFcn = createCallbackFcn(app, @EOMButtonValueChanged, true);
            app.EOMButton.Text = 'EOM';
            app.EOMButton.Position = [6 10 100 22];

            % Create NumberofPulsesSpinnerLabel
            app.NumberofPulsesSpinnerLabel = uilabel(app.SettingsTab);
            app.NumberofPulsesSpinnerLabel.HorizontalAlignment = 'right';
            app.NumberofPulsesSpinnerLabel.Position = [8 379 101 22];
            app.NumberofPulsesSpinnerLabel.Text = 'Number of Pulses';

            % Create NumberofPulsesSpinner
            app.NumberofPulsesSpinner = uispinner(app.SettingsTab);
            app.NumberofPulsesSpinner.ValueChangedFcn = createCallbackFcn(app, @NumberofPulsesSpinnerValueChanged, true);
            app.NumberofPulsesSpinner.Position = [124 379 100 22];

            % Create RawDataTab
            app.RawDataTab = uitab(app.TabGroup);
            app.RawDataTab.Title = 'Raw Data';

            % Create UIAxes
            app.UIAxes = uiaxes(app.RawDataTab);
            title(app.UIAxes, 'Raw I/Q Data')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            app.UIAxes.PlotBoxAspectRatio = [1 0.330061349693252 0.330061349693252];
            app.UIAxes.Position = [0 318 862 324];

            % Create UIAxes4
            app.UIAxes4 = uiaxes(app.RawDataTab);
            title(app.UIAxes4, 'Raw Power Data')
            xlabel(app.UIAxes4, 'X')
            ylabel(app.UIAxes4, 'Y')
            app.UIAxes4.Position = [0 1 862 303];

            % Create SignalTab
            app.SignalTab = uitab(app.TabGroup);
            app.SignalTab.Title = 'Signal';

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.SignalTab);
            title(app.UIAxes2, 'Integrated Data')
            xlabel(app.UIAxes2, 'X')
            ylabel(app.UIAxes2, 'Y')
            app.UIAxes2.Position = [0 1 863 641];

            % Create DisplayPowerButton
            app.DisplayPowerButton = uibutton(app.SignalTab, 'state');
            app.DisplayPowerButton.ValueChangedFcn = createCallbackFcn(app, @DisplayPowerButtonValueChanged, true);
            app.DisplayPowerButton.Text = 'Display Power';
            app.DisplayPowerButton.Position = [750 620 100 22];

            % Create NormalisedDataTab
            app.NormalisedDataTab = uitab(app.TabGroup);
            app.NormalisedDataTab.Title = 'Normalised Data';

            % Create UIAxes3
            app.UIAxes3 = uiaxes(app.NormalisedDataTab);
            title(app.UIAxes3, 'Normalised Data')
            xlabel(app.UIAxes3, 'X')
            ylabel(app.UIAxes3, 'Y')
            app.UIAxes3.Position = [1 1 861 641];
        end
    end

    methods (Access = public)

        % Construct app
        function app = AppFeedbackDP_exported(varargin)

            % Create and configure components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end