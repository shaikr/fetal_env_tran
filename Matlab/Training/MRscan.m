classdef MRscan < handle
    % MRscan master class that handles all volume scans operations from
    % loading, handeling masks and more sophisticated ( such as brain and
    % normalization )
    properties
        volume                              % the MR scan volume
        path                                % dicom path
        name                                % patient name or number
        date                                % scan date
        time                                % scan tim
        modality                            % scan modality
        defWindow                           % default view window
        
        matlabWindowShift = 1000;           % Matlab window shift
        UID
        registeredToUID
        userdata                            % costum saved user data
        extraData                            % costum saved user data
        metadata                            % contains dicom information
        original_read_all_dicom_vars
        % ROI properties
        masks = cell(1,10);                 % roi maks
        roitexts = cell(1,10);              % roi texts
        clinicaltext = '';                  % clinical text summary
        
    end
    
    properties (Dependent)
        normWindow;
        size;
    end
    
    properties (Access=private)
        normalized_
        skull_
        midline_
        ventricles_
        calcifications_
        brain_
        canonized_
        canonizedBrain_
        
                % the vars for read_all_dicom
    end
    
    methods (Access = private)
        
        function props = getNonPrivateProperties(obj)
            % returns all properties which are not dependant and not private
            propList = ?MRscan;
            propList = propList.PropertyList;
            publicList = strcmpi ( {propList.GetAccess} , 'public' );
            propList = propList(~[propList.Dependent] & publicList);
            props = {propList.Name}; % containt all properties which are not dependant and not private
        end
        
        function obj = readDicom(obj , dirpath , varargin)
            
            [MR , dinfo  ] = read_all_dicom(dirpath, varargin{:});
            
            if ~isTrueColor(MR)
                if strcmpi ( dinfo.Modality ,'MR')
                    obj.volume = cropMR(MR);
                else
                    obj.volume = cropMRI(MR);
                    obj.matlabWindowShift = -1*dinfo.WindowCenter;
                end
            else
                MR = permute(MR, [1 2 4 3]);
                obj.volume = MR;
            end
            obj.metadata = dinfo;
            obj.original_read_all_dicom_vars = varargin;
            obj.path = dirpath;
            if (isfield(dinfo.PatientName, 'GivenName'))
                obj.name = [dinfo.PatientName.GivenName];
            end
            if (isfield(dinfo.PatientName, 'FamilyName'))
                obj.name = [obj.name ' ' dinfo.PatientName.FamilyName];
            end
            obj.date = dinfo.AcquisitionDate;
            obj.time = dinfo.StudyTime;
            if (isfield(dinfo, 'Modality'))
                obj.modality = dinfo.Modality;
            else
                obj.modality = 'Unknown';
            end
            obj.UID = dinfo.SeriesInstanceUID;
            if (isfield(dinfo, 'WindowCenter') && isfield(dinfo, 'WindowWidth'))
                obj.defWindow = [dinfo.WindowCenter (dinfo.WindowWidth+dinfo.WindowCenter)];
                obj.defWindow = obj.defWindow(1,:);
            elseif (isTrueColor(MR))
                obj.defWindow = [0 256];
            end
            obj.registeredToUID = [];
            obj.extraData = struct;
            obj.extraData.coordinates = [];
        end
        
    end
    methods
        
        %% Constructor
        % ----------------------------------------------
        function obj = MRscan(dirpath, varargin)
            if nargin == 0
                % empty ct scan
                return;
            end
            if isMRscan(dirpath)
                % copy all fields other MR scan
                obj = dirpath.clone(varargin);
                return;
            elseif (nargin == 1) && ischar(dirpath) % read specific uid
                obj = loadMRscan(dirpath);
                return;
            elseif isnumeric(dirpath) % first input is volume
                obj.volume = dirpath;
                return;
            elseif ( nargin == 2 ) % TODO micahel .. why?
                return;
            else % read all dicom with varargin
                obj = MRscan();
                obj.readDicom(dirpath , varargin{:});
            end
        end
        
        function MRscanObj = structToMRscan(obj, structMR)
            % builds a ct scan from struct
            obj.volume = structMR.volume;
            obj.original_read_all_dicom_vars = structMR.original_read_all_dicom_vars;
            obj.path = structMR.path;
            obj.name = structMR.name;
            obj.date = structMR.date;
            obj.time = structMR.time;
            obj.modality = structMR.modality;
            obj.defWindow = structMR.defWindow;
            obj.UID = structMR.UID;
            obj.registeredToUID = structMR.registeredToUID;
            obj.extraData = structMR.extraData;
            obj.metadata = structMR.metadata;
            obj.matlabWindowShift = structMR.matlabWindowShift;
            if (isfield(structMR, 'masks'))
                obj.masks = structMR.masks;
                obj.roitexts = structMR.roitexts;
                obj.clinicaltext = structMR.clinicaltext;
            else
                obj.masks = cell(1,10);
                obj.roitexts = cell(1,10);
                obj.clinicaltext = '';
            end
            MRscanObj = obj;
        end
        % ---------------------------------------------------------------------
        
        function normalized = getNormalized(obj)
            % returns a voxel normalized scan. i.e. most times the voxels have a different z-axis resolution. resizes z-volume such
            % that every voxel has the same width, height and depth in mm
            % saves the calcaultion in a "lazy parameter" for fast loading
            if isempty(obj.normalized_)
                if ~isfield( obj.metadata , 'lastSliceInfo' )
                    dinfo.lastSliceInfo = 1;
                end
                obj.normalized_ = normalizePixelSpacing( obj.volume , obj.metadata );
                if obj.metadata.PixelSpacing(1) * size(obj.normalized_,3) > 380
                    warning('Probably Head and neck... removing neck slices'); % TODO remove this for normal ct scan
                    slicesFromTop = round(220 / obj.metadata.PixelSpacing(1));
                    obj.normalized_ = obj.normalized_(:,:,end-slicesFromTop+1:end);
                end
            end
            fprintf('normalized...\n');
            normalized = obj.normalized_;
        end
        
        function vol = getCrop(obj)
            switch lower ( obj.getModality )
                case 'ct'
                    vol = cropMR( obj.volume ) ;
                case { 'mr' ,'mri'}
                    vol = cropMRI( obj.volume ) ;
                otherwise
                    warning('unkown modality for crop, cannot crop');
            end
        end
        
        % constructor ctor
        function newobj = clone(obj, varargin)
            % clones ct scan.
            % newobj = clone( obj, optionString )
            % optionString - (optional, default:none ) can either be 'novolume'  or 'nomasks'
            % if 'novolume' doesnt clone the volume or masks (empty volume)
            % if 'nomasks' copeis volume but doesnt copy masks. useful for
            % a fast "prperties only" cloning
            newobj = MRscan();
            copyvolume = true;
            copymasks = true;
            if ~isempty(varargin) && ~isempty(varargin{1}) && strcmpi ( varargin{1} ,'novolume')
                copyvolume = false;
                copymasks = false;
            end
            if ~isempty(varargin) && ~isempty(varargin{1}) && strcmpi ( varargin{1} ,'nomasks')
                copyvolume = true;
                copymasks = false;
            end
            if copyvolume
                newobj.volume = obj.volume;
            end
            if copymasks
                newobj.masks = obj.masks;
            end
            newobj.name = obj.name;
            newobj.date = obj.date;
            newobj.time = obj.time;
            newobj.modality = obj.modality;
            newobj.defWindow = obj.defWindow;
            newobj.original_read_all_dicom_vars = obj.original_read_all_dicom_vars;
            newobj.path = obj.path;
            newobj.name = obj.name;
            newobj.date = obj.date;
            newobj.time = obj.time;
            newobj.modality = obj.modality;
            newobj.UID = obj.UID;
            newobj.defWindow = obj.defWindow;
            newobj.registeredToUID = obj.registeredToUID;
            newobj.extraData = obj.extraData;
            newobj.roitexts = obj.roitexts;
            newobj.clinicaltext = obj.clinicaltext;
            newobj.metadata = obj.metadata;
        end
        
        function newMRscan = MRscanRegister(MRscanFixed, MRscanMoving)
            % 3d registering for fixed scan to moving scan
            MRfixed = MRscanFixed.getVolume();
            MRmoving = MRscanMoving.getVolume();
            newMR = MRRegister(MRfixed, MRmoving);
            newMRscan = MRscan(MRscanMoving);
            newMRscan.volume = newMR;
            newMRscan.registeredToUID = MRscanFixed.getUID;
        end
        
        
        
        function [] = saveMRscan(obj, path)
            % saves the MR scan in given folder
            if nargin < 2
                path = getFetalFolder('MRscans');
            end
            props = obj.getNonPrivateProperties(); % containt all properties which are not dependant and not private
            
            scanstruct = [];
            for p = 1:numel(props)
                scanstruct.(props{p})=obj.(props{p});
            end
            
            if (isempty(obj.registeredToUID))
                fullName = [path num2str(obj.getUID)];
            end
            save(fullName, '-struct' , 'scanstruct');
        end
        
        function scanVolume = getVolume(obj)
            scanVolume = obj.volume;
        end
        
        function defWindow = getWindow(obj)
            defWindow = obj.defWindow + obj.matlabWindowShift;
        end
        
        function UID = getUID(obj)
            UID = obj.UID;
        end
        
        function scan = getOriginal(obj)
            % re-reads original volume
            [ ~ , spath ] = fileparts ( obj.path  );
            spath = fullfile( getFetalFolder('Data') ,  spath );
            scan = MRscan(spath, obj.original_read_all_dicom_vars{:});
        end
        
        function nameDescription = getName(obj)
            % returns name and description
            nameDescription = [obj.name ' ' obj.date ' ' obj.time '@' obj.UID];
        end
        
        function coarseROI = getCoarseROI( obj ,shouldInterp)
            % makes the roi coarse, a bounding box around the roi in each
            % slice
            roi = obj.redROI;
            if ~exist('shouldInterp' , 'var')
                shouldInterp = false;
            end
            if shouldInterp
                roi = interpolateMask(roi);
            end
            props = regionprops(roi, { 'PixelIdxList' , 'PixelList' , 'BoundingBox' });
            coarseROI = toCoarse(props, size(roi));
        end
        
        % -----------------------------------------------------
        %% Simple getters
        % -----------------------------------------------------
        
        function win = get.normWindow(obj)
            win = obj.defWindow + obj.matlabWindowShift;
        end
        
        function sz = get.size(obj)
            sz = size(obj.getVolume());
        end
        
        % -----------------------------------------------------
        %% Specific operations for brain images
        % -----------------------------------------------------
        function brain = getBrain(obj)
            % returns a mask of the brain area (inside the skull)
            if isempty(obj.brain_)
                obj.brain_ = getBrain( obj.volume );
            end
            brain = obj.brain_;
        end
        
        function skull = getSkull(obj)
            % returns a mask of the skull of the object
            % saves the calcaultion in a "lazy parameter" for fast loading
            if isempty(obj.skull_)
                obj.skull_ = getSkull(obj.volume);
            end
            skull = obj.skull_;
        end
        
        function ventricles = getVentricles(obj)
            % returns a mask of the ventricles
            % saves the calcaultion in a "lazy parameter" for fast loading
            if isempty(obj.ventricles_)
                obj.ventricles_ = findVentricles(obj.volume);
            end
            ventricles = obj.ventricles_;
        end
        
        function calcifications = getCalcifications(obj)
            % returns a mask of the calcifications
            % saves the calcaultion in a "lazy parameter" for fast loading
            if isempty(obj.calcifications_)
                obj.calcifications_ = findCalcifications(obj.volume);
            end
            calcifications = obj.calcifications_;
        end
        
        function canon = getCanonized(obj)
            % returns a mask of the canonized brain
            % saves the calcaultion in a "lazy parameter" for fast loading
            if isempty(obj.canonized_)
                midline = obj.getMidline;
                factor = 2;
                obj.canonized_ = straigtenMR(obj.getNormalized,midline.a,...
                    midline.b, midline.c , factor);
                fprintf('Straightened...\n');
            end
            
            canon = obj.canonized_;
        end
        
        function brain = getCanonizedBrain(obj)
            if isempty(obj.canonizedBrain_)
                obj.canonizedBrain_ = getBrain(obj.getCanonized);
                fprintf('Calculated canonized brain...\n');
            end
            
            brain = obj.canonizedBrain_;
        end
        
        function setCanonizedBrain(obj,brain)
            obj.canonizedBrain_ = brain;
        end
        
        function midline = getMidline(obj)
            % returns midline plane on the normalized scan
            if isempty(obj.midline_)
                mrsr = obj.getNormalized;
                mrsr = imresize3(mrsr , [ .5 .5 .5 ]);
                [ a , b , c ] = getSagittalPlane(mrsr , obj.modality );
                
                obj.midline_.a = a;
                obj.midline_.b = b;
                obj.midline_.c = c;
                fprintf('Got midline..');
            end
            midline = obj.midline_;
        end
        
    end
end





