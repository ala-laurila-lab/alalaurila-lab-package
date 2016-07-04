classdef AlignmentCross < fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol
    
    properties
        amp                             % Output amplifier
        preTime = 500                   % Cross leading duration (ms)
        stimTime = 500                  % Cross duration (ms)
        tailTime = 0                    % Cross trailing duration (ms)
        intensity = 1.0                 % Cross light intensity (0-1)
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        width = 10                      % Width of the cross in (um)
        length = 200                    % Length of the cross in  (um)
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between spots (s)
        asymmetricShape = false         % Display asymmetric cross
    end
    
    properties (Hidden)
        ampType
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj);
            
            [obj.amp, obj.ampType] = obj.createDeviceNamesProperty('Amp');
        end
        
        function p = getPreview(obj, panel)
            if isempty(obj.rig.getDevices('Stage'))
                p = [];
                return;
            end
            p = io.github.stage_vss.previews.StagePreview(panel, @()obj.createPresentation(), ...
                'windowSize', obj.rig.getDevice('Stage').getCanvasSize());
        end
        
        function prepareRun(obj)
            prepareRun@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('io.github.stage_vss.figures.FrameTimingFigure', obj.rig.getDevice('Stage'));
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            armWidthPix = obj.um2pix(obj.width);
            armLengthPix = obj.um2pix(obj.length);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            if obj.asymmetricShape
                armLengthPix = armLengthPix / 2;
                
                asymmHbar = stage.builtin.stimuli.Rectangle();
                asymmHbar.color = obj.intensity;
                asymmHbar.size = [armWidthPix * .6, armLengthPix];
                asymmHbar.position = [canvasSize(1)/2, canvasSize(1)/2 + armLengthPix / 2];
                p.addStimulus(asymmHbar);
                
                hbar = stage.builtin.stimuli.Rectangle();
                hbar.color = obj.intensity;
                hbar.size = [armWidthPix, armLengthPix];
                hbar.position = [canvasSize(1)/2, canvasSize(2)/2 - armLengthPix / 2];
                p.addStimulus(hbar);
                
                asymmVbar = stage.builtin.stimuli.Rectangle();
                asymmVbar.color = obj.intensity;
                asymmVbar.size = [armLengthPix, armWidthPix * 1.5];
                asymmVbar.position = [canvasSize(1)/2 + armLengthPix / 2, canvasSize(2)/2];
                p.addStimulus(asymmVbar);
                
                vbar = stage.builtin.stimuli.Rectangle();
                vbar.color = obj.intensity;
                vbar.size = [armLengthPix, armWidthPix];
                vbar.position = [canvasSize(1)/2 - armLengthPix / 2, canvasSize(2)/2];
                p.addStimulus(vbar);
            else
                
                hbar = stage.builtin.stimuli.Rectangle();
                hbar.size = [armWidthPix, armLengthPix];
                hbar.color = obj.intensity;
                hbar.position = [canvasSize(1)/2, canvasSize(2)/2];
                p.addStimulus(hbar);
                 
                vbar = stage.builtin.stimuli.Rectangle();
                vbar.size = [armLengthPix, armWidthPix];
                vbar.color = obj.intensity;
                vbar.position = [canvasSize(1)/2, canvasSize(2)/2];
                p.addStimulus(vbar);
            end
            
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj, epoch);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addResponse(device);
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
        
    end
    
end
