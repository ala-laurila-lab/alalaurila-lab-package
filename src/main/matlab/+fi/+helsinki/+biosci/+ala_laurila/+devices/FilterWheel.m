classdef FilterWheel < symphonyui.core.Device
    
    properties(Access = private)
        config
        currentndf
        interface
    end
    
    properties(Dependent)
        ndf
        identifier
    end
    
    methods
        
        function obj = FilterWheel()
            obj.interface = ComDevice(config.motorized, config.port, 115200, 8, 1, 'CR');
            obj.addConfigurationSetting('ndf-position', config.ndfContainer.keys, 'isReadOnly', true);
            obj.addConfigurationSetting('ndf-values',  config.ndfContainer.values, 'isReadOnly', true);
        end
        
        function str = get.identifier(obj)
            ndf  = obj.ndf;
            if isempty(ndf)
                str = ['NA'];
                return;
            end
            str = strcat(obj.wheelConfig.rigName, ndf);
        end
        
        function ndf = get.ndf(obj)
            ndf = [];
            
            wc = obj.config;
            if  wc.motorized
                ndf = wc.posContainer(obj.getPosition());
            elseif ~isempty(obj.currentndf)
                ndf = obj.currentndf;
            end
        end
        
        function obj = set.ndf(obj, ndf)
            
            if ~isKey(obj.config.ndfContainer, ndf)
                disp(['Error: filter value ' ndf ' not found']);
                return;
            end
            
            obj.currentndf = ndf;
            
            if ~ obj.config.motorized
                return
            end
            
            pos = obj.config.ndfContainer(ndf);
            if pos ~= obj.getPosition()
                obj.setPosition(num2str(pos));
            end
        end
    end
    
    methods(Access = private)
        
        function pos = getPosition(obj)
            pos = str2double(obj.interface.query('pos?\n', 0.2));
        end
        
        function setPosition(obj, pos)
            obj.interface.send(['pos=' pos '\n'], 4);
        end
    end
end