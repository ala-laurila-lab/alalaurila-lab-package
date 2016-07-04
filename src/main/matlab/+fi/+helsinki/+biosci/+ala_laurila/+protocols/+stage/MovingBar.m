classdef MovingBar < fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol
    
    properties
        amp                             % Output amplifier
        preTime = 250                   % Bar leading duration (ms)
        tailTime = 500                  % Bar trailing duration (ms)
        intensity = 1.0                 % Bar light intensity (0-1)
        barLength = 300                 % Bar length size (um)
        barWidth = 50                   % Bar Width size (um)
        barSpeed = 1000                 % Bar speed (um / s)
        distance = 1000                 % Bar distance (um)
        nAngles = 8                     % Number of angles
        startAngle = 0                  % Start angle for bar direction
        backgroundIntensity = 0.5       % Background light intensity (0-1)
        numberOfAverages = uint16(5)    % Number of epochs
        interpulseInterval = 0          % Duration between spots (s)
    end
    
    properties (Hidden)
        ampType
        angles
    end
    
    properties (Hidden, Dependent)
        curAngle
    end
    
    properties (Dependent)
        stimTime                        % Bar duration (ms)
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
            
            obj.angles = rem(obj.startAngle : round(360/obj.nAngles) : obj.startAngle + 359, 360);
            
            obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.amp));
            obj.showFigure('io.github.stage_vss.figures.FrameTimingFigure', obj.rig.getDevice('Stage'));
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.backgroundIntensity);
            
            bar = stage.builtin.stimuli.Rectangle();
            bar.color = obj.intensity;
            bar.orientation = obj.curAngle;
            bar.size = round([obj.um2pix(obj.barLength), obj.um2pix(obj.barWidth)]);
            p.addStimulus(bar);
            
            pixelSpeed = obj.um2pix(obj.barSpeed);
            xStep = cos(obj.curAngle * pi/180);
            yStep = sin(obj.curAngle * pi/180);
            
            xPos = canvasSize(1)/2 - xStep * canvasSize(2)/2;
            yPos = canvasSize(1)/2 - yStep * canvasSize(2)/2;
            
            function pos = movementController(state, duration)
                pos = [NaN, NaN];
                if (state.time > obj.preTime/1e3 && state.time <= (duration - obj.tailTime)/1e3)
                    pos = [xPos + (state.time - obj.preTime/1e3) * pixelSpeed * xStep,...
                        yPos + (state.time - obj.preTime/1e3) * pixelSpeed* yStep];
                end
            end
            
            barMovement = stage.builtin.controllers.PropertyController(bar, 'position', @(state)movementController(state, p.duration * 1e3));
            p.addController(barMovement);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaStageProtocol(obj, epoch);
            
            % Randomize angles if this is a new set
            if mod(obj.numEpochsPrepared, obj.nAngles) == 0
                obj.angles = obj.angles(randperm(obj.nAngles));
            end
            
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
        
        function angle = get.curAngle(obj)
            angle = obj.angles(mod(obj.numEpochsPrepared, obj.nAngles) + 1);
        end
        
        function stimTime = get.stimTime(obj)
            pixelSpeed = obj.um2pix(obj.barSpeed);
            pixelDistance = obj.um2pix(obj.distance);
            stimTime = round(1e3 * pixelDistance/pixelSpeed);
        end
    end
    
end

