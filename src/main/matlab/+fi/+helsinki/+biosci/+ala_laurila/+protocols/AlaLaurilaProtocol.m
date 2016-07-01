classdef (Abstract) AlaLaurilaProtocol < symphonyui.core.Protocol
    
    properties (Dependent, SetAccess = private)
        amp2    % Secondary amplifier one
        amp3    % Secondary amplifier two
        amp4    % Secondary amplifier three
        ndfs    % Selected ndfs. To change ndf press ctrl+D and change for given LED
    end
    
    properties(Hidden)
        ampList = {'amp2', 'amp3', 'amp4'};
    end
    
    methods
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@symphonyui.core.Protocol(obj, name);
            
            if ismember(name, obj.ampList) && isempty(obj.getSecondaryAmp(name))
                d.isHidden = true;
            end
            
            if strncmp(name, 'ndfs', 4) && isempty(obj.ndfs)
                d.isHidden = true;
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@symphonyui.core.Protocol(obj, epoch);
            
            controllers = obj.rig.getDevices('Temperature Controller');
            if ~isempty(controllers)
                epoch.addResponse(controllers{1});
            end
        end
        
        function completeEpoch(obj, epoch)
            completeEpoch@symphonyui.core.Protocol(obj, epoch);
            
            controllers = obj.rig.getDevices('Temperature Controller');
            if ~isempty(controllers) && epoch.hasResponse(controllers{1})
                response = epoch.getResponse(controllers{1});
                [quantities, units] = response.getData();
                if ~strcmp(units, 'V')
                    error('Temperature Controller must be in volts');
                end
                
                % Temperature readout from Warner TC-324B controller 100 mV/degree C.
                temperature = mean(quantities) * 1000 * (1/100);
                temperature = round(temperature * 10) / 10;
                epoch.addParameter('bathTemperature', temperature);
                
                epoch.removeResponse(controllers{1});
            end
        end
        
        function amp = get.amp2(obj)
            amp = obj.getSecondaryAmp('amp2');
        end
        
        function amp = get.amp3(obj)
            amp = obj.getSecondaryAmp('amp3');
        end
        
        function amp = get.amp4(obj)
            amp = obj.getSecondaryAmp('amp4');
        end
        
        function amp = getSecondaryAmp(obj, name)
            ampName = [upper(name(1)) name(2:end)];
            amp = obj.rig.getDeviceNames(ampName);
            if ~ isempty(amp)
                amp = amp{:};
            end
        end
        
        function ndfs = get.ndfs(obj)
            ndfs = obj.getSelectedNdfs();
        end
        
        % default configuration for led device.
        % Can be overridden, if stage is configured for netural density filter
        function ndfs = getSelectedNdfs(obj)
            ndfs = [];
            if ~ isprop(obj, 'led')
                return;
            end
            ledDevice = obj.rig.getDevice(obj.led);
            ndfs = ledDevice.getConfigurationSetting('ndfs');
        end
    end
    
end

