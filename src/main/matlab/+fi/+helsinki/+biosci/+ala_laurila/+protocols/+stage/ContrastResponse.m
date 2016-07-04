classdef ContrastResponse < fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol
    
    properties
        amp                             % Output amplifier
        preTime = 1000                  % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 1000                 % Spot trailing duration (ms)
        contrastNSteps = 5
        minContrast = 0.02
        maxContrast = 1
        contrastDirection = 'positive'
        spotDiameter = 300
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between spots (s)
    end
    
    properties (Hidden)
        ampType
        contrastDirectionType = symphonyui.core.PropertyType('char', 'row', {'both', 'positive', 'negative'})
        contrastValues
        intensityValues
        contrast
        intensity
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
            
            contrasts = 2.^linspace(log2(obj.minContrast), log2(obj.maxContrast), obj.contrastNSteps);
            
            if strcmp(obj.contrastDirection, 'positive')
                obj.contrastValues = contrasts;
            elseif strcmp(obj.contrastDirection, 'negative')
                obj.contrastValues = -1.* contrasts;
            else
                obj.contrastValues =[fliplr(-1.* contrasts), contrasts];
            end
            obj.intensityValues = obj.backgroundIntensity + (obj.contrastValues.* obj.backgroundIntensity);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('io.github.stage_vss.figures.FrameTimingFigure', obj.rig.getDevice('Stage'));
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            spotDiameterPix = obj.um2pix(obj.spotDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.color = obj.intensity;
            spot.radiusX = spotDiameterPix/2;
            spot.radiusY = spotDiameterPix/2;
            spot.position = [canvasSize(1)/2, canvasSize(2)/2];
            p.addStimulus(spot);
            
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'opacity', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj, epoch);
            
            if strcmp(obj.contrastDirection, 'both')
                steps = obj.contrastNSteps * 2;
            else
                steps = obj.contrastNSteps;
            end
            
            index = mod(obj.numEpochsPrepared, steps);
            if  index == 0
                reorder = randperm(length(obj.contrastValues));
                obj.contrastValues = obj.contrastValues(reorder);
                obj.intensityValues = obj.intensityValues(reorder);
            end
            
            obj.contrast = obj.contrastValues(index + 1);
            obj.intensity = obj.intensityValues(index + 1);
            
            device = obj.rig.getDevice(obj.amp);
            duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
            epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            epoch.addParameter('contrast', obj.contrast);
            epoch.addParameter('intensity', obj.intensity);
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

