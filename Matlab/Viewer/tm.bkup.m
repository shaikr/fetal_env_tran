function hF = imagine(varargin)
% IMAGINE IMAGe visualization, analysis and evaluation engINE
%
%   IMAGINE starts the IMAGINE user interface without initial data
%
%   IMAGINE(DATA) Starts the IMAGINE user interface with one (DATA is 3D)
%   or multiple panels (DATA is 4D).
%
%   IMAGINE(DATA, PROPERTY1, VALUE1, ...)) Starts the IMAGINE user
%   interface with data DATA plus supplying some additional information
%   about the dataset in the usual property/value pair format. Possible
%   combinations are:
%       PROPERTY        VALUE
%       'Name'          String: A name for the dataset
%       'Voxelsize'     [3x1] or [1x3] double: The voxel size of the first
%                       three dimensions of DATA.
%       'Units'         String: The physical unit of the pixee.g. 'mm')
%
%   IMAGINE(DATA1, DATA2, ...) Starts the IMAGINE user interface with
%   multiple panels, where each input can be either a 3D- or 4D-array. Each
%   dataset can be defined more detailedly with the properties above.
%
%
% Examples:
%
% 1. >> load mri % Gives variable D
%    >> imagine(squeeze(D)); % squeeze because D is in rgb format
%
% 2. >> load mri % Gives variable D
%    >> imagine(squeeze(D), 'Name', 'Head T1', 'Voxelsize', [1 1 2.7]);
% This syntax gives a more realistic aspect ration if you rotate the data.
%
% For more information about the IMAGINE functions refer to the user's
% guide file in the documentation folder supplied with the code.
%
% Copyright 2012-2015 Christian Wuerslin, Stanford University
% Contact: wuerslin@stanford.edu

% =========================================================================
% Warp Zone! (using Cntl + D)
% -------------------------------------------------------------------------
% *** The callbacks ***
% fCloseGUI                 % On figure close
% fResizeFigure             % On figure resize
% fIconClick                % On clicking menubar or tool icons
% fWindowMouseHoverFcn      % Standard figure mouse move callback
% fWindowButtonDownFcn      % Figure mouse button down function
% fWindowMouseMoveFcn       % Figure mouse move function when button is pressed or ROI drawing active
% fWindowButtonUpFcn        % Figure mouse button up function: Starts most actions
% fKeyPressFcn              % Keyboard callback
% fContextFcn               % Context menu callback
% fSetWindow                % Callback of the colorbars
%
% -------------------------------------------------------------------------
% *** IMAGINE Core ***
% fFillPanels
% fUpdateActivation
% fZoom
% fWindow
% fChangeImage
% fEval
%
% -------------------------------------------------------------------------
% *** Lengthy subfunction ***
% fLoadFiles
% fParseInputs
% fAddImageToData
% fSaveToFiles
%
% -------------------------------------------------------------------------
% *** Helpers ***
% fCreatePanels
% fGetPanel
% fServesSizeCriterion
% fIsOn
% fGetNActiveVisibleSeries
% fGetNVisibleSeries
% fGetImg
% fGetData
% fPrintNumber
% fBackgroundImg
% fReplicate
%
% -------------------------------------------------------------------------
% *** GUIS ***
% fGridSelect
% fColormapSelect
% fSelectEvalFcns
% =========================================================================

% =========================================================================
% *** FUNMRION imagine
% ***
% *** Main GUI function. Creates the figure and all its contents and
% *** registers the callbacks.
% ***
% =========================================================================

% -------------------------------------------------------------------------
% Control the figure's appearance
SAp.sVERSION          = '1.5';
SAp.sTITLE           = ['TailorMed viewer ',SAp.sVERSION];% Title of the figure
SAp.iICONSIZE         = 24;                     % Size if the icons
SAp.iICONPADDING      = SAp.iICONSIZE/2;        % Padding between icons
SAp.iMENUBARHEIGHT    = SAp.iICONSIZE*2;        % Height of the menubar (top)
SAp.iTOOLBARWIDTH     = SAp.iICONSIZE*2;        % Width of the toolbar (left)
SAp.iTITLEBARHEIGHT   = 24;                     % Height of the titles (above each image)
SAp.iCOLORBARHEIGHT   = 12;                     % Height of the colorbar
SAp.iCOLORBARPADDING  = 60;                     % The space on the left and right of the colorbar for the min/max values
SAp.iEVALBARHEIGHT    = 16;                     % Height of the evaluation bar
SAp.iDISABLED_SCALE   = 0.3;                    % Brightness of disabled buttons (decrease to make darker)
SAp.iINAMRIVE_SCALE   = 0.6;                    % Brightness of inactive buttons (toggle buttons and radio groups)
SAp.dBGCOLOR          = [0.15 0.25 0.35];       % Color scheme
SAp.dEmptyImg         = 0;                      % The background image (is calculated in fResizeFigure);
SAp.iCOLORMAPLENGTH   = 2.^12;
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Set some paths.
SPref.sMFILEPATH    = fileparts(mfilename('fullpath'));                 % This is the path of this m-file
SPref.sICONPATH     = [SPref.sMFILEPATH, filesep, 'icons', filesep];    % That's where the icons are
SPref.sSaveFilename = [SPref.sMFILEPATH, filesep, 'imagineSave.mat'];   % A .mat-file to save the GUI settings
% addpath([SPref.sMFILEPATH, filesep, 'EvalFunctions'], ...
%     [SPref.sMFILEPATH, filesep, 'colormaps'], ...
%     [SPref.sMFILEPATH, filesep, 'import'], ...
%     [SPref.sMFILEPATH, filesep, 'tools']);
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Define some preferences
S = load('mylines.mat');
SPref.dCOLORMAP             = S.mylines;% The color scheme of the overlays and lines
SPref.dWINDOWSENSITIVITY    = 0.01;     % Defines mouse sensitivity for windowing operation
SPref.dZOOMSENSITIVITY      = 0.02;     % Defines mouse sensitivity for zooming operation
SPref.dROTATION_THRESHOLD   = 50;       % Defines the number of pixels the cursor has to move to rotate an image
SPref.dLWRADIUS             = 200;      % The radius in which the path maps are calculated in the livewire algorithm
SPref.lGERMANEXPORT         = false;    % Not a beer! Determines whether the data is exported with a period or a comma as decimal point
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% This is the definition of the menubar. If a radiobutton-like
% functionality is to implemented, the GroupIndex parameter of all
% icons within the group has to be set to the same positive integer
% value. Normal Buttons have group index -1, toggel switches have group
% index 0. The toolbar has the GroupIndex 255.
SIcons = struct( ...
    'Name',        {'folder_open',                 'doc_import',          'save', 'doc_delete', 'exchange',          'grid', 'colormap',         'link',          'link1',     'reset',       'phase',                          'max',                          'min',         'record',                    'stop',          'undo',           'clock',           'line1',       'roishow',    'coarse','roierase',       'register',      'cursor_arrow', 'rotate',               'line',  'bio_midline',             'roired',                      'lw',                               'rg',                    'ic',        'tag',      'rotate_sag',   'rotate_axial', 'rotate_coronal' ,     'fast_frame'}, ...
    'Spacer',      {            0,                            0,               0,            0,          1,               0,          0,              0,                0,           1,             0,                              0,                              1,                0,                         0,               0,                 0,                 0,               1,           1,         1,                0,                   0,        0,                    0,              0,                    0,                         0,                                  0,                       0,            0,                 0,                0,                 0,                0}, ...
    'GroupIndex',  {           -1,                           -1,              -1,           -1,         -1,              -1,         -1,              0,                0,          -1,             1,                              1,                              1,               -1,                        -1,              -1,                 0,                 0,               0,           0,         0,                1,                 255,      255,                  255,             -1,                  255,                       255,                                255,                     255,          255,                -1,               -1,                -1,                0}, ...
    'Enabled',     {            1,                            1,               1,            0,          0,               1,          1,              1,                1,           1,             0,                              1,                              0,                0,                         0,               1,                 0,                 0,               1,           1,         1,                0,                   1,        0,                    1,              1,                    1,                         0,                                  0,                       0,            0,                 1,                1,                 1,                1}, ...
    'Active',      {            1,                            1,               1,            1,          1,               1,          1,              1,                0,           1,             0,                              0,                              0,                1,                         1,               1,                 0,                 1,               1,           0,         0,                1,                   1,        0,                    0,              0,                    0,                         0,                                  0,                       1,            1,                 1,                1,                 1,                1}, ...
    'Accelerator', {          'o',                          'i',             's',     'delete',        'x',              '',         '',            'l',               '',         '0',            '',                             '',                             '',               '',                        '',             'z',               't',               'w',              '',          '',       'e',               '',                 'n',      'r',                  'l',             '',                  'r',                        '',                                 '',                     'i',          'p',                '',               '',                '',              'j'}, ...
    'Modifier',    {       'Cntl',                       'Cntl',          'Cntl',           '',     'Cntl',              '',         '',         'Cntl',               '',      'Cntl',            '',                             '',                             '',               '',                        '',          'Cntl',            'Cntl',            'Cntl',              '',          '',        '',               '',                  '',       '',                   '',             '',                   '',                        '',                                 '',                      '',           '',                '',               '',                '',           'Cntl'}, ...
    'Tooltip',     {'Open Files' , 'Import Workspace Variables', 'Save To Files',     'Delete', 'Exchange', 'Change Layout', 'Colormap', 'Link Actions', 'Link Windowing','Reset View', 'Phase Image', 'Maximum Intensity Projection', 'Minimum Intensity Projection', 'Log Evaluation', 'Stop Logging Evaluation',          'Undo', 'Eval Timeseries', 'Show Line Plots',     'Show ROIs','coarse roi',   'erase','Register images',  'Move/Zoom/Window', 'Rotate', 'Profile Evaluation', 'Mark midline', 'RED ROI Evaluation', 'Livewire ROI Evaluation', 'Region Growing Volume Evaluation', 'Isocontour Evaluation', 'Properties',   'Sagittal View',     'Axial View',    'Coronal View', 'Jump 15 frames'});


% hide non enabled SIconss
SIcons = SIcons([SIcons.Enabled]> 0);
% add more biomarker icons
midlineIcon = strcmpi ( {SIcons.Name} ,'bio_midline');
biomarkerList = { 'ventricle' , 'calcification' };
for ci = 1:length(biomarkerList)
    biomarkerIcon = SIcons(midlineIcon);
    biomarkerIcon.Accelerator = '';
    biomarkerIcon.Name = sprintf('bio_%s', biomarkerList{ci});
    biomarkerIcon.Tooltip = sprintf('%s calculation' , biomarkerList{ci});
    SIcons(end+1) = biomarkerIcon;
end

% add more roi icons
roiIcon = strcmpi ( {SIcons.Name} ,'roired');
[ colorList ] = enumeration('maskColor');
for ci = 2:length(colorList)
    color = char(colorList(ci));
    colorIcon = SIcons(roiIcon);
    colorIcon.Accelerator = color(1);
    colorIcon.Name = sprintf('roi%s', color);
    colorIcon.Tooltip = sprintf('%s roi' , color);
    SIcons(end+1) = colorIcon;
end

% -------------------------------------------------------------------------

% ------------------------------------------------------------------------
% Reset the GUI's state variable
SState.iLastSeries     = 0;
SState.noWindow = 0;
SState.savedMask = [];
SState.savedMaskLocation = [];
SState.iStartSeries    = 1;
SState.currentTextWindow = 1;
SState.sTool           = 'cursor_arrow';
SState.sPath           = [SPref.sMFILEPATH, filesep];
SState.csEvalLineFcns  = {};
SState.csEvalROIFcns   = {};
SState.csEvalVolFcns   = {};
SState.sEvalFilename   = [];
SState.iROIState       = 0;     % The ROI state machine
SState.dROILineX       = [];
SState.dROILineY       = [];
SState.iPanels         = [0, 0];
SState.lShowColorbar   = true;
SState.lShowEvalbar    = true;
SState.dColormapBack   = gray(SAp.iCOLORMAPLENGTH);
SState.dColormapMask   = S.mylines;
SState.dMaskOpacity    = .9;
SState.coarseROI       = false;
SState.sDrawMode       = 'mag';
SState.dTolerance      = 1.0;
SState.hEvalFigure     = 0.1;
SState.sliceJump = 1;
% ------------------------------------------------------------------------

% ------------------------------------------------------------------------
% Create some globals
SData                  = [];    % A struct for hoding the data (image data + visualization parameters)
SImg                   = [];    % A struct for the image component handles
SLines                 = [];    % A struct for the line component handles
SMouse                 = [];    % A Struct to hold parameters of the mouse operations
SPanels                = [];    % A Struct to hold the panel data
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Read the preferences from the save file
iPosition = [100 100 1000 600];
if exist(SPref.sSaveFilename, 'file')
    load(SPref.sSaveFilename);
    SState.sPath            = SSaveVar.sPath;
    SState.csEvalLineFcns   = SSaveVar.csEvalLineFcns;
    SState.csEvalROIFcns    = SSaveVar.csEvalROIFcns;
    SState.csEvalVolFcns    = SSaveVar.csEvalVolFcns;
    iPosition               = SSaveVar.iPosition;
    SPref.lGERMANEXPORT     = SSaveVar.lGermanExport;
    clear SSaveVar; % <- no one needs you anymore! :((
else
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    % First-time call: Do some setup
    sAns = questdlg('Do you want to use periods (anglo-american) or commas (german) as decimal separator in the exported .csv spreadsheet files? This is important for a smooth Excel import.', 'IMAGINE First-Time Setup', 'Stick to the point', 'Use se commas', 'Stick to the point');
    SPref.lGERMANEXPORT = strcmp(sAns, 'Use se commas');
    fCompileMex;
    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
end
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Make sure the figure fits on the screen
iScreenSize = get(0, 'ScreenSize');
if (iPosition(1) + iPosition(3) > iScreenSize(3)) || ...
        (iPosition(2) + iPosition(4) > iScreenSize(4))
    iPosition(1:2) = 50;
    iPosition(3:4) = iScreenSize(3:4) - 100;
end
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Create the figure. Mouse scroll wheel is supported since Version 7.4 (I think).
% Create text window here to enable on on the background

hF = figure(...
    'BusyAction'           , 'cancel', ...
    'Interruptible'        , 'off', ...
    'Position'             , iPosition, ...
    'Units'                , 'pixels', ...
    'Color'                , SAp.dBGCOLOR, ...
    'ResizeFcn'            , @fResizeFigure, ...
    'DockControls'         , 'on', ...
    'MenuBar'              , 'none', ...
    'Name'                 , SAp.sTITLE, ...
    'NumberTitle'          , 'off', ...
    'KeyPressFcn'          , @fKeyPressFcn, ...
    'CloseRequestFcn'      , @fCloseGUI, ...
    'WindowButtonDownFcn'  , @fWindowButtonDownFcn, ...
    'WindowButtonMotionFcn', @fWindowMouseHoverFcn, ...
    'WindowScrollWheelFcn' , @fChangeImage);

colormap(gray(256));

try % Try to apply a nice icon
    warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
    jframe = get(hF, 'javaframe');
    jIcon = javax.swing.ImageIcon([SPref.sMFILEPATH, filesep, 'icons', filesep, 'icon.png']);
    pause(0.001);
    jframe.setFigureIcon(jIcon);
    clear jframe jIcon
catch
    warning('IMAGINE: Could not apply a nifty icon to the figure :(');
end



% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Crate context menu for the region growing
measureContextMenu = uicontextmenu;
% uimenu(measureContextMenu, 'Label', '[-] Measure', 'Callback', @rightClickMeasure);
% uimenu(measureContextMenu, 'Label', '[-] Bounding box', 'Callback', @rightClickBBOX);
uimenu(measureContextMenu, 'Label', '[-] Interpolate mask', 'Callback', @rightClickInterpMask);
% uimenu(measureContextMenu, 'Label', '[-] Save mask to workspace', 'Callback', @rightClickSave);
uimenu(measureContextMenu, 'Label', '[-] Delete ROI Connected component', 'Callback', @rightClickDelete);
uimenu(measureContextMenu, 'Label', '[-] Delete full ROI', 'Callback', @rightClickDeleteFullROI);
uimenu(measureContextMenu, 'Label', '[-] Delete roi from slice', 'Callback', @rightClickDeleteSlice);
% uimenu(measureContextMenu, 'Label', '[-] Which mask?(test function)', 'Callback', @rightClickTestMask);

hContextMenu = uicontextmenu;
uimenu(hContextMenu, 'Label', 'Tolerance +50%', 'Callback', @fContextFcn);
uimenu(hContextMenu, 'Label', 'Tolerance +10%', 'Callback', @fContextFcn);
uimenu(hContextMenu, 'Label', 'Tolerance -10%', 'Callback', @fContextFcn);
uimenu(hContextMenu, 'Label', 'Tolerance -50%', 'Callback', @fContextFcn);
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Create the menubar and the toolbar including their components
SPanels.hMenu  = uipanel('Parent', hF, 'BackgroundColor', 'k', 'BorderWidth', 0, 'Units', 'pixels');
SPanels.hTools = uipanel('Parent', hF, 'BackgroundColor', 'k', 'BorderWidth', 0, 'Units', 'pixels');

SAxes.hIcons = zeros(length(SIcons), 1);
SImg .hIcons = zeros(length(SIcons), 1);

iStartPos = SAp.iTOOLBARWIDTH - SAp.iICONSIZE;
for iI = 1:length(SIcons)
    if SIcons(iI).GroupIndex ~= 255, iStartPos = iStartPos + SAp.iICONPADDING + SAp.iICONSIZE; end
    
    dImage = double(imread([SPref.sICONPATH, SIcons(iI).Name, '.png'])); % icon file name (.png) has to be equal to icon name
    if size(dImage, 3) == 1, dImage = repmat(dImage, [1 1 3]); end
    SIcons(iI).dImg = dImage./255;
    
    if SIcons(iI).GroupIndex == 255, hParent = SPanels.hTools; else hParent = SPanels.hMenu; end
    SAxes.hIcons(iI) = axes('Parent', hParent, 'Units', 'pixels', 'Position'  , [iStartPos SAp.iICONPADDING SAp.iICONSIZE SAp.iICONSIZE]);
    SImg.hIcons(iI) = image(SIcons(iI).dImg, 'Parent', SAxes.hIcons(iI),'ButtonDownFcn' , @fIconClick);
    if SIcons(iI).Spacer, iStartPos = iStartPos + SAp.iICONSIZE; end
end
axis(SAxes.hIcons, 'off');
SState.dIconEnd = iStartPos + SAp.iICONPADDING + SAp.iICONSIZE;
% magic();
STexts.hStatus = uicontrol(... % Create the text element
    'Style'                 ,'Text', ...
    'FontName'              , 'Helvetica Neue', ...
    'FontWeight'            , 'light', ...
    'Parent'                , SPanels.hMenu, ...
    'FontUnits'             , 'normalized', ...
    'FontSize'              , 0.7, ...
    'BackgroundColor'       , 'k', ...
    'ForegroundColor'       , 'w', ...
    'HorizontalAlignment'   , 'right', ...
    'Units'                 , 'pixels');

STexts.hStatusDown  = uicontrol(... % Create the text element
    'Style'                 ,'Text', ...
    'FontName'              , 'Helvetica Neue', ...
    'FontWeight'            , 'light', ...
    'Parent'                , SPanels.hMenu, ...
    'FontUnits'             , 'normalized', ...
    'FontSize'              , 0.7, ...
    'BackgroundColor'       , 'k', ...
    'ForegroundColor'       , 'w', ...
    'HorizontalAlignment'   , 'right', ...
    'Units'                 , 'pixels');

clear iStartPos hParent iI dImage
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Parse Inputs and determine and create the initial amount of panels
textWindow = [];
imagesInput = find ( cell2mat ( cellfun ( @(xinput) isnumeric(xinput) || islogical(xinput) , varargin ,'uni' , 0) ) );
inputnames = cell(1,length(imagesInput));
for vi = 1:length(imagesInput)
    inputnames{vi} = inputname(imagesInput(vi));
end
if ~isempty(varargin), fParseInputs(varargin); end
if ~prod(SState.iPanels), SState.iPanels = [1 1]; end
if ~SState.noWindow
    textWindow = imagineTextWindow(@ROIChanged );
    WinOnTop(textWindow);
    updateTextWindow(1);
end

fCreatePanels;



% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Update the figure components
fUpdateActivation(); % Acitvate/deactivate some buttons according to the gui state
fResizeFigure(hF, []); % Call the resize function to allign all the gui elements
set(hF, 'UserData', @fGetData);
drawnow expose


clear varargin; % <- no one needs you anymore! :((
% -------------------------------------------------------------------------
% The 'end' of the IMAGINE main function. The real end is, of course, after
% all the nested functions. Using the nested functions, shared varaiables
% (the variables of the IMAGINE function) can be used which makes the usage
% of the 'guidata' commands obsolete.
% =========================================================================



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fCloseGUI (nested in imagine)
% * *
% * * Figure callback
% * *
% * * Closes the figure and saves the settings
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fCloseGUI(hObject, eventdata) %#ok<*INUSD> eventdata is repeatedly unused
        % -----------------------------------------------------------------
        % Save the settings
        SSaveVar.sPath          = SState.sPath;
        SSaveVar.csEvalLineFcns = SState.csEvalLineFcns;
        SSaveVar.csEvalROIFcns  = SState.csEvalROIFcns;
        SSaveVar.csEvalVolFcns  = SState.csEvalVolFcns;
        SSaveVar.iPosition      = get(hObject, 'Position');
        SSaveVar.lGermanExport  = SPref.lGERMANEXPORT;
        try
            save(SPref.sSaveFilename, 'SSaveVar');
        catch
            warning('Could not save the settings! Is the IMAGINE folder protected?');
        end
        % -----------------------------------------------------------------
        delete(textWindow); % Bye-bye text window
        delete(hObject); % Bye-bye figure
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fCloseGUI
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fResizeFigure (nested in imagine)
% * *
% * * Figure callback
% * *
% * * Re-arranges all the GUI elements after a figure resize
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    function addSagittalPlane()
        
    end

    function fResizeFigure(hObject, eventdata)
        % -----------------------------------------------------------------
        % The resize callback is called very early, therefore we have to check
        % if the GUI elements were already created and return if not
        if ~isfield(SPanels, 'hImgFrame'), return, end
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Get figure dimensions
        dFigureSize   = get(hF, 'Position');
        dFigureWidth  = dFigureSize(3);
        dFigureHeight = dFigureSize(4);
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Arrange the panels and all their contents
        for iM = 1:SState.iPanels(1)
            for iN = 1:SState.iPanels(2)
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % Determine the position of the panel
                iLinInd = (iM - 1).*SState.iPanels(2) + iN;
                dWidth  = round((dFigureWidth  - SAp.iTOOLBARWIDTH) / SState.iPanels(2)) - 1;
                dHeight = round((dFigureHeight - SAp.iMENUBARHEIGHT) / SState.iPanels(1)) - 1;
                dXStart =                 (iN - 1).*(dWidth  + 1) + 2 + SAp.iTOOLBARWIDTH;
                dYStart = (SState.iPanels(1) - iM).*(dHeight + 1) + 2;
                if iN == SState.iPanels(2), dWidth  = dFigureWidth                       - dXStart; end
                if iM == 1                , dHeight = dFigureHeight - SAp.iMENUBARHEIGHT - dYStart; end
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % Arrange the panels
                set(SPanels.hImgFrame(iLinInd),  'Position', [dXStart, dYStart, dWidth, dHeight]);
                dImgYStart = 1 + SState.lShowEvalbar.*SAp.iEVALBARHEIGHT;
                dImgHeight = dHeight - SAp.iTITLEBARHEIGHT - SState.lShowColorbar.*SAp.iCOLORBARHEIGHT - SState.lShowEvalbar.*SAp.iEVALBARHEIGHT;
                set(SPanels.hImg(iLinInd), 'Position', [1, dImgYStart, dWidth, dImgHeight]);
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                set(STexts.hImg1(iLinInd), 'Position', [5,  dHeight - SAp.iTITLEBARHEIGHT + 4, dWidth - 85, SAp.iTITLEBARHEIGHT - 4]);
                set(STexts.hImg2(iLinInd), 'Position', [dWidth - 80, dHeight - SAp.iTITLEBARHEIGHT + 4, 75, SAp.iTITLEBARHEIGHT - 4]);
                
                set(SAxes.hColorbar(iLinInd), 'Position', [SAp.iCOLORBARPADDING, dHeight - SAp.iCOLORBARHEIGHT - SAp.iTITLEBARHEIGHT + 4, max([dWidth - 2*SAp.iCOLORBARPADDING, 1]), SAp.iCOLORBARHEIGHT - 3]);
                set(STexts.hColorbarMin(iLinInd), 'Position', [5, dHeight - SAp.iTITLEBARHEIGHT - SAp.iCOLORBARHEIGHT + 3, SAp.iCOLORBARPADDING - 10, 12]);
                set(STexts.hColorbarMax(iLinInd), 'Position', [dWidth - SAp.iCOLORBARPADDING + 5, dHeight - SAp.iTITLEBARHEIGHT - SAp.iCOLORBARHEIGHT + 3, SAp.iCOLORBARPADDING - 10, 12]);
                
                set(STexts.hEval, 'Position', [5, 2, dWidth - 100, SAp.iEVALBARHEIGHT - 1]);
                set(STexts.hVal,  'Position', [dWidth - 95, 2, 90, SAp.iEVALBARHEIGHT - 1]);
            end
        end
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Arrange the menubar
        dTextWidth = max([dFigureWidth - SState.dIconEnd - 10, 1]);
        set(SPanels.hMenu, 'Position', [1, dFigureHeight - SAp.iMENUBARHEIGHT + 1, dFigureWidth, SAp.iMENUBARHEIGHT]);
        set(STexts.hStatus, 'Position', [SState.dIconEnd + 5, 10, dTextWidth, 28]);
        %         set(STexts.hStatusDown, 'Position', [SState.dIconEnd + 5, 10, dTextWidth, 28]);
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Arrange the toolbar
        set(SPanels.hTools, 'Position', [1, 1, SAp.iTOOLBARWIDTH, dFigureHeight - SAp.iMENUBARHEIGHT]);
        iStartPos = dFigureHeight - SAp.iMENUBARHEIGHT - SAp.iICONPADDING - SAp.iICONSIZE;
        for i = 1:length(SIcons) % Unfortunately we have to rearrange all the icons to keep them on top :(
            if SIcons(i).GroupIndex ~= 255, continue, end
            
            set(SAxes.hIcons(i), 'Position', [SAp.iICONPADDING, iStartPos, SAp.iICONSIZE, SAp.iICONSIZE]);
            iStartPos = iStartPos - SAp.iICONSIZE - SAp.iICONPADDING;
        end
        % -----------------------------------------------------------------
        
        % -------------------------------------------------------------------------
        % Create a beatuiful image for the empty axes
        dWidth  = ceil((dFigureWidth  - SAp.iTOOLBARWIDTH) / SState.iPanels(2));
        dHeight = ceil((dFigureHeight - SAp.iMENUBARHEIGHT) / SState.iPanels(1)) - SAp.iTITLEBARHEIGHT - SAp.iCOLORBARHEIGHT - SAp.iEVALBARHEIGHT;
        SAp.dEmptyImg = fBackgroundImg(dHeight, dWidth);
        % -------------------------------------------------------------------------
        
        fFillPanels;
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fResizeFigure
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fIconClick (nested in imagine)
% * *
% * * Common callback for all buttons in the menubar
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fIconClick(hObject, eventdata)
        % -----------------------------------------------------------------
        % Get the source's (pressed buttton) data and exit if disabled
        iInd = find(SImg.hIcons == hObject);
        if ~SIcons(iInd).Enabled, return, end;
        % -----------------------------------------------------------------
        
        sActivate = [];
        % -----------------------------------------------------------------
        % Distinguish the idfferent button types (normal, toggle, radio)
        switch SIcons(iInd).GroupIndex
            
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            % NORMAL pushbuttons
            case -1
                iconName = SIcons(iInd).Name;
                if strcmpi ( iconName(1:3),'bio')
                    iconName = 'biomarkers';
                end
                switch(iconName)
                    
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    % LOAD new FILES using file dialog
                    case 'folder_open'
                        if strcmp(get(hF, 'SelectionType'), 'normal')
                            %                             [csFilenames, sPath] = uigetfile( ...
                            %                                 {'*.*', 'All Files'; ...
                            %                                 '*.dcm; *.DCM; *.mat; *.MAT; *.jpg; *.jpeg; *.JPG; *.JPEG; *.tif; *.tiff; *.TIF; *.TIFF; *.gif; *.GIF; *.bmp; *.BMP; *.png; *.PNG; *.nii; *.NII; *.gipl; *.GIPL', 'All images'; ...
                            %                                 '*.mat; *.MAT', 'Matlab File (*.mat)'; ...
                            %                                 '*.jpg; *.jpeg; *.JPG; *.JPEG', 'JPEG-Image (*.jpg)'; ...
                            %                                 '*.tif; *.tiff; *.TIF; *.TIFF;', 'TIFF-Image (*.tif)'; ...
                            %                                 '*.gif; *.GIF', 'Gif-Image (*.gif)'; ...
                            %                                 '*.bmp; *.BMP', 'Bitmaps (*.bmp)'; ...
                            %                                 '*.png; *.PNG', 'Portable Network Graphics (*.png)'; ...
                            %                                 '*.dcm; *.DCM', 'DICOM Files (*.dcm)'; ...
                            %                                 '*.nii; *.NII', 'NifTy Files (*.nii)'; ...
                            %                                 '*.gipl; *.GIPL', 'Guys Image Processing Lab Files (*.gipl)'}, ...
                            %                                 'Multiselect'   , 'on');
                            [csFilenames, sPath] = uigetfile( '*.mat');
                            if isnumeric(sPath), return, end;   % Dialog aborted
                        else
                            % Load a folder
                            sPath = uigetdir(SState.sPath);
                            if isnumeric(sPath), return, end;
                            
                            sPath = [sPath, filesep];
                            SFiles = dir(sPath);
                            SFiles = SFiles(~[SFiles.isdir]);
                            csFilenames = cell(length(SFiles), 1);
                            for i = 1:length(SFiles), csFilenames{i} = SFiles(i).name; end
                        end
                        
                        SState.sPath = sPath;
                        fLoadFiles(csFilenames);
                        fFillPanels();
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % IMPORT workspace (base) VARIABLE(S)
                        
                    case 'biomarkers';
                        biomarkerType = SIcons(iInd).Name;
                        biomarkerType = biomarkerType(5:end);
                        addBiomarkers(biomarkerType);
                    case 'doc_import'
                        csVars = fWSImport();
                        if isempty(csVars), return, end   % Dialog aborted
                        
                        for i = 1:length(csVars)
                            dVar = evalin('base', csVars{i});
                            fAddImageToData(dVar, csVars{i}, 'workspace');
                        end
                        fFillPanels();
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % SAVE panel data to file(s)
                    case 'save'
                        % new save : save ct scan
                        iSeriesInd = getActivePanels(); % Get indices of selected axes;
                        if isempty(iSeriesInd)
                            iSeriesInd = 1:length(SData);
                        end
                        for ind = iSeriesInd
                            rotate('axial');
                            cts = SData(ind).cts;
                            %                             cts.volume = SData(ind).dImg;
                            %                             cts.masks = SData(ind).masks;
                            % getting texts by ctscan points
                            sname = sprintf('savedcts%d' , ind);
                            assignin ( 'base' , sname , cts);
                            fprintf('Saved volume in axis %d as %s\n', ind , sname);
                            %                             fprintf('Also resaved ct scan %d as %s\n', ind , sname);
                            cts.saveMRscan();
                            msgbox(gmessage());
                        end
                        % old save : save to files
                        %                         if strcmp(get(hF, 'SelectionType'), 'normal')
                        %                             [sFilename, sPath] = uiputfile( ...
                        %                                 {'*.jpg', 'JPEG-Image (*.jpg)'; ...
                        %                                 '*.tif', 'TIFF-Image (*.tif)'; ...
                        %                                 '*.gif', 'Gif-Image (*.gif)'; ...
                        %                                 '*.bmp', 'Bitmaps (*.bmp)'; ...
                        %                                 '*.png', 'Portable Network Graphics (*.png)'}, ...
                        %                                 'Save selected series to files', ...
                        %                                 [SState.sPath, filesep, '%SeriesName%_%ImageNumber%']);
                        %                             if isnumeric(sPath), return, end;   % Dialog aborted
                        %
                        %                             SState.sPath = sPath;
                        %                             fSaveToFiles(sFilename, sPath);
                        %                         else
                        %                             [sFilename, sPath] = uiputfile( ...
                        %                                 {'*.jpg', 'JPEG-Image (*.jpg)'; ...
                        %                                 '*.tif', 'TIFF-Image (*.tif)'; ...
                        %                                 '*.gif', 'Gif-Image (*.gif)'; ...
                        %                                 '*.bmp', 'Bitmaps (*.bmp)'; ...
                        %                                 '*.png', 'Portable Network Graphics (*.png)'}, ...
                        %                                 'Save MASK of selected series to files', ...
                        %                                 [SState.sPath, filesep, '%SeriesName%_%ImageNumber%_Mask']);
                        %                             if isnumeric(sPath), return, end;   % Dialog aborted
                        %
                        %                             SState.sPath = sPath;
                        %                             fSaveMaskToFiles(sFilename, sPath);
                        %                         end
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % DELETE DATA from structure
                    case 'undo'
                        undoLastMaskOperation();
                        
                    case 'doc_delete'
                        iSeriesInd = getActivePanels(); % Get indices of selected axes
                        iSeriesInd = iSeriesInd(iSeriesInd >= SState.iStartSeries);
                        SData(iSeriesInd) = []; % Delete the visible active data
                        fFillPanels();
                        fUpdateActivation(); % To make sure panels without data are not selected
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % EXCHANGE SERIES
                    case 'exchange'
                        iSeriesInd = getActivePanels(); % Get indices of selected axes
                        SData1 = SData(iSeriesInd(1));
                        SData(iSeriesInd(1)) = SData(iSeriesInd(2)); % Exchange the data
                        SData(iSeriesInd(2)) = SData1;
                        fFillPanels();
                        fUpdateActivation(); % To make sure panels without data are not selected
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % Determine the NUMBER OF PANELS and their LAYOUT
                    case 'grid'
                        iPanels = fGridSelect(4, 4);
                        if ~sum(iPanels), return, end   % Dialog aborted
                        
                        SState.iPanels = iPanels;
                        fCreatePanels; % also updates the SState.iPanels
                        fFillPanels;
                        fUpdateActivation;
                        fResizeFigure(hF, []);
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % Select the COLORMAP
                    case 'colormap'
                        sColormap = fColormapSelect(STexts.hStatus);
                        if ~isempty(sColormap)
                            eval(sprintf('dColormap = %s(SAp.iCOLORMAPLENGTH);', sColormap));
                            SState.dColormapBack = dColormap;
                            fFillPanels;
                            eval(sprintf('colormap(%s(256));', sColormap));
                            set(SPanels.hImg, 'BackgroundColor', dColormap(1,:));
                        end
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % RESET the view (zoom/window/center)
                    case 'reset' % Reset the view properties of all data
                        resetView();
                        
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % RECORD Start recording data
                    case 'record'
                        [sName, sPath] = uiputfile( ...
                            {'*.csv', 'Comma-separated File (*.csv)'}, ...
                            'Chose Logfile', SState.sPath);
                        if isnumeric(sPath)
                            SState.sEvalFilename = '';
                        else
                            SState.sEvalFilename = [sPath, sName];
                        end
                        SState.sPath = sPath;
                        fUpdateActivation;
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % STOP logging data
                    case 'stop'
                        SState.sEvalFilename = '';
                        fUpdateActivation;
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % REWIND last measurement
                    case 'rewind'
                        iPosDel = fGetEvalFilePos;
                        if iPosDel < 0
                            fprintf('File ''%s''does not exist yet or is write-protexted!\n', SState.sEvalFilename);
                            return
                        end
                        
                        if iPosDel == 0
                            fprintf('Log file ''%s'' is empty!\n', SState.sEvalFilename);
                            return
                        end
                        
                        fid = fopen(SState.sEvalFilename, 'r');
                        sLine = fgets(fid);
                        i = 1;
                        lLast = false;
                        while ischar(sLine)
                            csText{i} = sLine;
                            i = i + 1;
                            sLine = fgets(fid);
                            csPos = textscan(sLine, '"%d"');
                            if isempty(csPos{1})
                                iPos = 0;
                            else
                                iPos = csPos{1};
                            end
                            if iPos == iPosDel - 1, lLast = true; end
                            if iPos ~= iPosDel - 1 && lLast, break, end
                        end
                        fclose(fid);
                        iEnd = length(csText);
                        if iPosDel == 1, iEnd = 3; end
                        fid = fopen(SState.sEvalFilename, 'w');
                        for i = 1:iEnd
                            fprintf(fid, '%s', csText{i});
                        end
                        fprintf('Removed entry %d from ''%s''!\n', iPosDel, SState.sEvalFilename);
                        fclose(fid);
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    case 'rotate_sag'
                        rotate('sagittal');
                        
                    case 'rotate_axial'
                        rotate('axial');
                        
                    case 'rotate_coronal'
                        rotate('coronal');
                        
                        
                    otherwise
                end
                % End of NORMAL buttons
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % TOGGLE buttons: Invert the state
            case 0
                
                
                SIcons(iInd).Active = ~SIcons(iInd).Active;
                fUpdateActivation();
                switch(SIcons(iInd).Name)
                    case 'fast_frame'
                        changeSliceJump( 'toggle' );
                    case 'roishow'
                        changeROiShow();
                    case 'coarse'
                        changeROICoarse();
                end
                fFillPanels; % Because of link button
                % End of TOGGLE buttons
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % The render-mode group
            case 1 % The render-mode group
                if ~strcmp(SState.sDrawMode, SIcons(iInd).Name)
                    SState.sDrawMode = SIcons(iInd).Name;
                    sActivate        = SIcons(iInd).Name;
                else
                    SState.sDrawMode = 'mag';
                end
                fFillPanels;
                
            case 255 % The toolbar
                % -   -   -   -   -   -   -   -   -   -   -   -   -
                % Right-click setup menus
                if strcmp(get(hF, 'SelectionType'), 'alt') && ~isfield(eventdata, 'Character')% Right click, open tool settings in neccessary
                    iconName = SIcons(iInd).Name;
                    if strcmpi ( iconName(1:3)  ,'roi')
                        iconName = 'roi';
                    end
                    switch iconName
                        case 'line',
                            csFcns = fSelectEvalFcns(SState.csEvalLineFcns, [SPref.sMFILEPATH, filesep, 'EvalFunctions']);
                            if iscell(csFcns), SState.csEvalLineFcns = csFcns; end
                        case { 'roi' , 'lw' }
                            %                             csFcns = fSelectEvalFcns(SState.csEvalROIFcns, [SPref.sMFILEPATH, filesep, 'EvalFunctions']);
                            %                             if iscell(csFcns), SState.csEvalROIFcns = csFcns; end
                        case 'rg'
                            csFcns = fSelectEvalFcns(SState.csEvalVolFcns, [SPref.sMFILEPATH, filesep, 'EvalFunctions']);
                            if iscell(csFcns), SState.csEvalVolFcns = csFcns; end
                    end
                end
                % -   -   -   -   -   -   -   -   -   -   -   -   -
                
                % -   -   -   -   -   -   -   -   -   -   -   -   -
                if ~strcmp(SState.sTool, SIcons(iInd).Name) % Tool change
                    % Try to delete the lines of the ROI and line eval tools
                    if isfield(SLines, 'hEval')
                        try delete(SLines.hEval); end %#ok<TRYNC>
                        SLines = rmfield(SLines, 'hEval');
                    end
                    
                    % Set tool-specific context menus
                    switch SIcons(iInd).Name
                        %                         case 'rg', set(SPanels.hImg, 'uicontextmenu', hContextMenu);
                        %                         otherwise, set(SPanels.hImg, 'uicontextmenu', []);
                    end
                    
                    % Remove the masks, if a new eval tool is selected
                    %                     switch SIcons(iInd).Name
                    %                         case 'roi'
                    %                             for i = 1:length(SData), SData(i).rMask = []; end
                    %                             fFillPanels;
                    %                     end
                    
                    % -----------------------------------------------------------------
                    % Reset the ROI painting state machine and Mouse callbacks
                    SState.iROIState = 0;
                    set(gcf, 'WindowButtonDownFcn'  , @fWindowButtonDownFcn);
                    set(gcf, 'WindowButtonMotionFcn', @fWindowMouseHoverFcn);
                    set(gcf, 'WindowButtonUpFcn'    , '');
                    % -----------------------------------------------------------------
                end
                SState.sTool = SIcons(iInd).Name;
                sActivate    = SIcons(iInd).Name;
                % -   -   -   -   -   -   -   -   -   -   -   -   -
                
        end
        % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
        
        % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
        % Common code for all radio groups
        if SIcons(iInd).GroupIndex > 0
            for i = 1:length(SIcons)
                if SIcons(i).GroupIndex == SIcons(iInd).GroupIndex
                    SIcons(i).Active = strcmp(SIcons(i).Name, sActivate);
                end
            end
        end
        fUpdateActivation();
        % -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fIconClick
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =




% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fWindowMouseHoverFcn (nested in imagine)
% * *
% * * Figure callback
% * *
% * * The standard mouse move callback. Displays cursor coordinates and
% * * intensity value of corresponding pixel.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function resetView()
        for i = 1:length(SData)
            SData(i).dZoomFactor = 1;
            SData(i).dWindowCenter = mean(SData(i).dDynamicRange);
            SData(i).dWindowWidth = SData(i).dDynamicRange(2) - SData(i).dDynamicRange(1);
            SData(i).dDrawCenter = [0.5 0.5];
            rotate('axial');
        end
        fFillPanels();
    end
    function fWindowMouseHoverFcn(hObject, eventdata)
        if ~isfield(SPanels, 'hImgFrame'), return, end; % Return if called during GUI startup
        
        iAxisInd = fGetPanel();
        if iAxisInd
            % -------------------------------------------------------------
            % Cursor is over a panel -> show coordinates and intensity
            iPos = uint16(get(SAxes.hImg(iAxisInd), 'CurrentPoint')); % Get cursor poition in axis coordinate system
            
            for i = 1:length(SPanels.hImgFrame)
                iSeriesInd = SState.iStartSeries + i - 1;
                if iSeriesInd > length(SData), continue, end
                sz = SData(iSeriesInd).cts.size;
                if iPos(1, 1) > 0 && iPos(1, 2) > 0 && iPos(1, 1) <= sz(2) && iPos(1, 2) <= sz(1)
                    switch SState.sDrawMode
                        case {'mag', 'phase'}
                            dImg = fGetImg(iSeriesInd);
                            dVal = dImg(iPos(1, 2), iPos(1, 1),:);
                        case 'max'
                            %                             if isreal(SData(iSeriesInd).dImg)
                            dVal = max(SData(iSeriesInd).cts.volume(iPos(1, 2), iPos(1, 1), :), [], 3);
                            %                             else
                            %                                 dVal = max(abs(SData(iSeriesInd).dImg(iPos(1, 2), iPos(1, 1), :)), [], 3);
                            %                             end
                        case 'min'
                            %                             if isreal(SData(iSeriesInd).dImg)
                            dVal = min(SData(iSeriesInd).cts.volume(iPos(1, 2), iPos(1, 1), :), [], 3);
                            %                             else
                            %                                 dVal = min(abs(SData(iSeriesInd).dImg(iPos(1, 2), iPos(1, 1), :)), [], 3);
                            %                             end
                    end
                    pos = [ iPos(1, 2), iPos(1, 1) , SData(i).iActiveImage ];
                    
                    if isfield(SData(i) ,'currentRotation') && ~isempty(SData(i).currentRotation)
                        inversePermute = calcInversePermute( SData(i).currentRotation );
                        pos = pos(inversePermute);
                    end
                    
                    if i == iAxisInd,
                        set(STexts.hStatus, 'String', sprintf('MR(%u,%u,%u) = %s', pos,fPrintNumber(dVal)));
                    end
                    set(STexts.hVal(i), 'String', sprintf('%s', fPrintNumber(dVal)));
                else
                    if i == iAxisInd, set(STexts.hStatus, 'String', ''); end
                    set(STexts.hVal(i), 'String', '');
                end
            end
            % -------------------------------------------------------------
        else
            % -------------------------------------------------------------
            % Cursor is not over a panel -> Check if tooltip has to be shown
            iCursorPos = get(hF, 'CurrentPoint');
            iInd = 0;
            for i = 1:length(SAxes.hIcons);
                dPos = get(SAxes.hIcons(i), 'Position');
                dParentPos = get(get(SAxes.hIcons(i), 'Parent'), 'Position');
                dPos(1:2) = dPos(1:2) + dParentPos(1:2);
                if ((iCursorPos(1) >= dPos(1)) && (iCursorPos(1) < dPos(1) + dPos(3)) && ...
                        (iCursorPos(2) >= dPos(2)) && (iCursorPos(2) < dPos(2) + dPos(4)))
                    iInd = i;
                end
            end
            if iInd
                sText = SIcons(iInd).Tooltip;
                sAccelerator = SIcons(iInd).Accelerator;
                if ~isempty(SIcons(iInd).Modifier), sAccelerator = sprintf('%s+%s', SIcons(iInd).Modifier, SIcons(iInd).Accelerator); end
                if ~isempty(SIcons(iInd).Accelerator), sText = sprintf('%s [%s]', sText, sAccelerator); end
                set(STexts.hStatus, 'String', sText);
            else
                set(STexts.hStatus, 'String', '');
            end
            % -------------------------------------------------------------
        end
        
        drawnow expose
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fWindowMouseHoverFcn
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fWindowButtonDownFcn (nested in imagine)
% * *
% * * Figure callback
% * *
% * * Starting callback for mouse button actions.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fWindowButtonDownFcn(hObject, eventdata)
        iAxisInd = fGetPanel();
        %         if strcmpi ( eventdata.Source.SelectionType ,'alt')  % right mouse button
        %
        %         end
        if ~iAxisInd, return, end % Exit if event didn't occurr in a panel
        
        % -----------------------------------------------------------------
        % Save starting parameters
        dPos = get(SAxes.hImg(iAxisInd), 'CurrentPoint');
        SMouse.iStartAxis       = iAxisInd;
        SMouse.iStartPos        = get(hObject, 'CurrentPoint');
        SMouse.dAxesStartPos    = [dPos(1, 1), dPos(1, 2)];
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Backup the display settings of all data
        SMouse.dDrawCenter   = reshape([SData.dDrawCenter], [2, length(SData)]);
        SMouse.dZoomFactor   = [SData.dZoomFactor];
        SMouse.dWindowCenter = [SData.dWindowCenter];
        SMouse.dWindowWidth  = [SData.dWindowWidth];
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Delete existing line objects, clear masks
        if isfield(SLines, 'hEval')
            try delete(SLines.hEval); end %#ok<TRYNC>
            SLines = rmfield(SLines, 'hEval');
        end
        %         switch SState.sTool
        %             case {'line', 'roi', 'lw', 'rg', 'ic'}
        %                 for i = 1:length(SData), SData(i).rMask = []; end
        %                 fFillPanels;
        %         end
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Activate the callbacks for drag operations
        set(hObject, 'WindowButtonUpFcn',     @fWindowButtonUpFcn);
        set(hObject, 'WindowButtonMotionFcn', @fWindowMouseMoveFcn);
        % -----------------------------------------------------------------
        if exist('textWindow' ,'var') && ~isempty(textWindow) && textWindow.isvalid
            linkingFunction = textWindow.UserData;
            [ ~ , ~ , ~ , maskind] = getClickedMask(iAxisInd);
            if ~isempty(maskind)
                linkingFunction.roiClickedFcn(maskind);% chan
            end
        end
        drawnow expose
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fWindowButtonDownFcn
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =


    function [ bw , maskStr ] = getActiveMask(iSeriesInd)
        % returns either clicked mask
        % if no mask is clicked returns first green mask and than red mask
        %
        [ bw , maskStr , ind ] = getClickedMask(iSeriesInd);
        
        if ~isempty(bw)
            return;
        end
        maskStr = 'none';
        for k = 1:length(masks)
            bw = SData(iSeriesInd).cts.masks{k};
            if ~isempty(bw)
                maskStr = maskStrFromId(k);
            end
        end
    end
    function addBiomarkers(biomarkerType)
        
        switch biomarkerType
            case 'midline'
                rotate('axial');
        end
        
        h = waitbar(0,sprintf('calculating biomarker:%s ', biomarkerType));
        for k = 1:length(SData)
            
            % calculate mask according to biomarker type
            switch biomarkerType
                case 'midline'
                    ratio = 2;
                    if isempty(SData(k).cts.metadata)
                        modality = 'MR';
                        ctsr = SData(k).cts.volume;
                    else
                        modality = SData(k).cts.modality;
                        ctsr = SData(k).cts.normalized;
                    end
                    
                    ctsr = imresize3 ( ctsr , ones(1,3)/ratio);
                    [ a , b , c ] = getSagittalPlane(ctsr , modality );
                    sz = SData(k).cts.size;
                    
                    fac = size(SData(k).cts.volume)./size(ctsr);
                    plane = round ( getPlaneXYZ( a.*fac, b.*fac , c.*fac , sz([1 3]) ) );
                    plane = max ( plane , 1 ) ;
                    ind = sub2ind_unsafe( sz , plane(:,:,1) , plane(:,:,2) , plane(:,:,3) ) ;
                    bw = false(sz);
                    bw(ind) = 1;
                case 'ventricle'
                    bw = SData(k).cts.getVentricles;
                case 'calcification'
                    bw = SData(k).cts.getCalcifications;
            end
            emptyMasks = cellfun ( @isempty , SData(k).cts.masks ) ;
            nonEmpty = find ( emptyMasks , 1 , 'first');
            waitbar(.9 , h,sprintf('updating %d mask', nonEmpty));
            SData(k).cts.masks{nonEmpty} = bw;
            SData(k).cts.roitexts{nonEmpty} = sprintf('%s [auto]' , biomarkerType);
        end
        
        close(h);
        fFillPanels;
    end
    function rightClickBBOX(source,callbackdata)
        iSeriesInd = fGetPanel();
        if iSeriesInd
            [ bw , maskStr ] = getClickedMask(iSeriesInd);
            if isempty(bw)
                fprintf('no mask clicked\n');
                return;
            end
            [ x , y , z ] = find3( bw );
            roi = [ min(x) min(y) min(z) ; max(x) max(y) max(z) ];
            if isfield(SData(iSeriesInd) ,'currentRotation') && ~isempty(SData(iSeriesInd).currentRotation)
                inversePermute = calcInversePermute( SData(iSeriesInd).currentRotation );
                roi = roi(:,inversePermute);
            end
            fprintf('%s roi is:[%d:%d,%d:%d,%d:%d], copied to clipboard\n' , maskStr , roi);
            clipboard('copy',sprintf('%d:%d,%d:%d,%d:%d',roi));
        end
    end

    function rightClickTestMask(source,callbackdata)
        iSeriesInd = fGetPanel();
        if ~iSeriesInd
            return;
        end
        [ bw , maskStr ] = getClickedMask(iSeriesInd);
        msgbox(maskStr);
    end
    function rightClickSave(source,callbackdata)
        iSeriesInd = fGetPanel();
        if ~iSeriesInd
            return;
        end
        assignin('base' , 'masks' ,SData(iSeriesInd).cts.masks);
        fprintf('saved "masks" variable to worksapce \n' );
    end
    function rightClickInterpMask(source,callbackdata)
        iSeriesInd = fGetPanel();
        if ~iSeriesInd
            return;
        end
        [ bw , maskStr ] = getClickedMask(iSeriesInd);
        if isempty(bw)
            fprintf('No mask clicked\n');
        else
            bw = interpolateMask(bw);
            maskField = maskIdFromStr(maskStr);
            fprintf('%s mask clicked\n' , maskStr);
            updateMask ( iSeriesInd , maskField , bw ) ;
        end
    end

    function [ bw , maskStr , ind, maskind] = getClickedMask(iSeriesInd)
        maskStr = 'none';
        bw = [];
        maskind = [];
        ind = [];
        iPos = getMousePos(iSeriesInd);
        if isempty(iPos)
            return;
        end
        sub = [iPos(1,2) , iPos(1,1) , SData(iSeriesInd).iActiveImage];
        ind = sub2ind( size( SData(iSeriesInd).cts.volume) , sub(1) , sub(2) , sub(3));
        maskind = nan;
        for k = 1:length(SData(iSeriesInd).cts.masks)
            bw = SData(iSeriesInd).cts.masks{k};
            isInMask = ~isempty(bw) && bw(ind);
            if isInMask
                maskStr = maskStrFromId(k);
                maskind = k;
                break;
            end
        end
        
        if ~isInMask
            maskStr = 'none';
            bw = [];
        end
    end
    function rightClickDeleteSlice(source,callbackdata)
        iSeriesInd = fGetPanel();
        if ~iSeriesInd
            return;
        end
        [ mask , maskStr , ind , maskind] = getClickedMask(iSeriesInd);
        if isempty(mask)
            fprintf('no mask clicked\n');
            return;
        end
        fprintf('deleting %s mask from slice\n' , maskStr);
        
        mask(:,:,SData(iSeriesInd).iActiveImage) = 0;
        updateMask ( iSeriesInd , maskind , mask);
    end

    function rightClickDeleteFullROI(source,callbackdata)
        iSeriesInd = fGetPanel();
        if ~iSeriesInd
            return;
        end
        [ ~ , maskStr , ~ , maskind] = getClickedMask(iSeriesInd);
        if isnan(maskind)
            fprintf('no mask pressed\n' );
            return;
        end
        fprintf('deleting %s mask from scan\n' , maskStr);
        updateMask ( iSeriesInd , maskind , []);
    end

    function rightClickDelete(source,callbackdata)
        iSeriesInd = fGetPanel();
        if ~iSeriesInd
            return;
        end
        [ mask , maskStr , ind , maskind] = getClickedMask(iSeriesInd);
        if isempty(mask)
            fprintf('no mask clicked\n');
            return;
        end
        
        fprintf('deleting %s mask\n' , maskStr);
        CC = bwconncomp(mask);
        correctProp = cell2mat(cellfun ( @(pl) any(pl==ind) , CC.PixelIdxList , 'uni' , 0));
        mask(CC.PixelIdxList{correctProp}) = 0;
        updateMask ( iSeriesInd , maskind , mask);
    end

    function iPos = getMousePos(iSeriesInd)
        iPos = uint16(get(SAxes.hImg(iSeriesInd), 'CurrentPoint')); % Get cursor poition in axis coordinate system
        if iPos(1, 1) > 0 && iPos(1, 2) > 0 && iPos(1, 1) <= size(SData(iSeriesInd).cts.volume, 2) && iPos(1, 2) <= size(SData(iSeriesInd).cts.volume, 1)
            return;
        end
        iPos = [];
    end

    function undoLastMaskOperation()
        % each mask operation save last mask and last mask location
        if isempty(SState.savedMask)
            return;
        end
        loc = SState.savedMaskLocation;
        updateMask ( loc.iSeriesInd , loc.maskInd , SState.savedMask );
    end

    function updateMask ( iSeriesInd , maskInd , mask)
        SState.savedMask = SData(iSeriesInd).cts.masks{maskInd};
        SState.savedMaskLocation.iSeriesInd = iSeriesInd;
        SState.savedMaskLocation.maskInd = maskInd;
        SData(iSeriesInd).cts.masks{maskInd} =  mask ;
        updateTextWindow([],maskInd);
        fFillPanels();
    end

    function rightClickMeasure(source,callbackdata)
        % find red mask
        iSeriesInd = fGetPanel();
        if ~iSeriesInd
            return;
        end
        % -------------------------------------------------------------
        [ bw , maskStr , ind] = getClickedMask(iSeriesInd);
        isInMask = ~isempty(bw);
        if isInMask
            CC = bwconncomp(bw);
            correctProp = cell2mat(cellfun ( @(pl) any(pl==ind) , CC.PixelIdxList , 'uni' , 0));
            area = numel(CC.PixelIdxList{correctProp});
            msgbox(sprintf('Region size in %s mask is %d' ,maskStr, area) ,'Measurement');
        end
        
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fWindowMouseMoveFcn (nested in imagine)
% * *
% * * Figure callback
% * *
% * * Callback for mouse movement while button is pressed.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fWindowMouseMoveFcn(hObject, eventdata)
        iAxesInd = fGetPanel();
        
        % -----------------------------------------------------------------
        % Get some frequently used values
        lLinked   = fIsOn('link'); % Determines whether axes are linked
        iD        = get(hF, 'CurrentPoint') - SMouse.iStartPos; % Mouse distance travelled since button down
        dPanelPos = get(SPanels.hImg(SMouse.iStartAxis), 'Position');
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Tool-specific code
        toolName = SState.sTool;
        if strcmpi ( toolName(1:3) ,'roi')
            toolName = 'roi';
        end
        
        switch toolName
            
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            % The NORMAL CURSOR: select, move, zoom, window
            case 'cursor_arrow'
                switch get(hF, 'SelectionType')
                    
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    % Normal, left mouse button -> MOVE operation
                    case 'normal'
                        dD = double(iD)./dPanelPos(3:4); % Scale mouse movement to panel size (since DrawCenter is a relative value)
                        for i = 1:length(SData)
                            iAxisInd = i - SState.iStartSeries + 1;
                            if ~((lLinked) || (iAxisInd == SMouse.iStartAxis)), continue, end % Skip if axes not linked and current figure not active
                            
                            dNewPos = SMouse.dDrawCenter(:, i)' + dD; % Calculate new draw center relative to saved one
                            SData(i).dDrawCenter = dNewPos; % Save DrawCenter data
                            if iAxisInd < 1 || iAxisInd > length(SPanels.hImg), continue, end % Do not update images outside the figure's scope (will be done with next call of fFillPanels
                            
                            dPos = get(SAxes.hImg(iAxisInd), 'Position');
                            set(SAxes.hImg(iAxisInd), 'Position', [dPanelPos(3)*(dNewPos(1)) - dPos(3)/2, dPanelPos(4)*(dNewPos(2)) - dPos(4)/2, dPos(3), dPos(4)]);
                        end
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % Shift key or right mouse button -> ZOOM operation
                    case 'alt'
                        fZoom(iD, dPanelPos);
                        
                    case 'extend' % Control key or middle mouse button -> WINDOW operation
                        fWindow(iD);
                        
                end
                % end of the NORMAL CURSOR
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % The ROTATION tool
            case 'rotate'
                if ~any(abs(iD) > SPref.dROTATION_THRESHOLD), return, end   % Only proceed if action required
                
                iStartSeries = SMouse.iStartAxis + SState.iStartSeries - 1;
                for i = 1:length(SData)
                    if ~(lLinked || i == iStartSeries || SData(i).iGroupIndex == SData(iStartSeries).iGroupIndex), continue, end % Skip if axes not linked and current figure not active
                    
                    switch get(hObject, 'SelectionType')
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % Normal, left mouse button -> volume rotation operation
                        case 'normal'
                            if iD(1) > SPref.dROTATION_THRESHOLD % Moved mouse to right
                                SData(i).iActiveImage = uint16(SMouse.dAxesStartPos(1, 1));
                                iPermutation = [1 3 2]; iFlipdim = 2;
                            end
                            if iD(1) < -SPref.dROTATION_THRESHOLD % Moved mouse to left , sagittal
                                SData(i).iActiveImage = uint16(size(SData(i).cts.volume, 2) - SMouse.dAxesStartPos(1, 1) + 1);
                                iPermutation = [1 3 2]; iFlipdim = 3;
                            end
                            if iD(2) > SPref.dROTATION_THRESHOLD
                                SData(i).iActiveImage = uint16(size(SData(i).cts.volume, 1) - SMouse.dAxesStartPos(1, 2) + 1);
                                iPermutation = [3 2 1]; iFlipdim = 3;
                            end
                            if iD(2) < -SPref.dROTATION_THRESHOLD
                                SData(i).iActiveImage = uint16(SMouse.dAxesStartPos(1, 2));
                                iPermutation = [3 2 1]; iFlipdim = 1;
                            end
                            
                            % - - - - - - - - - - - - - - - - - - - - - - - - -
                            % Shift key or right mouse button -> rotate in-plane
                        case 'alt'
                            if any(iD > SPref.dROTATION_THRESHOLD)
                                iPermutation = [2 1 3]; iFlipdim = 2;
                            end
                            if any(iD < -SPref.dROTATION_THRESHOLD)
                                iPermutation = [2 1 3]; iFlipdim = 1;
                            end
                            % - - - - - - - - - - - - - - - - - - - - - - - - -
                    end
                    % Switch statement
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    % Apply the transformation
                    SData(i).cts.volume =  flip(permute(SData(i).cts.volume,  iPermutation), iFlipdim);
                    for k = 1:length(SData(i).cts.masks)
                        SData(i).cts.masks{k} = flip(permute(SData(i).cts.masks{k}, iPermutation), iFlipdim);
                    end
                    SData(i).dPixelSpacing = SData(i).dPixelSpacing(iPermutation);
                    set(hObject, 'WindowButtonMotionFcn', @fWindowMouseHoverFcn);
                    
                    % - - - - - - - - - - - - - - - - - - - - - - -
                    % Limit active image range to image dimensions
                    if SData(i).iActiveImage < 1, SData(i).iActiveImage = 1; end
                    if SData(i).iActiveImage > size(SData(i).cts.volume, 3), SData(i).iActiveImage = size(SData(i).cts.volume, 3); end
                end
                % Loop over the data
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                fFillPanels();
                % END of the rotate tool
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % The LINE EVALUATION tool
            case 'line'
                if ~iAxesInd, return, end % Exit if event didn't occurr in a panel
                dPos = get(SAxes.hImg(iAxesInd), 'CurrentPoint');
                if ~isfield(SLines, 'hEval') % Make sure line object exists
                    for i = 1:length(SPanels.hImg)
                        if i + SState.iStartSeries - 1 > length(SData), continue, end
                        SLines.hEval(i) = line([SMouse.dAxesStartPos(1, 1), dPos(1, 1)], [SMouse.dAxesStartPos(1, 2), dPos(1, 2)], ...
                            'Parent'        , SAxes.hImg(i), ...
                            'Color'         , SPref.dCOLORMAP(i,:), ...
                            'LineStyle'     , '-');
                    end
                else
                    lines = arrayfun ( @(sline) isa(sline,'matlab.graphics.primitive.Line') ,SLines.hEval);
                    set(SLines.hEval(lines), 'XData', [SMouse.dAxesStartPos(1, 1), dPos(1, 1)], 'YData', [SMouse.dAxesStartPos(1, 2), dPos(1, 2)]);
                end
                fWindowMouseHoverFcn(hF, []); % Update the position display by triggering the mouse hover callback
                % end of the LINE EVALUATION tool
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % Handle special case of ROI drawing (update the lines), ellipse
            case 'roi'
                if ~iAxesInd || iAxesInd + SState.iStartSeries - 1 > length(SData), return, end
                
                switch SState.iROIState
                    
                    case 0 % No drawing -> Check if one should start an elliplse or rectangle
                        dPos = get(SAxes.hImg(SMouse.iStartAxis), 'CurrentPoint');
                        if sum((dPos(1, 1:2) - SMouse.dAxesStartPos).^2) > 4
                            panels = oneOrAllIfLinked();
                            
                            for i = panels;% getActivePanelsAndPressed() %1:length(SPanels.hImg);
                                if i + SState.iStartSeries - 1 > length(SData), continue, end
                                SLines.hEval(i) = line(dPos(1, 1), dPos(1, 2), ...
                                    'Parent'    , SAxes.hImg(i), ...
                                    'Color'     , SPref.dCOLORMAP(i,:),...
                                    'LineStyle' , '-');
                            end
                            switch(get(hF, 'SelectionType'))
                                case 'normal', SState.iROIState = 2; % -> Rectangle
                                    %                                 case {'alt', 'extend'}, SState.iROIState = 3; % -> Ellipse
                            end
                        end
                        
                    case 1 % Polygon mode
                        dPos = get(SAxes.hImg(iAxesInd), 'CurrentPoint');
                        dROILineX = [SState.dROILineX; dPos(1, 1)]; % Draw a line to the cursor position
                        dROILineY = [SState.dROILineY; dPos(1, 2)];
                        lines = arrayfun ( @(sline) isa(sline,'matlab.graphics.primitive.Line') ,SLines.hEval);
                        set(SLines.hEval(lines), 'XData', dROILineX, 'YData', dROILineY);
                        
                    case 2 % Rectangle mode
                        dPos = get(SAxes.hImg(iAxesInd), 'CurrentPoint');
                        SState.dROILineX = [SMouse.dAxesStartPos(1); SMouse.dAxesStartPos(1); dPos(1, 1); dPos(1, 1); SMouse.dAxesStartPos(1)];
                        SState.dROILineY = [SMouse.dAxesStartPos(2); dPos(1, 2); dPos(1, 2); SMouse.dAxesStartPos(2); SMouse.dAxesStartPos(2)];
                        lines = arrayfun ( @(sline) isa(sline,'matlab.graphics.primitive.Line') ,SLines.hEval);
                        set(SLines.hEval(lines), 'XData', SState.dROILineX, 'YData', SState.dROILineY);
                        
                    case 3 % Ellipse mode
                        dPos = get(SAxes.hImg(iAxesInd), 'CurrentPoint');
                        dDX = dPos(1, 1) - SMouse.dAxesStartPos(1);
                        dDY = dPos(1, 2) - SMouse.dAxesStartPos(2);
                        if strcmp(get(hF, 'SelectionType'), 'extend')
                            dD = max(abs([dDX, dDY]));
                            dDX = sign(dDX).*dD;
                            dDY = sign(dDY).*dD;
                        end
                        dT = linspace(-pi, pi, 100)';
                        SState.dROILineX = SMouse.dAxesStartPos(1) + dDX./2.*(1 + cos(dT));
                        SState.dROILineY = SMouse.dAxesStartPos(2) + dDY./2.*(1 + sin(dT));
                        lines = arrayfun ( @(sline) isa(sline,'matlab.graphics.primitive.Line') ,SLines.hEval);
                        set(SLines.hEval(lines), 'XData', SState.dROILineX, 'YData', SState.dROILineY);
                end
                fWindowMouseHoverFcn(hF, []); % Update the position display by triggering the mouse hover callback
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % Handle special case of GREEN ROI drawing (update the lines), ellipse
            case 'lw'
                if iAxesInd == SMouse.iStartAxis
                    if SState.iROIState == 1 && sum(abs(SState.iPX(:))) > 0 % ROI drawing in progress
                        dPos = get(SAxes.hImg(SMouse.iStartAxis), 'CurrentPoint');
                        [iXPath, iYPath] = fLiveWireGetPath(SState.iPX, SState.iPY, dPos(1, 1), dPos(1, 2));
                        if isempty(iXPath)
                            iXPath = dPos(1, 1);
                            iYPath = dPos(1, 2);
                        end
                        lines = arrayfun ( @(sline) isa(sline,'matlab.graphics.primitive.Line') ,SLines.hEval);
                        set(SLines.hEval(lines), 'XData', [SState.dROILineX; double(iXPath(:))], ...
                            'YData', [SState.dROILineY; double(iYPath(:))]);
                        drawnow expose
                    end
                end
                fWindowMouseHoverFcn(hF, []); % Update the position display by triggering the mouse hover callback
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
            otherwise
                
        end
        % end of the TOOL switch statement
        % -----------------------------------------------------------------
        
        drawnow expose
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fWindowMouseMoveFcn
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    function inversePermute = calcInversePermute( fromPermute )
        inversePermute(fromPermute) = 1:numel(fromPermute);
    end
    function applyRotation ( i , iPermutation  )
        
        % Apply the transformation
        if ~isfield(SData(i) ,'currentRotation') || isempty(SData(i).currentRotation)
            SData(i).currentRotation = [ 1 2 3 ];
        end
        
        if all( SData(i).currentRotation == iPermutation )
            return;
        end
        if any( SData(i).currentRotation ~= [ 1 2 3 ])
            inversePermute = calcInversePermute( SData(i).currentRotation );
            SData(i).cts.volume =  permute(SData(i).cts.volume,  inversePermute);
            for k = 1:length(SData(i).cts.masks)
                SData(i).cts.masks{k} = permute(SData(i).cts.masks{k}, inversePermute);
            end
            SData(i).dPixelSpacing = SData(i).dPixelSpacing(inversePermute);
        end
        SData(i).cts.volume =  permute(SData(i).cts.volume,  iPermutation);
        for k = 1:length(SData(i).cts.masks)
            SData(i).cts.masks{k} = permute(SData(i).cts.masks{k}, iPermutation);
        end
        if ~isempty( SState.savedMask )
            SState.savedMask = permute(SState.savedMask, iPermutation);
        end
        SData(i).dPixelSpacing = SData(i).dPixelSpacing(iPermutation);
        SData(i).currentRotation = iPermutation;
        
        % - - - - - - - - - - - - - - - - - - - - - - -
        % Limit active image range to image dimensions
        SData(i).iActiveImage = uint16 ( size ( SData(i).cts.volume , 3 ) / 2 );
        if SData(i).iActiveImage < 1, SData(i).iActiveImage = 1; end
        if SData(i).iActiveImage > size(SData(i).cts.volume, 3), SData(i).iActiveImage = size(SData(i).cts.volume, 3); end
    end

    function rotate( type )
        switch lower(type)
            case 'sagittal'
                iPermutation = [1 3 2];
            case 'coronal'
                iPermutation = [3 2 1];
            case 'axial'
                iPermutation = [1 2 3];
        end
        for i = 1:length(SData)
            applyRotation( i , iPermutation  );
        end
        fFillPanels;
    end

% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fWindowButtonUpFcn (nested in imagine)
% * *
% * * Figure callback
% * *
% * * End of mouse operations.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fWindowButtonUpFcn(hObject, eventdata)
        iAxisInd = fGetPanel();
        
        iCursorPos = get(hF, 'CurrentPoint');
        % -----------------------------------------------------------------
        % Stop the operation by disabling the corresponding callbacks
        set(hF, 'WindowButtonMotionFcn'    ,@fWindowMouseHoverFcn);
        set(hF, 'WindowButtonUpFcn'        ,'');
        set(STexts.hStatus, 'String', '');
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Tool-specific code
        selectionType = get(hF, 'SelectionType');
        tool = SState.sTool;
        
        if strcmpi ( tool(1:3) , 'roi')
            tool = 'roi';
        end
        if strcmpi ( tool  ,'roi') && any ( strcmpi ( selectionType ,{'alt'})) % if control + roi is clicked, treat as normal button press
            tool = 'cursor_arrow';
        end
        
        if strcmpi(tool,'cursor_arrow')
            
            switch selectionType
                % - - - - - - - - - - - - - - - - - - - - - - - - -
                % NORMAL selection: Select only current series
                case 'normal'
                    
                    iN = fGetNActiveVisibleSeries();
                    for iSeries = 1:length(SData)
                        if SMouse.iStartAxis + SState.iStartSeries - 1 == iSeries
                            SData(iSeries).lActive = ~SData(iSeries).lActive || iN > 1;
                        else
                            SData(iSeries).lActive = false;
                        end
                    end
                    SState.iLastSeries = SMouse.iStartAxis + SState.iStartSeries - 1; % The lastAxis is needed for the shift-click operation
                    selectedAxis = getActivePanelsAndPressed();
                    selectedAxis = selectedAxis(end);
                    if (SState.currentTextWindow ~= selectedAxis)
                        updateTextWindow(selectedAxis); % change to current window
                    end
                    % end of normal selection
                    % - - - - - - - - - - - - - - - - - - - - - - - - -
                    
                    % - - - - - - - - - - - - - - - - - - - - - - - - -
                    %  Shift key or right mouse button: Select ALL axes
                    %  between last selected axis and current axis
                case 'extend'
                    iSeriesInd = SMouse.iStartAxis + SState.iStartSeries - 1;
                    if sum([SData.lActive] == true) == 0
                        % If no panel active, only select the current axis
                        SData(iSeriesInd).lActive = true;
                        SState.iLastSeries = iSeriesInd;
                    else
                        if SState.iLastSeries ~= iSeriesInd
                            iSortedInd = sort([SState.iLastSeries, iSeriesInd], 'ascend');
                            for i = 1:length(SData)
                                SData(i).lActive = (i >= iSortedInd(1)) && (i <= iSortedInd(2));
                            end
                        end
                    end
                    % end of shift key/right mouse button
                    % - - - - - - - - - - - - - - - - - - - - - - - - -
                    
                    % - - - - - - - - - - - - - - - - - - - - - - - - -
                    % Cntl key or middle mouse button: ADD/REMOVE axis
                    % from selection
                case { 'alt' }
                    iSeriesInd = SMouse.iStartAxis + SState.iStartSeries - 1;
                    SData(iSeriesInd).lActive = ~SData(iSeriesInd).lActive;
                    SState.iLastSeries = iSeriesInd;
                    % end of alt/middle mouse buttton
                    % - - - - - - - - - - - - - - - - - - - - - - - - -
                    
            end
            fUpdateActivation();
        end
        
        switch tool
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            % The NORMAL CURSOR: select, move, zoom, window
            % In this function, only the select case has to be handled
            case 'cursor_arrow'
                % end of the NORMAL CURSOR
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % The LINE EVALUATION tool
            case 'line'
                fEval(SState.csEvalLineFcns);
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % End of the LINE EVALUATION tool
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % The ROI EVALUATION tool
            case 'roi'
                set(hF, 'WindowButtonMotionFcn', @fWindowMouseMoveFcn);
                set(hF, 'WindowButtonDownFcn', '');
                set(hF, 'WindowButtonUpFcn', @fWindowButtonUpFcn); % But keep the button up function
                
                if iAxisInd && iAxisInd + SState.iStartSeries - 1 <= length(SData) % ROI drawing in progress
                    dPos = get(SAxes.hImg(iAxisInd), 'CurrentPoint');
                    
                    if SState.iROIState > 1 || any(strcmp({'extend', 'open'}, get(hF, 'SelectionType')))
                        
                        %% Close polygon line - double click (closing)
                        SState.dROILineX = [SState.dROILineX; SState.dROILineX(1)]; % Close line
                        SState.dROILineY = [SState.dROILineY; SState.dROILineY(1)];
                        if isfield(SLines ,'hEval') && ~isempty(SLines.hEval)
                            delete(SLines.hEval);
                        end
                        SState.iROIState = 0;
                        set(hF, 'WindowButtonMotionFcn',@fWindowMouseHoverFcn);
                        set(hF, 'WindowButtonDownFcn', @fWindowButtonDownFcn);
                        set(hF, 'WindowButtonUpFcn', '');
                        fEval(SState.csEvalROIFcns, SState.sTool);
                        
                        %                         activeImageIdx = getActivePanels();
                        %                         if isempty(activeImageIdx)
                        %                             activeImageIdx = 1;
                        %                         end
                        %                         if (length(SData) == 1)
                        %                             activeImageIdx = 1;
                        %                         end
                        %                         activeImage = SData(activeImageIdx);
                        %                         activeImageName = activeImage.sName;
                        %                         poly = [SState.dROILineX SState.dROILineY];
                        %
                        %
                        %                         %                         ROIAns = inputdlg({'ROI title'}, 'ROI define', 1);
                        %                         ROIAns = 'newname';
                        %                         save('MR1-ROI','poly', 'ROIAns');
                        return
                    end
                    
                    switch get(hF, 'SelectionType')
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % NORMAL selection: Add point to roi
                        case 'normal'
                            if ~SState.iROIState % This is the first polygon point
                                SState.dROILineX = dPos(1, 1);
                                SState.dROILineY = dPos(1, 2);
                                panels = oneOrAllIfLinked();
                                for i = panels
                                    if i + SState.iStartSeries - 1 > length(SData), continue, end
                                    %                                     SLines.hEval(i) = line(SState.dROILineX, SState.dROILineY, ...
                                    %                                         'Parent'    , SAxes.hImg(i), ...
                                    %                                         'Color'     , SPref.dCOLORMAP(i,:),...
                                    %                                         'LineStyle' , '-');
                                    SLines.hEval(i) = line(SState.dROILineX, SState.dROILineY, ...
                                        'Parent'    , SAxes.hImg(i), ...
                                        'Color'     , [1 0 0],...
                                        'LineStyle' , '-');
                                end
                                SState.iROIState = 1;
                            else % Add point to existing polygone - here we add them
                                SState.dROILineX = [SState.dROILineX; dPos(1, 1)];
                                SState.dROILineY = [SState.dROILineY; dPos(1, 2)];
                                [rows cols] = getLineInterp(SState.dROILineX, SState.dROILineY);
                                iSeriesInd = fGetPanel();
                                vol = SData(iSeriesInd).cts.getVolume;
                                img = vol(:,:,SData(iSeriesInd).iActiveImage);
                                [newRow, newCol] = findNextPoint(img, rows, cols);
                                maxCount = 20;
                                counter = 0;
                                 while (newRow ~= -1 && counter <= maxCount)
                                    if (pntDist([SState.dROILineX(1) SState.dROILineY(1)],[newCol,newRow]) < 5)
                                        SState.dROILineX = [SState.dROILineX; SState.dROILineX(1)]; % Close line
                                        SState.dROILineY = [SState.dROILineY; SState.dROILineY(1)];
                                        if isfield(SLines ,'hEval') && ~isempty(SLines.hEval)
                                            delete(SLines.hEval);
                                        end
                                        SState.iROIState = 0;
                                        set(hF, 'WindowButtonMotionFcn',@fWindowMouseHoverFcn);
                                        set(hF, 'WindowButtonDownFcn', @fWindowButtonDownFcn);
                                        set(hF, 'WindowButtonUpFcn', '');
                                        fEval(SState.csEvalROIFcns, SState.sTool);
                                        
                                        SData(iSeriesInd).iActiveImage = SData(iSeriesInd).iActiveImage + 1;
                                        fEval(SState.csEvalROIFcns, SState.sTool);
                                        SData(iSeriesInd).iActiveImage = SData(iSeriesInd).iActiveImage - 2;
                                        fEval(SState.csEvalROIFcns, SState.sTool);
                                        fFillPanels;
                                        newROI = getNewROI(SState, vol, SData(iSeriesInd).iActiveImage); 
                                        
                                        return;
                                    else
                                    SState.dROILineX = [SState.dROILineX; newCol];
                                    SState.dROILineY = [SState.dROILineY; newRow];
                                    [rows cols] = getLineInterp(SState.dROILineX, SState.dROILineY);
                                    [newRow, newCol] = findNextPoint(img, rows, cols);
                                    counter = counter + 1;
                                    end
                                end
                                %                                  img = img / max(img(:));
                                %                                  img3 = repmat(img, [1 1 3]);
                                %                                  for m = 1:length(rows)
                                %                                      img3(rows(m), cols(m), 1) = 1;
                                %                                  end
                                %                                  fs(img3)
                                new = [];
                                another = [];
                                %                                  img = SData(iSeriesInd).iActiveImage;
                                lines = arrayfun ( @(sline) isa(sline,'matlab.graphics.primitive.Line') ,SLines.hEval);
                                set(SLines.hEval(lines), 'XData', SState.dROILineX, 'YData', SState.dROILineY);
                            end
                            % End of NORMAL selection
                            % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                            
                            % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                            % Right mouse button/shift key: UNDO last point, quit
                            % if is no point remains
                        case 'alt'
                            if ~SState.iROIState, return, end    % Only perform action if painting in progress
                            
                            if length(SState.dROILineX) > 1
                                SState.dROILineX = SState.dROILineX(1:end-1); % Delete last point
                                SState.dROILineY = SState.dROILineY(1:end-1);
                                dROILineX = [SState.dROILineX; dPos(1, 1)]; % But draw line to current cursor position
                                dROILineY = [SState.dROILineY; dPos(1, 2)];
                                lines = arrayfun ( @(sline) isa(sline,'matlab.graphics.primitive.Line') ,SLines.hEval);
                                set(SLines.hEval(lines), 'XData', dROILineX, 'YData', dROILineY);
                            else % Abort drawing ROI
                                SState.iROIState = 0;
                                delete(SLines.hEval);
                                SLines = rmfield(SLines, 'hEval');
                                set(hF, 'WindowButtonMotionFcn',@fWindowMouseHoverFcn);
                                set(hF, 'WindowButtonDownFcn', @fWindowButtonDownFcn); % Disable the button down function
                            end
                            % End of right click/shift-click
                            % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    end
                end
                % End of the ROI EVALUATION tool
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % livewire
            case 'lw'
                set(hF, 'WindowButtonMotionFcn', @fWindowMouseMoveFcn);
                set(hF, 'WindowButtonDownFcn', '');
                set(hF, 'WindowButtonUpFcn', @fWindowButtonUpFcn); % But keep the button up function
                if iAxisInd ~= SMouse.iStartAxis, return, end
                
                dPos = get(SAxes.hImg(SMouse.iStartAxis), 'CurrentPoint');
                switch get(hF, 'SelectionType')
                    
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    % NORMAL selection: Add point to roi
                    case 'normal'
                        if ~SState.iROIState % This is the first polygon point
                            dImg = SData(SMouse.iStartAxis + SState.iStartSeries - 1).cts.volume(:,:,SData(SMouse.iStartAxis + SState.iStartSeries - 1).iActiveImage);
                            SState.dLWCostFcn = fLiveWireGetCostFcn(dImg);
                            SState.dROILineX = dPos(1, 1);
                            SState.dROILineY = dPos(1, 2);
                            for i = 1:length(SPanels.hImg)
                                if i + SState.iStartSeries - 1 > length(SData), continue, end
                                SLines.hEval(i) = line(SState.dROILineX, SState.dROILineY, ...
                                    'Parent'    , SAxes.hImg(i), ...
                                    'Color'     , SPref.dCOLORMAP(i,:),...
                                    'LineStyle' , '-');
                            end
                            SState.iROIState = 1;
                            SState.iLWAnchorList = zeros(200, 1);
                            SState.iLWAnchorInd  = 0;
                        else % Add point to existing polygone
                            [iXPath, iYPath] = fLiveWireGetPath(SState.iPX, SState.iPY, dPos(1, 1), dPos(1, 2));
                            if isempty(iXPath)
                                iXPath = dPos(1, 1);
                                iYPath = dPos(1, 2);
                            end
                            SState.dROILineX = [SState.dROILineX; double(iXPath(:))];
                            SState.dROILineY = [SState.dROILineY; double(iYPath(:))];
                            set(SLines.hEval, 'XData', SState.dROILineX, 'YData', SState.dROILineY);
                        end
                        SState.iLWAnchorInd = SState.iLWAnchorInd + 1;
                        SState.iLWAnchorList(SState.iLWAnchorInd) = length(SState.dROILineX); % Save the previous path length for the undo operation
                        [SState.iPX, SState.iPY] = fLiveWireCalcP(SState.dLWCostFcn, dPos(1, 1), dPos(1, 2), SPref.dLWRADIUS);
                        % End of NORMAL selection
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        % Right mouse button/shift key: UNDO last point, quit
                        % if is no point remains
                    case 'alt'
                        if SState.iROIState
                            SState.iLWAnchorInd = SState.iLWAnchorInd - 1;
                            if SState.iLWAnchorInd
                                SState.dROILineX = SState.dROILineX(1:SState.iLWAnchorList(SState.iLWAnchorInd)); % Delete last point
                                SState.dROILineY = SState.dROILineY(1:SState.iLWAnchorList(SState.iLWAnchorInd));
                                set(SLines.hEval, 'XData', SState.dROILineX, 'YData', SState.dROILineY);
                                drawnow;
                                [SState.iPX, SState.iPY] = fLiveWireCalcP(SState.dLWCostFcn, SState.dROILineX(end), SState.dROILineY(end), SPref.dLWRADIUS);
                                fWindowMouseMoveFcn(hObject, []);
                            else % Abort drawing ROI
                                SState.iROIState = 0;
                                delete(SLines.hEval);
                                SLines = rmfield(SLines, 'hEval');
                                set(hF, 'WindowButtonMotionFcn',@fWindowMouseHoverFcn);
                                set(hF, 'WindowButtonDownFcn', @fWindowButtonDownFcn);
                            end
                        end
                        % End of right click/shift-click
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                        % Middle mouse button/double-click/cntl-click: CLOSE
                        % POLYGONE and quit roi action
                    case {'extend', 'open'} % Middle mouse button or double-click ->
                        if ~SState.iROIState, return, end    % Only perform action if painting in progress
                        
                        [iXPath, iYPath] = fLiveWireGetPath(SState.iPX, SState.iPY, dPos(1, 1), dPos(1, 2));
                        if isempty(iXPath)
                            iXPath = dPos(1, 1);
                            iYPath = dPos(1, 2);
                        end
                        SState.dROILineX = [SState.dROILineX; double(iXPath(:))];
                        SState.dROILineY = [SState.dROILineY; double(iYPath(:))];
                        
                        [SState.iPX, SState.iPY] = fLiveWireCalcP(SState.dLWCostFcn, dPos(1, 1), dPos(1, 2), SPref.dLWRADIUS);
                        [iXPath, iYPath] = fLiveWireGetPath(SState.iPX, SState.iPY, SState.dROILineX(1), SState.dROILineY(1));
                        if isempty(iXPath)
                            iXPath = SState.dROILineX(1);
                            iYPath = SState.dROILineX(2);
                        end
                        SState.dROILineX = [SState.dROILineX; double(iXPath(:))];
                        SState.dROILineY = [SState.dROILineY; double(iYPath(:))];
                        set(SLines.hEval, 'XData', SState.dROILineX, 'YData', SState.dROILineY);
                        
                        delete(SLines.hEval);
                        SState.iROIState = 0;
                        set(hF, 'WindowButtonMotionFcn',@fWindowMouseHoverFcn);
                        set(hF, 'WindowButtonDownFcn', @fWindowButtonDownFcn);
                        set(hF, 'WindowButtonUpFcn', '');
                        fEval(SState.csEvalROIFcns);
                        
                        % End of middle mouse button/double-click/cntl-click
                        % - - - - - - - - - - - - - - - - - - - - - - - - - - -
                        
                end
                % End of the LIVEWIRE EVALUATION tool
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % The REGION GROWING tool
            case 'rg'
                if ~strcmp(get(hF, 'SelectionType'), 'normal'), return, end; % Otherwise calling the context menu starts a rg
                if ~iAxisInd || iAxisInd > length(SData), return, end;
                
                iSeriesInd = iAxisInd + SState.iStartSeries - 1;
                iSize = size(SData(iSeriesInd).cts.volume);
                dPos = get(SAxes.hImg(iAxisInd), 'CurrentPoint');
                if dPos(1, 1) < 1 || dPos(1, 2) < 1 || dPos(1, 1) > iSize(2) || dPos(1, 2) > iSize(1), return, end
                
                fEval(SState.csEvalVolFcns);
                % End of the REGION GROWING tool
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % The ISOCONTOUR tool
            case 'ic'
                if ~iAxisInd || iAxisInd > length(SData), return, end;
                
                iSeriesInd = iAxisInd + SState.iStartSeries - 1;
                iSize = size(SData(iSeriesInd).cts.volume);
                dPos = get(SAxes.hImg(iAxisInd), 'CurrentPoint');
                if dPos(1, 1) < 1 || dPos(1, 2) < 1 || dPos(1, 1) > iSize(2) || dPos(1, 2) > iSize(1), return, end
                
                fEval(SState.csEvalVolFcns);
                % End of the ISOCONTOUR tool
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % The PROPERTIES tool: Rename the data
            case 'tag'
                if ~iAxisInd || iAxisInd > length(SData), return, end;
                
                iSeriesInd = SState.iStartSeries + iAxisInd - 1;
                csPrompt = {'Name', 'Voxel Size', 'Units'};
                dDim = SData(iSeriesInd).dPixelSpacing;
                sDim = sprintf('%4.2f x ', dDim([2, 1, 3]));
                csVal = {SData(iSeriesInd).sName, sDim(1:end-3), SData(iSeriesInd).sUnits};
                csAns    = inputdlg(csPrompt, sprintf('Change %s', SData(iSeriesInd).sName), 1, csVal);
                if isempty(csAns), return, end
                
                sName = csAns{1};
                iInd = find([SData.iGroupIndex] == SData(iSeriesInd).iGroupIndex);
                if length(iInd) > 1
                    if ~isnan(str2double(sName(end - 1:end))), sName = sName(1:end - 2); end % Crop the number
                end
                dDim = cell2mat(textscan(csAns{2}, '%fx%fx%f'));
                iCnt = 1;
                for i = iInd
                    if length(iInd) > 1
                        SData(i).sName = sprintf('%s%02d', sName, iCnt);
                    else
                        SData(i).sName = sName;
                    end
                    SData(i).dPixelSpacing  = dDim([2, 1, 3]);
                    SData(i).sUnits = csAns{3};
                    iCnt = iCnt + 1;
                end
                fFillPanels;
                % End of the TAG tool
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
        end
        % end of the tool switch-statement
        % -----------------------------------------------------------------
        
        fUpdateActivation();
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fWindowButtonUpFcn
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fKeyPressFcn (nested in imagine)
% * *
% * * Figure callback
% * *
% * * Callback for keyboard actions.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fKeyPressFcn(hObject, eventdata)
        % -----------------------------------------------------------------
        % Bail if only a modifier has been pressed
        switch eventdata.Key
            case {'shift', 'control', 'alt'}, return
        end
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Get the modifier (shift, cntl, alt) keys and determine whether
        % the control key was pressed
        csModifier = eventdata.Modifier;
        sModifier = '';
        for i = 1:length(csModifier)
            if strcmp(csModifier{i}, 'shift'  ), sModifier = 'Shift'; end
            if strcmp(csModifier{i}, 'control'), sModifier = 'Cntl'; end
            if strcmp(csModifier{i}, 'alt'    ), sModifier = 'Alt'; end
        end
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Look for buttons with corresponding accelerators/modifiers
        for i = 1:length(SIcons)
            if strcmp(SIcons(i).Accelerator, eventdata.Key) && ...
                    strcmp(SIcons(i).Modifier, sModifier)
                fIconClick(SImg.hIcons(i), eventdata);
            end
        end
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Functions not implemented by buttons
        switch eventdata.Key
            case {'numpad1', 'leftarrow'} % Image up
                fChangeImage(hObject, -SState.sliceJump);
                
            case {'numpad2', 'rightarrow'} % Image down
                fChangeImage(hObject, SState.sliceJump);
                
            case {'numpad4', 'uparrow'} % Series up
                SState.iStartSeries = max([1 SState.iStartSeries - 1]);
                fFillPanels();
                fUpdateActivation();
                fWindowMouseHoverFcn(hObject, eventdata); % Update the cursor value
                
            case {'numpad5', 'downarrow'} % Series down
                SState.iStartSeries = min([SState.iStartSeries + 1 length(SData)]);
                SState.iStartSeries = max([SState.iStartSeries 1]);
                fFillPanels();
                fUpdateActivation();
                fWindowMouseHoverFcn(hObject, eventdata); % Update the cursor value
                
            case 'space' % Cycle Tools
                iTools = find([SIcons.GroupIndex] == 255 & [SIcons.Enabled]);
                iToolInd = find(strcmp({SIcons.Name}, SState.sTool));
                iToolIndInd = find(iTools == iToolInd);
                iTools = [iTools(end), iTools, iTools(1)];
                if ~strcmp(sModifier, 'Shift'), iToolIndInd = iToolIndInd + 2; end
                iToolInd = iTools(iToolIndInd);
                fIconClick(SImg.hIcons(iToolInd), eventdata);
           
            case '5'
                % brain window
                for k = 1:length(SData)
                    
                    isMR = any2(SData(k).cts.volume > 1200);
                    if isMR;
                        changeWindow( k , 1040 , 1120);
                    end
                end
                
            case 'g'
                if strcmpi ( eventdata.Modifier , 'control' )
                    num = inputdlg('jump to frame:') ;
                    num = str2double(num);
                    jumpToFrame(num);
                end
                
            case 'd'
                SState.dROILineX = SState.dROILineX(1:end-1); % Close line
                SState.dROILineY = SState.dROILineY(1:end-1);
                
            case 'f'
                jump = round(length(SState.dROILineX)/5);
                length(SState.dROILineX)
                SState.dROILineX = SState.dROILineX(1:end-jump); % Close line
                SState.dROILineY = SState.dROILineY(1:end-jump);
            case 'j'
                %                 if strcmpi ( eventdata.Modifier , 'control' )
                %                     changeSliceJump('toggle');
                %                 end
                
            case 's'
                if strcmpi ( eventdata.Modifier , 'alt' )
                    rotate('sagittal');
                end
                
            case 'c'
                if strcmpi ( eventdata.Modifier , 'alt' )
                    rotate('coronal');
                end
                
            case 'a'
                if strcmpi ( eventdata.Modifier , 'alt' )
                    rotate('axial');
                end
        end
        % -----------------------------------------------------------------
        set(hF, 'SelectionType', 'normal');
    end

    function changeWindow( iSeriesInd , dMin , dMax )
        SData(iSeriesInd).dWindowCenter = (dMin + dMax)./2;
        SData(iSeriesInd).dWindowWidth  = (dMax - dMin);
        fFillPanels;
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fKeyPressFcn
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fContextFcn (nested in imagine)
% * *
% * * Menu callback
% * *
% * * Callback for context menu clicks
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fContextFcn(hObject, eventdata)
        switch get(hObject, 'Label')
            case 'Tolerance +50%', SState.dTolerance = SState.dTolerance.*1.5;
            case 'Tolerance +10%', SState.dTolerance = SState.dTolerance.*1.1;
            case 'Tolerance -10%', SState.dTolerance = SState.dTolerance./1.1;
            case 'Tolerance -50%', SState.dTolerance = SState.dTolerance./1.5;
        end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fContextFcn
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fEval (nested in imagine)
% * *
% * * Do the evaluation of line/ROIs
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fEval(csFcns, roitype)
        dPos = get(SAxes.hImg(fGetPanel), 'CurrentPoint');
        
        % -----------------------------------------------------------------
        % Depending on the time series setting, eval only visible or all data
        if fIsOn('clock')
            iSeries = 1:length(SData); % Eval all series
        else
            iSeries = getVisibleSeries();
        end
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Get the rawdata for evaluation and the distance/area/volume
        csSeriesName    = cell(length(iSeries), 1);
        cData           = cell(length(iSeries), 1);
        dMeasures       = zeros(length(iSeries), length(csFcns) + 1);
        csName          = cell(1, length(csFcns) + 1);
        csUnitString    = cell(1, length(csFcns) + 1);
        
        % -----------------------------------------------------------------
        % ROI update Loop
        if strcmpi ( SState.sTool(1:3) , 'roi' )
            serisInds = oneOrAllIfLinked();
            for i = serisInds
                iSeriesInd = iSeries(i);
                csSeriesName{i} = SData(i).sName;
                csName{1} = 'Area';
                csUnitString{1} = sprintf('%s^2', SData(iSeriesInd).sUnits);
                dImg = fGetImg(iSeriesInd);
                rMask = poly2mask(SState.dROILineX, SState.dROILineY, size(dImg, 1), size(dImg, 2));
                dMeasures(i, 1) = nnz(rMask).*SData(iSeriesInd).dPixelSpacing(2).*SData(iSeriesInd).dPixelSpacing(1);
                cData{i} = dImg(rMask);
                if exist('roitype','var')
                    mind = maskIdFromStr(roitype);
                    
                    if isempty(SData(iSeriesInd).cts.masks{mind})
                        SData(iSeriesInd).cts.masks{mind} = false(size(SData(iSeriesInd).cts.volume));
                    end
                    eraseOn  = fIsOn('roierase'); % Determines whether erase mode is active
                    mask = SData(iSeriesInd).cts.masks{mind};
                    if eraseOn
                        mask(:,:,SData(iSeriesInd).iActiveImage) = mask(:,:,SData(iSeriesInd).iActiveImage) & ~rMask;
                    else % add mask
                        mask(:,:,SData(iSeriesInd).iActiveImage) = mask(:,:,SData(iSeriesInd).iActiveImage) | rMask;
                    end
                    updateMask( iSeriesInd , mind , mask ) ;
                end
            end
            fFillPanels;
        end
        
        % -----------------------------------------------------------------
        % Series Loop
        for i = 1:length(iSeries)
            iSeriesInd = iSeries(i);
            csSeriesName{i} = SData(i).sName;
            
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            % Tool dependent code
            switch SState.sTool
                case 'line'
                    dXStart = SMouse.dAxesStartPos(1,1);    dYStart = SMouse.dAxesStartPos(1,2);
                    dXEnd   = dPos(1,1);                    dYEnd = dPos(1,2);
                    dDist = sqrt(((dXStart - dXEnd).*SData(iSeriesInd).dPixelSpacing(2)).^2 + ((dYStart - dYEnd).*SData(iSeriesInd).dPixelSpacing(1)).^2);
                    if dDist < 1.0, return, end % In case of a misclick
                    
                    csName{1} = 'Length';
                    csUnitString{1} = sprintf('%s', SData(iSeriesInd).sUnits);
                    dMeasures(i, 1) = dDist;
                    cData{i}    = improfile(fGetImg(iSeriesInd), [dXStart dXEnd], [dYStart, dYEnd], round(dDist), 'bilinear');
                    
                    
                case 'rg'
                    csName{1} = 'Volume';
                    csUnitString{1} = sprintf('%s^3', SData(iSeriesInd).sUnits);
                    if strcmp(SState.sDrawMode, 'phase')
                        dImg = angle(SData(iSeriesInd).cts.volume);
                    else
                        dImg = SData(iSeriesInd).cts.volume;
                        if ~isreal(dImg), dImg = abs(dImg); end
                    end
                    if i == 1 % In the first series detrmine the tolerance and use the same tolerance in the other series
                        [rMask, dTol] = fRegionGrowingAuto_mex(dImg, int16([dPos(1, 2); dPos(1, 1); SData(iSeriesInd).iActiveImage]), -1, SState.dTolerance);
                    else
                        rMask         = fRegionGrowingAuto_mex(dImg, int16([dPos(1, 2); dPos(1, 1); SData(iSeriesInd).iActiveImage]), dTol);
                    end
                    dMeasures(i, 1) = nnz(rMask).*prod(SData(iSeriesInd).dPixelSpacing);
                    cData{i} = dImg(rMask);
                    SData(iSeriesInd).cts.masks{1} = rMask;
                    fFillPanels;
                    
                case 'ic'
                    csName{1} = 'Volume';
                    csUnitString{1} = sprintf('%s^3', SData(iSeriesInd).sUnits);
                    if strcmp(SState.sDrawMode, 'phase')
                        dImg = angle(SData(iSeriesInd).cts.volume);
                    else
                        dImg = SData(iSeriesInd).cts.volume;
                        if ~isreal(dImg), dImg = abs(dImg); end
                    end
                    rMask = fIsoContour_mex(dImg, int16([dPos(1, 2); dPos(1, 1); SData(iSeriesInd).iActiveImage]), 0.5);
                    dMeasures(i, 1) = nnz(rMask).*prod(SData(iSeriesInd).dPixelSpacing);
                    cData{i} = dImg(rMask);
                    SData(iSeriesInd).cts.masks{1} = rMask;
                    fFillPanels;
                    
            end
            % End of switch SState.sTool
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            % Do the evaluation
            sEvalString = sprintf('%s=%s%s;', csName{1}, num2str(dMeasures(i, 1)), csUnitString{1});
            for iJ = 2:length(csFcns) + 1
                [dMeasures(i, iJ), csName{iJ}, sUnitFormat] = eval([csFcns{iJ - 1}, '(cData{i});']);
                csUnitString{iJ} = sprintf(sUnitFormat, SData(iSeriesInd).sUnits);
                if isempty(csUnitString{iJ}), csUnitString{iJ} = ''; end
                sEvalString = sprintf('%s %s=%s%s;', sEvalString, csName{iJ}, num2str(dMeasures(i, iJ)), csUnitString{iJ});
            end
            SData(iSeriesInd).sEvalText = sEvalString;
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            
        end
        % End of series loop
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Plot the line profile and add name to legend
        % Check for presence of plot figure and create if necessary.
        if (fIsOn('line1') && fIsOn('clock')) || (fIsOn('line1') && ~fIsOn('clock') && strcmp(SState.sTool, 'line'))
            if ~ishandle(SState.hEvalFigure)
                SState.hEvalFigure = figure('Units', 'pixels', 'Position', [100 100 600, 400], 'NumberTitle', 'off');
                axes('Parent', SState.hEvalFigure);
                hold on;
            end
            figure(SState.hEvalFigure);
            hL = findobj(SState.hEvalFigure, 'Type', 'line');
            hAEval = gca;
            delete(hL);
            
            if fIsOn('clock')
                for i = 2:size(dMeasures, 2)
                    plot(dMeasures(:,i), 'Color', SPref.dCOLORMAP(i - 1,:));
                end
                legend(csName{2:end}); % Show legend
                set(SState.hEvalFigure, 'Name', 'Time Series');
                set(get(hAEval, 'XLabel'), 'String', 'Time Point');
                set(get(hAEval, 'YLabel'), 'String', 'Value');
            else
                for i = 1:length(cData);
                    plot(cData{i}, 'Color', SPref.dCOLORMAP(i,:));
                end
                legend(csSeriesName); % Show legend
                set(SState.hEvalFigure, 'Name', 'Line Profile');
                set(get(hAEval, 'XLabel'), 'String', sprintf('x [%s]', SData(SState.iStartSeries).sUnits));
                set(get(hAEval, 'YLabel'), 'String', 'Intensity');
            end
            
        end
        fFillPanels;
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Export to file if enabled
        if isempty(SState.sEvalFilename), return, end
        
        iPos = fGetEvalFilePos;
        if iPos < 0
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            % File does not exist -> Write header
            fid = fopen(SState.sEvalFilename, 'w');
            if fid < 0, warning('IMAGINE: Cannot write to file ''%s''!', SState.sEvalFilename); return, end
            
            if fIsOn('clock')
                fprintf(fid, '\n'); % First line (series names) empty
                fprintf(fid, ['"";"";', fPrintCell('"%s";', csName), '\n']); % The eval function names
                fprintf(fid, ['"";"";', fPrintCell('"%s";', csUnitString), '\n']); % The eval function names
            else
                sFormatString = ['"%s";', repmat('"";', [1, length(csName) - 1])];
                fprintf(fid, ['"";"";', fPrintCell(sFormatString, csSeriesName), '\n']);
                fprintf(fid, ['"";"";', fPrintCell('"%s";', repmat(csName, [1, length(csSeriesName)])), '\n']); % The eval function names
                fprintf(fid, ['"";"";', fPrintCell('"%s";', repmat(csUnitString, [1, length(csSeriesName)])), '\n']); % The eval function names
            end
            
            fclose(fid);
            fprintf('Created file ''%s''!\n', SState.sEvalFilename);
            iPos = 0;
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        end
        
        % ----------------------------------------------------------------
        % Write the measurements to file
        fid = fopen(SState.sEvalFilename, 'a');
        if fid < 0, warning('IMAGINE: Cannot write to file ''%s''!', SState.sEvalFilename); return, end
        
        iPos = iPos + 1;
        if fIsOn('clock')
            fprintf(fid, '\n');
            for i = 1:length(csSeriesName)
                fprintf(fid, '"%d";"%s";', iPos, csSeriesName{i});
                if SPref.lGERMANEXPORT
                    for iJ = 1:size(dMeasures, 2), fprintf(fid, '"%s";', strrep(num2str(dMeasures(i, iJ)), '.', ',')); end
                else
                    for iJ = 1:size(dMeasures, 2), fprintf(fid, '"%s";', num2str(dMeasures(i, iJ))); end
                end
                fprintf(fid, '\n');
            end
        else
            fprintf(fid, '"%d";"";', iPos);
            dMeasures = dMeasures';
            dMeasures = dMeasures(:);
            if SPref.lGERMANEXPORT
                for i = 1:length(dMeasures), fprintf(fid, '"%s";', strrep(num2str(dMeasures(i)), '.', ',')); end
            else
                for i = 1:length(dMeasures), fprintf(fid, '"%s";', num2str(dMeasures(i))); end
            end
            fprintf(fid, '\n');
        end
        
        fclose(fid);
        fprintf('Written to position %d in file ''%s''!\n', iPos, SState.sEvalFilename);
        % -----------------------------------------------------------------
        
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fEval
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    function panels = oneOrAllIfLinked()
        panels = fGetPanel();
        if fIsOn('link');
            panels = getVisibleSeries();
        end
    end
    function iSeries = getVisibleSeries()
        iSeries = 1:length(SData);
        iSeries = iSeries(iSeries >= SState.iStartSeries & iSeries < SState.iStartSeries + length(SPanels.hImg));
    end

    function sString = fPrintCell(sFormatString, csCell)
        sString = '';
        for i = 1:length(csCell);
            sString = sprintf(['%s', sFormatString], sString, csCell{i});
        end
    end

    function iPos = fGetEvalFilePos
        iPos = -1;
        if ~exist(SState.sEvalFilename, 'file'), return, end
        
        fid = fopen(SState.sEvalFilename, 'r');
        if fid < 0, return, end
        
        iPos = 0; i = 1;
        sLine = fgets(fid);
        while ischar(sLine)
            csText{i} = sLine;
            sLine = fgets(fid);
            i = 1 + 1;
        end
        fclose(fid);
        
        csPos = textscan(csText{end}, '"%d"');
        if ~isempty(csPos{1}), iPos = csPos{1}; end
    end



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fChangeImage (nested in imagine)
% * *
% TAILOR MED - updated the image on scroll
% * * Change image index of all series (if linked) or all selected
% * * series.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function jumpToFrame(frame)
        if frame <= 0
            return;
        end
        for k = 1:length(SData)
            SData(k).iActiveImage = frame;
        end
        fFillPanels;
    end

    function changeROiShow()
        isOn = fIsOn('roishow');
        if (isOn)
            SState.dMaskOpacity = .5;
        else
            SState.dMaskOpacity = 0;
        end
    end

    function changeROICoarse()
        isOn = fIsOn('coarse');
        SState.coarseROI = isOn;
    end

    function blinkROI()
        for opacity = .6:-.01:0
            SState.dMaskOpacity = opacity;
            pause(.001);
            fFillPanels;
        end
    end

    function changeSliceJump( newJump )
        if strcmpi(newJump , 'toggle' )
            if SState.sliceJump > 1
                newJump = 1;
            else
                newJump = 15;
            end
        end
        SState.sliceJump = newJump;
    end

    function ROIChanged( hObject , eventdata , handles)
        %         contents = cellstr(get(hObject,'String'));
        %         newCont = get(hObject,'String');
        %         newStr = 'Hemorrhagic infarct - reduction detected';
        %         newCont(2,1:length(newStr)) = newStr;
        %         set (hObject,'String' ,newCont);
        %         disp (   contents{get(hObject,'Value')}  );
        val = get(hObject,'Value');
        if ~isempty(val)
            mslices = [handles.rois(handles.shownMasks).meanSlice];
            sliceJump = mslices ( val ) ;
            jumpToFrame(sliceJump);
        end
    end

    function fChangeImage(hObject, iCnt)
        % -----------------------------------------------------------------
        % Return if projection image selected or ROI drawing in progress
        if strcmp(SState.sDrawMode, 'max') || strcmp(SState.sDrawMode, 'min') || SState.iROIState, return, end
        % -----------------------------------------------------------------
        
        if isstruct(iCnt), iCnt = iCnt.VerticalScrollCount; end % Origin is mouse wheel
        if isobject(iCnt), iCnt = iCnt.VerticalScrollCount; end % Origin is mouse wheel, R2014b
        % -----------------------------------------------------------------
        % Loop over all data (visible or not)
        for iSeriesInd = 1:length(SData)
            if (~fIsOn('link')) && (~SData(iSeriesInd).lActive), continue, end % Skip if axes not linked and current figure not active
            
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            % Calculate new image index and make sure it's not out of bounds
            iNewImgInd = SData(iSeriesInd).iActiveImage + iCnt;
            iNewImgInd = max([iNewImgInd, 1]);
            iNewImgInd = min([iNewImgInd, size(SData(iSeriesInd).cts.volume, 3)]);
            SData(iSeriesInd).iActiveImage = iNewImgInd;
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            % Update corresponding axes if necessary (visible)
            iAxisInd = iSeriesInd - SState.iStartSeries + 1;
            if (iAxisInd) > 0 && (iAxisInd <= length(SPanels.hImgFrame))         % Update Corresponding Axis
                set(STexts.hImg2(iAxisInd), 'String', sprintf('%u/%u', iNewImgInd, size(SData(iSeriesInd).cts.volume, 3)));
            end
        end
        fFillPanels;
        fWindowMouseHoverFcn(hObject, []); % Update the cursor value
        % -----------------------------------------------------------------
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fChangeImage
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fSaveToFiles (nested in imagine)
% * *
% * * Save image data of selected panels to file(s)
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fSaveToFiles(sFilename, sPath)
        
        set(hF, 'Pointer', 'watch'); drawnow
        iNSeries = fGetNVisibleSeries;
        dMin = SData(SState.iStartSeries).dWindowCenter - 0.5.*SData(SState.iStartSeries).dWindowWidth;
        dMax = SData(SState.iStartSeries).dWindowCenter + 0.5.*SData(SState.iStartSeries).dWindowWidth;
        for i = 1:iNSeries
            iSeriesInd = i + SState.iStartSeries - 1;
            if ~fIsOn('link1')
                dMin = SData(iSeriesInd).dWindowCenter - 0.5.*SData(iSeriesInd).dWindowWidth;
                dMax = SData(iSeriesInd).dWindowCenter + 0.5.*SData(iSeriesInd).dWindowWidth;
            end
            if strcmp(SState.sDrawMode, 'phase')
                dMin = -pi;
                dMax =  pi;
            end
            switch SState.sDrawMode
                case {'mag', 'phase'}
                    dImg = zeros(size(SData(iSeriesInd).cts.volume));
                    for iJ = 1:size(SData(iSeriesInd).cts.volume, 3);
                        dImg(:,:,iJ) = fGetImg(iSeriesInd, iJ);
                    end
                case {'min', 'max'}
                    dImg = fGetImg(iSeriesInd);
            end
            dImg = dImg - dMin;
            iImg = uint8(dImg./(dMax - dMin).*255) + 1;
            dImg = reshape(SState.dColormapBack(iImg, :), [size(iImg, 1), size(iImg, 2), size(iImg, 3), 3]);
            dImg = permute(dImg, [1 2 4 3]); % rgb mode
            dImg = dImg.*255;
            dImg(dImg < 0) = 0;
            dImg(dImg > 255) = 255;
            sSeriesFilename = strrep(sFilename, '%SeriesName%', SData(iSeriesInd).sName);
            switch SState.sDrawMode
                case {'mag', 'phase'}
                    hW = waitbar(0, sprintf('Saving Stack ''%s''', SData(iSeriesInd).sName));
                    for iImgInd = 1:size(dImg, 4)
                        sImgFilename = strrep(sSeriesFilename, '%ImageNumber%', sprintf('%03u', iImgInd));
                        imwrite(uint8(dImg(:,:,:,iImgInd)), [sPath, filesep, sImgFilename]);
                        waitbar(iImgInd./size(dImg, 4), hW); drawnow;
                    end
                    close(hW);
                case {'max', 'min'}
                    sImgFilename = strrep(sSeriesFilename, '%ImageNumber%', sprintf('%sProjection', SState.sDrawMode));
                    imwrite(uint8(dImg), [sPath, filesep, sImgFilename]);
            end
            % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            
        end
        set(hF, 'Pointer', 'arrow');
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fSaveToFiles
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fSaveToFiles (nested in imagine)
% * *
% * * Save image data of selected panels to file(s)
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fSaveMaskToFiles(sFilename, sPath)
        
        set(hF, 'Pointer', 'watch'); drawnow
        iNSeries = fGetNVisibleSeries;
        for i = 1:iNSeries
            iSeriesInd = i + SState.iStartSeries - 1;
            lImg = SData(iSeriesInd).cts.masks{1};
            if isempty(lImg), continue, end
            
            rMask = max(max(lImg, [], 1), [], 2);
            dImg = double(lImg);
            switch nnz(rMask)
                case 0, continue % no mask
                    
                case 1 % its a 2D mask
                    iInd = find(rMask);
                    sSeriesFilename = strrep(sFilename, '%SeriesName%', SData(iSeriesInd).sName);
                    sImgFilename = strrep(sSeriesFilename, '%ImageNumber%', sprintf('%03d', iInd));
                    imwrite(dImg(:,:,iInd), [sPath, filesep, sImgFilename]);
                otherwise
                    sSeriesFilename = strrep(sFilename, '%SeriesName%', SData(iSeriesInd).sName);
                    for iInd = 1:size(dImg, 3)
                        sImgFilename = strrep(sSeriesFilename, '%ImageNumber%', sprintf('%03d', iInd));
                        imwrite(dImg(:,:,iInd), [sPath, filesep, sImgFilename]);
                    end
            end
        end
        set(hF, 'Pointer', 'arrow');
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fSaveToFiles
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =


% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fFillPanels (nested in imagine)
% * *
% * * Display the current data in all panels.
% * * The holy grail of Imagine!
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fFillPanels
        
        for i = 1:length(SPanels.hImgFrame)
            iSeriesInd = SState.iStartSeries + i - 1;
            if iSeriesInd <= length(SData) % Panel not empty
                
                if strcmp(SState.sDrawMode, 'phase')
                    dMin = -pi; dMax = pi;
                else
                    dMin = SData(SState.iStartSeries).dWindowCenter - 0.5.*SData(SState.iStartSeries).dWindowWidth;
                    dMax = SData(SState.iStartSeries).dWindowCenter + 0.5.*SData(SState.iStartSeries).dWindowWidth;
                end
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % Get the image data, do windowing and apply colormap
                if ~fIsOn('link1') && ~strcmp(SState.sDrawMode, 'phase')
                    dMin = SData(iSeriesInd).dWindowCenter - 0.5.*SData(iSeriesInd).dWindowWidth;
                    dMax = SData(iSeriesInd).dWindowCenter + 0.5.*SData(iSeriesInd).dWindowWidth;
                end
                dImg = fGetImg(iSeriesInd);
                isColor = size(dImg,3) > 1;
                if ~isColor
                    dImg = dImg - dMin;
                    iImg = round(dImg.*((SAp.iCOLORMAPLENGTH - 1)./(dMax - dMin))+ 1) ;
                    iImg(iImg < 1 | isnan(iImg)) = 1;
                    iImg(iImg > SAp.iCOLORMAPLENGTH) = SAp.iCOLORMAPLENGTH;
                    dImg = reshape(SState.dColormapBack(iImg, :), [size(iImg, 1) ,size(iImg, 2), 3]);
                end
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % Apply mask if any
                
                masks = SData(iSeriesInd).cts.masks;
                colors = maskColors;
                
                for k = 1:length(masks)
                    mask = masks{k};
                    if ~isempty(mask)
                        dColormap = [ 0 0 0 ; colors(k,:) ];
                        switch SState.sDrawMode
                            case {'mag', 'phase'}, iMask = uint8(mask(:,:,SData(iSeriesInd).iActiveImage));
                            case {'max', 'min'}  , iMask = uint8(max(mask, [], 3));
                        end
                        if any2(iMask)
                            iMask = bwperim ( iMask ) + 1;
%                             iMask = iMask + 1;
                            if SState.coarseROI
                                [ r , c ] = find(iMask > 1);
                                dMask = ones(size(iMask));
                                minr = min(r);
                                maxr = max(r);
                                minc = min(c);
                                maxc = max(c);
                                dMask(minr:maxr,[ minc , maxc]) = 2;
                                dMask([minr maxr],minc:maxc) = 2;
                                dMask = reshape(dColormap(dMask, :), [size(dMask, 1) ,size(dMask, 2), 3]);
                            else
                                se = strel('disk',1);
%                                 iMask = imdilate(iMask, se);
                                dMask = reshape(dColormap(iMask, :), [size(iMask, 1) ,size(iMask, 2), 3]);
                            end
                            
                            dImg = 1 - (1 - dImg).*(1 - SState.dMaskOpacity.*dMask); % The 'screen' overlay mode
                        end
                    end
                    set(SImg.hImg(i), 'CData', dImg);
                end
                
                %                 if ~isempty(SData(iSeriesInd).rMask)
                %                     dColormap = [0 0 0; [1 0 0]];
                %                     switch SState.sDrawMode
                %                         case {'mag', 'phase'}, iMask = uint8(SData(iSeriesInd).rMask(:,:,SData(iSeriesInd).iActiveImage)) + 1;
                %                         case {'max', 'min'}  , iMask = uint8(max(SData(iSeriesInd).rMask, [], 3)) + 1;
                %                     end
                %                     dMask = reshape(dColormap(iMask, :), [size(iMask, 1) ,size(iMask, 2), 3]);
                %                     dImg = 1 - (1 - dImg).*(1 - SState.dMaskOpacity.*dMask); % The 'screen' overlay mode
                %                 end
                %                 set(SImg.hImg(i), 'CData', dImg);
                %                 % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                %
                %                 % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                %                 % Apply green mask
                %                 if ~isempty(SData(iSeriesInd).gMask)
                %                     dColormap = [0 0 0; [0 1 0]];
                %                     switch SState.sDrawMode
                %                         case {'mag', 'phase'}, iMask = uint8(SData(iSeriesInd).gMask(:,:,SData(iSeriesInd).iActiveImage)) + 1;
                %                         case {'max', 'min'}  , iMask = uint8(max(SData(iSeriesInd).gMask, [], 3)) + 1;
                %                     end
                %                     dMask = reshape(dColormap(iMask, :), [size(iMask, 1) ,size(iMask, 2), 3]);
                %                     dImg = 1 - (1 - dImg).*(1 - SState.dMaskOpacity.*dMask); % The 'screen' overlay mode
                %                 end
                %                 set(SImg.hImg(i), 'CData', dImg);
                %                 % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % Handle zoom and shift
                dPos = get(SPanels.hImg(i), 'Position');
                dScale = SData(iSeriesInd).dPixelSpacing;
                dScale = dScale(2:-1:1)./min(dScale); % Smallest Entry scaled to 1
                dDim = [size(dImg, 2), size(dImg, 1)]; % Swap x and y
                dSize = dDim.*SData(iSeriesInd).dZoomFactor.*dScale;
                set(SAxes.hImg(i), ...
                    'Position', [SData(iSeriesInd).dDrawCenter.*dPos(3:4) - dSize./2, dSize], ...
                    'XLim'    , [0.5 dDim(1) + 0.5], ...
                    'YLim'    , [0.5 dDim(2) + 0.5]);
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % Update the text elements
                set(STexts.hColorbarMin(i), 'String', sprintf('%s', fPrintNumber(dMin)));
                set(STexts.hColorbarMax(i), 'String', sprintf('%s', fPrintNumber(dMax)));
                set(STexts.hImg1(i), 'String', ['[', int2str(iSeriesInd), ']: ', SData(iSeriesInd).sName]);
                if strcmp(SState.sDrawMode, 'max') || strcmp(SState.sDrawMode, 'min')
                    set(STexts.hImg2(iSeriesInd), 'String', 'Projection');
                else
                    set(STexts.hImg2(i), 'String', sprintf('%u/%u', SData(iSeriesInd).iActiveImage, size(SData(iSeriesInd).cts.volume, 3)));
                end
                set(STexts.hEval(i), 'String', SData(iSeriesInd).sEvalText);
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                
            else % Panel is empty
                
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % Set image to the background image (RGB)
                set(SImg.hImg(i), 'CData', SAp.dEmptyImg);
                dXDim = size(SAp.dEmptyImg, 2);
                dYDim = size(SAp.dEmptyImg, 1);
                set(SAxes.hImg(i), 'Position', [1 1 dXDim, dYDim], 'XLim', [0.5 dXDim + 0.5], 'YLim', [0.5 dYDim + 0.5]);
                set(STexts.hImg1(i), 'String', '<no data>');
                set(STexts.hImg2(i), 'String', '');
                set([STexts.hEval(i), STexts.hVal(i)], 'String', '');
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            end
        end
        
    end


% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fFillPanels
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fGetImg (nested in imagine)
% * *
% * * Return data for view according to drawmode
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function dImg = fGetImg(iInd, iImgInd)
        if nargin < 2, iImgInd = SData(iInd).iActiveImage; end
        
        if strcmp(SState.sDrawMode, 'phase')
            dImg = angle(SData(iInd).cts.volume(:,:,iImgInd));
            return
        end
        
        dImg = SData(iInd).cts.volume;
        if ~isreal(dImg), dImg = abs(dImg); end
        if ~inRange(iImgInd , size(dImg,3) , 1 )
            iImgInd = 1;
        end
        switch SState.sDrawMode
            case 'mag', dImg = squeeze(dImg(:,:,iImgInd,:));
            case 'max', dImg = max(dImg, [], 3);
            case 'min', dImg = min(dImg, [], 3);
        end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fGetImg
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =


% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fCreatePanels (nested in imagine)
% * *
% * * Create the panels and its child object.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fCreatePanels
        % -----------------------------------------------------------------
        % Delete panels and their handles if necessary
        if isfield(SPanels, 'hImgFrame')
            delete(SPanels.hImgFrame); % Deletes hImgFrame and its children
            SPanels = rmfield(SPanels, {'hImgFrame', 'hImg'});
            STexts  = rmfield(STexts,  {'hImg1', 'hImg2', 'hColorbarMin', 'hColorbarMax','hEval', 'hVal'});
            SAxes   = rmfield(SAxes,   {'hImg', 'hColorbar'});
            SImg    = rmfield(SImg,    {'hImg', 'hColorbar'});
        end
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % For each panel create panels, axis, image and text objects
        for i = 1:prod(SState.iPanels)
            SPanels.hImgFrame(i) = uipanel(...
                'Parent'                , hF, ...
                'BackgroundColor'       , SAp.dBGCOLOR*0.6, ...
                'BorderWidth'           , 0, ...
                'BorderType'            , 'line', ...
                'Units'                 , 'pixels');
            SPanels.hImg(i) = uipanel(...
                'Parent'                , SPanels.hImgFrame(i), ...
                'BackgroundColor'       , SState.dColormapBack(1,:), ...
                'BorderWidth'           , 0, ...
                'Units'                 , 'pixels');
            SAxes.hImg(i) = axes(...
                'Parent'                , SPanels.hImg(i), ...
                'Units'                 , 'pixels');
            SImg.hImg(i) = image(zeros(1, 'uint8'), ...
                'Parent'                , SAxes.hImg(i), ...
                'HitTest'               , 'off');
            SAxes.hColorbar(i) = axes(...
                'Parent'                , SPanels.hImgFrame(i), ...
                'Units'                 , 'pixels', ...
                'XAxisLocation'         , 'top');
            SImg.hColorbar(i)       = image(uint8(0:255), 'Parent', SAxes.hColorbar(i), 'ButtonDownFcn', @fSetWindow);
            STexts.hImg1(i)         = uicontrol('Style', 'text', 'Parent', SPanels.hImgFrame(i));
            STexts.hImg2(i)         = uicontrol('Style', 'text', 'Parent', SPanels.hImgFrame(i));
            STexts.hColorbarMin(i)  = uicontrol('Style', 'text', 'Parent', SPanels.hImgFrame(i));
            STexts.hColorbarMax(i)  = uicontrol('Style', 'text', 'Parent', SPanels.hImgFrame(i));
            STexts.hEval(i)         = uicontrol('Style', 'text', 'Parent', SPanels.hImgFrame(i));
            STexts.hVal(i)          = uicontrol('Style', 'text', 'Parent', SPanels.hImgFrame(i));
            
            iDataInd = i + SState.iStartSeries - 1;
            if (iDataInd > 0) && (iDataInd <= length(SData))
                set(STexts.hColorbarMin(i), 'String', sprintf('%s', fPrintNumber(SData(iDataInd).dWindowCenter - SData(iDataInd).dWindowWidth./2)));
                set(STexts.hColorbarMax(i), 'String', sprintf('%s', fPrintNumber(SData(iDataInd).dWindowCenter + SData(iDataInd).dWindowWidth./2)));
            end
            
        end % of loop over pannels
        % -----------------------------------------------------------------
        
        axis(SAxes.hImg, 'off');
        set(SAxes.hColorbar, 'XAxisLocation', 'top', 'XTick', [], 'YTick', [], 'XTickLabel', [], 'Visible', 'on');
        set([STexts.hColorbarMin, STexts.hColorbarMax, STexts.hEval, STexts.hVal], ...
            'BackgroundColor'       , SAp.dBGCOLOR*0.6, ...
            'ForegroundColor'       , 'w', ...
            'HorizontalAlignment'   , 'left', ...
            'FontUnits'             , 'normalized', ...
            'FontSize'              , 0.8);
        set([STexts.hImg1, STexts.hImg2], ...
            'BackgroundColor'       , SAp.dBGCOLOR*0.6, ...
            'ForegroundColor'       , 'w', ...
            'HorizontalAlignment'   , 'left', ...
            'FontUnits'             , 'normalized', ...
            'FontSize'              , 0.8);
        set([STexts.hColorbarMin, STexts.hVal, STexts.hImg2], 'HorizontalAlignment', 'right');
        
        %         if strcmp(SState.sTool, 'rg'), set(SPanels.hImg, 'uicontextmenu', hContextMenu); end
        set(SPanels.hImg, 'uicontextmenu', measureContextMenu);
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fCreatePanels
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    function fSetWindow(hObject, eventdata)
        iAxisInd = find(SImg.hColorbar == hObject);
        iSeriesInd = iAxisInd + SState.iStartSeries - 1;
        if iSeriesInd > length(SData), return, end
        
        dMin = SData(iSeriesInd).dWindowCenter - 0.5.*SData(iSeriesInd).dWindowWidth;
        dMax = SData(iSeriesInd).dWindowCenter + 0.5.*SData(iSeriesInd).dWindowWidth;
        csVal{1} = fPrintNumber(dMin);
        csVal{2} = fPrintNumber(dMax);
        csAns = inputdlg({'Min', 'Max'}, sprintf('Change %s windowing', SData(iSeriesInd).sName), 1, csVal);
        if isempty(csAns), return, end
        
        csVal = textscan([csAns{1}, ' ', csAns{2}], '%f %f');
        if ~isempty(csVal{1}), dMin = csVal{1}; end
        if ~isempty(csVal{2}), dMax = csVal{2}; end
        SData(iSeriesInd).dWindowCenter = (dMin + dMax)./2;
        SData(iSeriesInd).dWindowWidth  = (dMax - dMin);
        fFillPanels;
    end

% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fUpdateActivation (nested in imagine)
% * *
% * * Set the activation and availability of some switches according to
% * * the GUI state.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

    function fUpdateButtonActivation(buttonName , flag)
        csLabels = {SIcons.Name};
        btnIdx = find(strcmp(csLabels, buttonName));
        if ~isempty(btnIdx)
            SIcons(btnIdx).Enabled = flag;
        end
    end
    function fUpdateActivation
        
        % -----------------------------------------------------------------
        % Update states of some menubar buttons according to panel selection
        %         fUpdateButtonActivation('save' , fGetNActiveVisibleSeries() > 0);
        fUpdateButtonActivation('doc_delete' , fGetNActiveVisibleSeries() > 0);
        fUpdateButtonActivation('echange' , fGetNActiveVisibleSeries() == 2);
        fUpdateButtonActivation('record' , ~isempty(SState.sEvalFilename));
        fUpdateButtonActivation('stop' , ~isempty(SState.sEvalFilename));
        fUpdateButtonActivation('rewind' , ~isempty(SState.sEvalFilename));
        
        % -----------------------------------------------------------------
        fUpdateButtonActivation('lw' , exist('fLiveWireCalcP','file') == 3);
        fUpdateButtonActivation('rg' , exist('fRegionGrowingAuto_mex','file') == 3);
        fUpdateButtonActivation('ic' , exist('fIsoContour_mex','file') == 3);
        
        % -----------------------------------------------------------------
        % Treat the menubar items
        dScale = ones(length(SIcons));
        dScale(~[SIcons.Enabled]) = SAp.iDISABLED_SCALE;
        dScale( [SIcons.Enabled] & ~[SIcons.Active]) = SAp.iINAMRIVE_SCALE;
        for i = 1:length(SIcons), set(SImg.hIcons(i), 'CData', SIcons(i).dImg.*dScale(i)); end
        % -----------------------------------------------------------------
        
        % -----------------------------------------------------------------
        % Treat the panels
        for i = 1:length(SPanels.hImgFrame)
            iSeriesInd = i + SState.iStartSeries - 1;
            if iSeriesInd > length(SData) || ~SData(iSeriesInd).lActive
                set([SPanels.hImgFrame(i), STexts.hImg1(i), STexts.hImg2(i), STexts.hColorbarMin(i), STexts.hColorbarMax(i), STexts.hEval(i), STexts.hVal(i)], 'BackgroundColor', SAp.dBGCOLOR.*0.6);
            else
                set([SPanels.hImgFrame(i), STexts.hImg1(i), STexts.hImg2(i), STexts.hColorbarMin(i), STexts.hColorbarMax(i), STexts.hEval(i), STexts.hVal(i)], 'BackgroundColor', SAp.dBGCOLOR);
            end
        end
        % -----------------------------------------------------------------
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fUpdateActivation
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fGetNActiveVisibleSeries (nested in imagine)
% * *
% * * Returns the number of visible active series.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function iNActiveSeries = fGetNActiveVisibleSeries()
        iNActiveSeries = 0;
        if isempty(SData), return, end
        
        iStartInd = SState.iStartSeries;
        iEndInd = min([iStartInd + length(SPanels.hImgFrame) - 1, length(SData)]);
        iNActiveSeries = nnz([SData(iStartInd:iEndInd).lActive]);
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fGetNActiveVisibleSeries
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fGetNVisibleSeries (nested in imagine)
% * *
% * * Returns the number of visible active series.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function iNVisibleSeries = fGetNVisibleSeries()
        if isempty(SData)
            iNVisibleSeries = 0;
        else
            iNVisibleSeries = min([length(SPanels.hImgFrame), length(SData) - SState.iStartSeries + 1]);
        end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fGetNVisibleSeries
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fParseInputs (nested in imagine)
% * *
% * * Parse the varargin input variable. It can be either pairs of
% * * data/captions or just data. Data can be either 2D, 3D or 4D.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fParseInputs(cInput)
        
        iInd = 1;
        iDataInd = 0;
        
        
        while iInd <= length(cInput);
            xInput = cInput{iInd};
            if ~(isnumeric(xInput) || islogical(xInput) || ischar(xInput) || isMRscan(xInput)), error('Argument %d expected to be either property or data!', iInd); end
            
            if (isnumeric(xInput) || islogical(xInput)) % New image data
                if iDataInd, fAddImageToData(dImg, sName, 'startup', dDim, sUnits, dWindow); end% Add the last Dataset
                iDataInd = iDataInd + 1;
                dImg = xInput;
                sName = sprintf('Input_%02d', iDataInd);
                %                 sName = cInputNames(iInd);
                dDim = [1 1 1];
                sUnits = 'px';
                dWindow = [];
            elseif isMRscan(xInput) % New image data
                if iDataInd, fAddImageToData(dImg, sName, 'startup', dDim, sUnits, dWindow); end% Add the last Dataset
                iDataInd = iDataInd + 1;
                dImg = xInput;
                sName = xInput.getName;
                %                 sName = cInputNames(iInd);
                dDim = [1 1 1];
                sUnits = 'px';
                dWindow = xInput.getWindow;
            end
            
            SState.noWindow = true;
            %             if ischar(xInput)
            %                 %                 iInd = iInd + 1;
            %                 %                 if iInd > length(cInput), error('Argument %d (property) must be followed by a value!', iInd - 1); end
            %                 %
            %                 %                 xVal = cInput{iInd};
            %                 switch lower(xInput)
            %                     case { 'nowindow'  , 'nowin'}
            %                         SState.noWindow = true;
            %                         %                     case {'n', 'name'}
            %                         %                         if ~ischar(xVal), error('Name property must be a string!'); end
            %                         %                         sName = xVal;
            %                         %                     case {'v', 'voxelsize'}
            %                         %                         if ~isnumeric(xVal) || numel(xVal) ~= 3, error('Voxelsize property must be a [3x1] or [1x3] numeric vector!'); end
            %                         %                         dDim = xVal;
            %                         %                     case {'u', 'units'}
            %                         %                         if ~ischar(xVal), error('Units property must be a string!'); end
            %                         %                         sUnits = xVal;
            %                         %                     case {'w', 'window'}
            %                         %                         if ~isnumeric(xVal) || numel(xVal) ~= 2, error('Window limits property must be a [2x1] or [1x2] numeric vector!'); end
            %                         %                         dWindow = xVal;
            %                         %                     case {'m', 'mask'}
            %                         %                         if ~islogical(xVal) || ndims(xVal) ~= ndims(dImg), error('Mask must be logical and have same number of dimensions as the image!'); end
            %                         %                         if any(size(dImg) ~= size(xVal)), error('Mask must have same size as image'); end
            %                         %                         rMask = xVal;
            %                         %                     case {'p', 'panels'}
            %                         %                         if ~isnumeric(xVal) || numel(xVal) ~= 2, error('Panel size must be a [2x1] or [1x2] numeric vector!'); end
            %                         %                         SState.iPanels = xVal(:)';
            %                     otherwise, error('Unknown property ''%s''!', xInput);
            %                 end
            %
            %             end
            iInd = iInd + 1;
        end
        if iDataInd, fAddImageToData(dImg, sName, 'startup', dDim, sUnits, dWindow); end
        
        if sum(SState.iPanels) == 0
            iNumImages = length(SData);
            dRoot = sqrt(iNumImages);
            iPanelsN = ceil(dRoot);
            iPanelsM = ceil(dRoot);
            while iPanelsN*iPanelsM >= iNumImages
                iPanelsN = iPanelsN - 1;
            end
            iPanelsN = iPanelsN + 1;
            iPanelsN = min([4, iPanelsN]);
            iPanelsM = min([4, iPanelsM]);
            if iNumImages == 3
                iPanelsN = 1;
                iPanelsM = 3;
            end
            SState.iPanels = [iPanelsN, iPanelsM];
        end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fParseInputs
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fLoadFiles (nested in imagine)
% * *
% * * Load image files from disk and sort into series.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fLoadFiles(csFilenames)
        if ~iscell(csFilenames), csFilenames = {csFilenames}; end % If only one file
        lLoaded = false(length(csFilenames), 1);
        
        SImageData = [];
        hW = waitbar(0, 'Loading files');
        for i = 1:length(csFilenames)
            [sPath, sName, sExt] = fileparts(csFilenames{i}); %#ok<ASGLU>
            switch lower(sExt)
                % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                % Standard image data: Try to group according to size
                case {'.jpg', '.jpeg', '.tif', '.tiff', '.gif', '.bmp', '.png'}
                    try
                        dImg = double(imread([SState.sPath, csFilenames{i}]))./255;
                        lLoaded(i) = true;
                    catch %#ok<MRCH>
                        disp(['Error when loading "', SState.sPath, csFilenames{i}, '": File extenstion and type do not match']);
                        continue;
                    end
                    dImg = mean(dImg, 3);
                    iInd = fServesSizeCriterion(size(dImg), SImageData);
                    if iInd
                        dImg = cat(3, SImageData(iInd).dImg, dImg);
                        SImageData(iInd).dImg = dImg;
                    else
                        iLength = length(SImageData) + 1;
                        SImageData(iLength).dImg = dImg;
                        SImageData(iLength).sOrigin = 'Image File';
                        SImageData(iLength).sName = csFilenames{i};
                        SImageData(iLength).dPixelSpacing = [1 1 1];
                    end
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    % NifTy Data
                case '.nii'
                    set(hF, 'Pointer', 'watch'); drawnow;
                    [dImg, dDim] = fNifTyRead([SState.sPath, csFilenames{i}]);
                    if ndims(dImg) > 4, error('Only 4D data supported'); end
                    lLoaded(i) = true;
                    fAddImageToData(dImg, csFilenames{i}, 'NifTy File', dDim, 'mm');
                    set(hF, 'Pointer', 'arrow');
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                case '.gipl'
                    set(hF, 'Pointer', 'watch'); drawnow;
                    [dImg, dDim] = fGIPLRead([SState.sPath, csFilenames{i}]);
                    lLoaded(i) = true;
                    fAddImageToData(dImg, csFilenames{i}, 'GIPL File', dDim, 'mm');
                    set(hF, 'Pointer', 'arrow');
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                    
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                case '.mat'
                    csVars = fMatRead([SState.sPath, csFilenames{i}]);
                    lLoaded(i) = true;
                    if isempty(csVars), continue, end   % Dialog aborted
                    
                    set(hF, 'Pointer', 'watch'); drawnow;
                    for iJ = 1:length(csVars)
                        S = load([SState.sPath, csFilenames{i}], csVars{iJ});
                        eval(['dImg = S.', csVars{iJ}, ';']);
                        fAddImageToData(dImg, sprintf('%s in %s', csVars{iJ}, csFilenames{i}), 'MAT File');
                    end
                    set(hF, 'Pointer', 'arrow');
                    % - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            end
            waitbar(i/length(csFilenames), hW);
        end
        close(hW);
        
        for i = 1:length(SImageData)
            fAddImageToData(SImageData(i).dImg, SImageData.sName, 'Image File', [1 1 1]);
        end
        
        set(hF, 'Pointer', 'watch'); drawnow;
        SDicomData = fDICOMRead(csFilenames(~lLoaded), SState.sPath);
        for i = 1:length(SDicomData)
            fAddImageToData(SDicomData(i).dImg, SDicomData(i).SeriesDescriptions, 'DICOM', SDicomData(i).Aspect, 'mm');
        end
        set(hF, 'Pointer', 'arrow');
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fLoadFiles
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fAddImageToData (nested in imagine)
% * *
% * * Add image data to the global SDATA variable. Can handle 2D, 3D or
% * * 4D data.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
%     function fAddImageToData(dImage, sName, sOrigin, dDim, sUnits, dWindow, rMask, gMask)
%         if (nargin < 8)
%             gMask = [];
%         end
%         if (nargin < 7)
%             rMask = [];
%         end
%         if nargin < 6, dWindow = []; end
%         if nargin < 5, sUnits = 'px'; end
%         if nargin < 4, dDim = [1 1 1]; end
%         if islogical(dImage), dImage = ones(size(dImage)).*dImage; end
%
%         if strcmp(class(dImage),'MRscan')
%             windowTemp = dImage.getWindow;
%             dImage = dImage.getVolume;
%         end
%
%         dImage = double(dImage);
%
%
%         dImage(isnan(dImage)) = 0;
%
%                 iInd = length(SData) + 1;
%
%
%
%         iGroupIndex = 1;

    function fAddImageToData(dImage, sName, sOrigin, dDim, sUnits, dWindow)
        if nargin < 6
            if isMRscan(dImage)
                dWindow = dImage.getWindow;
            else
                dWindow = [];
            end
        end
        if nargin < 5, sUnits = 'px'; end
        if nargin < 4, dDim = [1 1 1]; end
        
        % update sdata ind
        iInd = length(SData) + 1;
        
        
        iGroupIndex = 1;
        if ~isempty(SData)
            iExistingGroups = unique([SData.iGroupIndex]);
            if ~isempty(iExistingGroups)
                while nnz(iExistingGroups == iGroupIndex), iGroupIndex = iGroupIndex + 1; end
            end
        end
        
        if isMRscan(dImage)
            %             SData(iInd).cts = MRscan(dImage);
            SData(iInd).cts = dImage;
        else
            SData(iInd).cts = MRscan(double(dImage));
        end
        
        if ~isempty(dWindow)
            dMin = dWindow(1);
            dMax = dWindow(2);
        else
            if isreal(SData(iInd).cts.volume)
                dMin = min(SData(iInd).cts.volume(:));
                dMax = max(SData(iInd).cts.volume(:));
            else
                dMin = min(abs(SData(iInd).cts.volume(:)));
                dMax = max(abs(SData(iInd).cts.volume(:)));
            end
        end
        SData(iInd).dDynamicRange = [dMin, dMax];
        SData(iInd).dWindowCenter = (dMax + dMin)./2;
        SData(iInd).dWindowWidth  = dMax - dMin;
        
        SData(iInd).sOrigin = sOrigin;
        
        SData(iInd).dZoomFactor = 1;
        SData(iInd).dDrawCenter = [0.5 0.5];
        SData(iInd).iActiveImage = 1;
        SData(iInd).lActive = false;
        if dDim(end) == 0, dDim(end) = min(dDim(1:2)); end
        SData(iInd).dPixelSpacing = dDim(:)';
        SData(iInd).sUnits = sUnits;
        SData(iInd).iGroupIndex = iGroupIndex;
        SData(iInd).sEvalText = '';
        SData(iInd).sName = sName;
        
        iInd = iInd+1;
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fAddImageToData
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fGetPanel (nested in imagine)
% * *
% * * Determine the panelnumber under the mouse cursor. Returns 0 if
% * * not over a panel at all.
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function iPanelInd = fGetPanel()
        iCursorPos = get(hF, 'CurrentPoint');
        iPanelInd = uint8(0);
        for i = 1:min([length(SPanels.hImg), length(SData) - SState.iStartSeries + 1])
            dPos = get(SPanels.hImgFrame(i), 'Position');
            if ((iCursorPos(1) >= dPos(1)) && (iCursorPos(1) < dPos(1) + dPos(3)) && ...
                    (iCursorPos(2) >= dPos(2) + SAp.iEVALBARHEIGHT) && (iCursorPos(2) < dPos(2) + dPos(4) - SAp.iTITLEBARHEIGHT - SAp.iCOLORBARHEIGHT))
                iPanelInd = uint8(i);
            end
        end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fGetPanel
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fServesSizeCriterion (nested in imagine)
% * *
% * * Determines, whether the data structure contains an image series
% * * with the same x- and y-dimensions as iSize
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function iInd = fServesSizeCriterion(iSize, SNewData)
        iInd = 0;
        for i = 1:length(SNewData)
            if (iSize(1) == size(SNewData(i).cts.volume, 1)) && ...
                    (iSize(2) == size(SNewData(i).cts.volume, 2))
                iInd = i;
                return;
            end
        end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fServesSizeCriterion
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fZoom (nested in imagine)
% * *
% * * Zoom images
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fZoom(iD, dPanelPos)
        for i = 1:length(SData)
            if (~fIsOn('link')) && i ~= (SMouse.iStartAxis + SState.iStartSeries - 1), continue, end % Skip if axes not linked and current figure not active
            
            iAxisInd = i - SState.iStartSeries + 1;
            
            dZoomFactor = max([0.25, SMouse.dZoomFactor(i).*exp(SPref.dZOOMSENSITIVITY.*iD(2))]);
            dZoomFactor = min([dZoomFactor, 100]);
            
            dScale = SData(i).dPixelSpacing;
            dScale = dScale(2:-1:1)./min(dScale); % Smallest Entry scaled to 1
            
            dStaticCoordinate = SMouse.dAxesStartPos - 0.5;
            dStaticCoordinate(2) = size(SData(i).cts.volume, 1) - dStaticCoordinate(2);
            iFramePos = get(SPanels.hImgFrame(SMouse.iStartAxis), 'Position');
            dStaticPoint = SMouse.iStartPos - iFramePos(1:2);
            if SState.lShowEvalbar, dStaticPoint(2) = dStaticPoint(2) - SAp.iEVALBARHEIGHT; end;
            
            dStartPoint = dStaticPoint - (dStaticCoordinate).*dZoomFactor.*dScale + [1.5 1.5];
            dEndPoint   = dStaticPoint + ([size(SData(i).cts.volume, 2), size(SData(i).cts.volume, 1)] - dStaticCoordinate).*dZoomFactor.*dScale + [1.5 1.5];
            
            SData(i).dDrawCenter = (dEndPoint + dStartPoint)./(2.*dPanelPos(3:4)); % Save Draw Center
            SData(i).dZoomFactor = dZoomFactor; % Save ZoomFactor data
            
            if iAxisInd < 1 || iAxisInd > length(SPanels.hImg), continue, end % Do not update images outside the figure's scope (will be done with next call of fFillPanels
            
            dScale = SData(i).dPixelSpacing;
            dScale = dScale./min(dScale); % Smallest Entry scaled to 1
            
            dImageWidth  = double(size(SData(i).cts.volume, 2)).*dZoomFactor.*dScale(2);
            dImageHeight = double(size(SData(i).cts.volume, 1)).*dZoomFactor.*dScale(1);
            set(SAxes.hImg(iAxisInd), 'Position', [dPanelPos(3).*SData(i).dDrawCenter(1) - dImageWidth/2, ...
                dPanelPos(4).*SData(i).dDrawCenter(2) - dImageHeight/2, ...
                dImageWidth, dImageHeight]);
            if iAxisInd == SMouse.iStartAxis % Show zooming information for the starting axis
                set(STexts.hStatus, 'String', sprintf('Zoom: %3.1fx', dZoomFactor));
            end
        end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fZoom
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fWindow (nested in imagine)
% * *
% * * Window an image (that is radiology slang for
% * * "adjust contrast and brightness")
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fWindow(iD)
        for i = 1:length(SData)
            if (~fIsOn('link')) && (i ~= SMouse.iStartAxis + SState.iStartSeries - 1), continue, end % Skip if axes not linked and current figure not active
            
            SData(i).dWindowWidth  = SMouse.dWindowWidth(i) .*exp(SPref.dWINDOWSENSITIVITY*(-iD(2)));
            SData(i).dWindowCenter = SMouse.dWindowCenter(i).*exp(SPref.dWINDOWSENSITIVITY*  iD(1));
            iAxisInd = i - SState.iStartSeries + 1;
            if iAxisInd < 1 || iAxisInd > length(SPanels.hImg), continue, end % Do not update images outside the figure's scope (will be done with next call of fFillPanels)
            if iAxisInd == SMouse.iStartAxis % Show windowing information for the starting axes
                set(STexts.hStatus, 'String', sprintf('C: %s, W: %s', fPrintNumber(SData(i).dWindowCenter), fPrintNumber(SData(i).dWindowWidth)));
            end
        end
        fFillPanels;
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fWindow
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fIsOn (nested in imagine)
% * *
% * * Determine whether togglebutton is active
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function lOn = fIsOn(sTag)
        tagName = strcmp({SIcons.Name}, sTag);
        lOn = false;
        if any(tagName)
            lOn = SIcons(tagName).Active;
        end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fIsOn
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION SDataOut (nested in imagine)
% * *
% * * Thomas' hack function to get the data structure
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function iSeriesInd = getActivePanels()
        iSeriesInd = find([SData.lActive]); % Get indices of selected axes;
    end

    function updateTextWindow(selectedAxis , mind)
        if SState.noWindow || ~textWindow.isvalid
            return;
        end
        if ~exist('mind' ,'var')
            mind = [];
        end
        
        if ~exist('selectedAxis' , 'var') || isempty(selectedAxis)
            selectedAxis = SState.currentTextWindow;
        end
        
        SState.currentTextWindow = selectedAxis;
        
        linkingFunction = textWindow.UserData;
        linkingFunction.updateWindow(SData(selectedAxis).cts , mind); % update function of text window
        set ( textWindow , 'Name' , sprintf('window %d' , selectedAxis ) ) ;
        
    end

    function iSeriesInd = getActivePanelsAndPressed()
        iSeriesInd = find([SData.lActive]); % Get indices of selected axes;
        pressed = fGetPanel();
        if all(iSeriesInd ~= pressed)
            iSeriesInd = [ iSeriesInd pressed ];
        end
        if isempty(iSeriesInd)
            iSeriesInd = 1;
        end
    end

    function SDataOut = fGetData
        SDataOut = SData;
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION SDataOut
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =


% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fPrintNumber (nested in imagine3D)
% * *
% * * Display a value in adequate format
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function sString = fPrintNumber(xNumber)
        if isempty(xNumber)
            sString = 'empty';
            return;
        end
        if length(xNumber) > 1
            s = '';
            for k = 1:length(xNumber)
                s =[ s ',' fPrintNumber(xNumber(k))];
            end
            sString = sprintf('(%s)', s(2:end));
            return;
        end
        if ((abs(xNumber) < 0.01) && (xNumber ~= 0)) || (abs(xNumber) > 1E4)
            sString = sprintf('%2.1E', xNumber);
        else
            sString = sprintf('%4.2f', xNumber);
        end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fPrintNumber
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =


% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fBackgroundImg (nested in imagine)
% * *
% * * Create a funky image for empty panels
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function dImg = fBackgroundImg(dHeight, dWidth)
        %
        
        dImg = imread('logo.png');
        %         dLogo = [0 0 0 1 1 0 0 0; ...
        %                  0 0 0 1 1 0 0 0; ...
        %                  0 0 0 0 0 0 0 0; ...
        %                  0 0 1 1 1 0 0 0; ...
        %                  0 0 0 1 1 0 0 0; ...
        %                  0 0 0 1 1 0 0 0; ...
        %                  0 0 1 1 1 1 0 0; ...
        %                  0 0 0 0 0 0 0 0;];
        %
        %         dWidth  = ceil(dWidth./16);
        %         dHeight = ceil(dHeight./16);
        %         dImg = 0.6 + 0.4.*rand(dHeight, dWidth);
        %         if ~any(size(dImg) < 8)
        %             dImg(floor(dHeight/2) - 3:floor(dHeight/2) + 4, floor(dWidth/2) - 3:floor(dWidth/2) + 4) = ...
        %             dImg(floor(dHeight/2) - 3:floor(dHeight/2) + 4, floor(dWidth/2) - 3:floor(dWidth/2) + 4) + 0.6.*dLogo;
        %         end
        %
        %         dImg = fReplicate(dImg, 1);
        %         dImg = 0.9.*dImg + 0.1.*rand(size(dImg));
        %         dImg = fReplicate(dImg, 3);
        %
        %         dImg = imfilter(dImg, [0 -3 0; -3 13 -3; 0 -3 0], 'circular', 'same');
        %         dImg = 0.8.*dImg + 0.7.*rand(size(dImg));
        %         dImg = dImg.*repmat(linspace(1, 0.3, size(dImg, 1))', [1, size(dImg, 2)]);
        %
        %         dImg = repmat(dImg, [1 1 3]);
        %         dImg = dImg.*repmat(permute(SAp.dBGCOLOR./2, [1 3 2]) , [size(dImg, 1), size(dImg, 2), 1]);
        %         dImg(dImg > 1.0) = 1.0;
        %         dImg(dImg < 0.0) = 0.0;
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fBackgroundImg
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =


% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fReplicate (nested in imagine)
% * *
% * * Scale image by power of 2 by nearest neighbour interpolation
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function dImgOut = fReplicate(dImg, iIter)
        dImgOut = zeros(2.*size(dImg));
        dImgOut(1:2:end, 1:2:end) = dImg;
        dImgOut(2:2:end, 1:2:end) = dImg;
        dImgOut(1:2:end, 2:2:end) = dImg;
        dImgOut(2:2:end, 2:2:end) = dImg;
        iIter = iIter - 1;
        if iIter > 0, dImgOut = fReplicate(dImgOut, iIter); end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fReplicate
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =



% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * NESTED FUNMRION fCompileMex (nested in imagine)
% * *
% * * Scale image by power of 2 by nearest neighbour interpolation
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fCompileMex
        fprintf('Imagine will try to compile some mex files!\n');
        sToolsPath = [SPref.sMFILEPATH, filesep, 'tools'];
        S = dir([sToolsPath, filesep, '*.cpp']);
        sPath = cd;
        cd(sToolsPath);
        lSucc = true;
        for i = 1:length(S)
            [temp, sName] = fileparts(S(i).name); %#ok<ASGLU>
            if exist(sName, 'file') == 3, continue, end
            try
                eval(['mex ', S(i).name]);
            catch
                warning('Could nor compile ''%s''!', S(i).name);
                lSucc = false;
            end
        end
        cd(sPath);
        if ~lSucc
            warndlg(sprintf('Not all mex files could be compiled, thus some tools will not be available. Try to setup the mex-compiler using ''mex -setup'' and compile the *.cpp files in the ''tools'' folder manually.'), 'IMAGINE');
        else
            fprintf('Hey, it worked!\n');
        end
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fCompileMex
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

end
% =========================================================================
% *** END FUNMRION imagine (and its nested functions)
% =========================================================================




% #########################################################################
% ***
% ***   Helper GUIS and their callbacks
% ***
% #########################################################################


% =========================================================================
% *** FUNMRION fGridSelect
% ***
% *** Creates a tiny GUI to select the GUI layout, i.e. the number of
% *** panels and the grid dimensions.
% ***
% =========================================================================
function iSizeOut = fGridSelect(iM, iN)

iAXESSIZE = 30;
iSizeOut = [0 0];

% -------------------------------------------------------------------------
% Create a new figure at the current mouse pointer position
iPos = get(0, 'PointerLocation');
iHeight = iAXESSIZE*iM;
iWidth  = iAXESSIZE*iN;
hGridFig = figure(...
    'Position'             , [iPos(1), iPos(2) - iHeight, iWidth, iHeight], ...
    'Units'                , 'pixels', ...
    'Color'                , [0.5 0.5 0.5], ...
    'DockControls'         , 'off', ...
    'WindowStyle'          , 'modal', ...
    'Name'                 , '', ...
    'WindowButtonMotionFcn', @fGridMouseMoveFcn, ...
    'WindowButtonDownFcn'  , 'uiresume(gcbf)', ... % continues the execution of this function after the uiwait when the mousebutton is pressed
    'NumberTitle'          , 'off', ...
    'Resize'               , 'off');

colormap gray
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Create MxN axes/images for the visualization
hA = zeros(iM, iN);
hI = zeros(iM, iN);
for iI = 1:iM
    for iJ = 1:iN
        hA(iI, iJ) = axes(...
            'Units'     , 'pixels', ...
            'Position'  , [(iJ - 1)*iAXESSIZE + 2, (iM - iI)*iAXESSIZE + 2, iAXESSIZE-2, iAXESSIZE-2], ...
            'Parent'    , hGridFig, ...
            'Color'     , 'w', ...
            'XLim'      , [0.5 1.5], ...
            'YLim'      , [0.5 1.5]); %#ok<LAXES>
        
        hI(iI, iJ) = image(256.*ones(1), ...
            'Parent'        ,  hA(iI, iJ));
        
        axis(hA(iI, iJ), 'off');
    end
end
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Handle GUI interaction
uiwait(hGridFig); % Wait until the uiresume function is called (happens when mouse button is pressed, see creation of the figure above)
try % Button was pressed, return the amount of selected panels
    delete(hGridFig); % close the figure
catch %#ok<MRCH> % if figure could not be deleted (dialog aborted), return [0 0]
    iSizeOut = [0 0];
end
% -------------------------------------------------------------------------


% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fGridMouseMoveFcn (nested in fGridSelect)
% * *
% * * Determine whether axes are linked
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fGridMouseMoveFcn(hObject, eventdata)
        dCursorPos = get(hGridFig, 'CurrentPoint'); % The mouse pointer
        dPos       = get(hGridFig, 'Position');     % The figure dimensions
        
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % Determine over which axes the mouse pointer is located
        i = ceil((dPos(4) - dCursorPos(2))/iAXESSIZE);
        j = ceil(dCursorPos(1)/iAXESSIZE);
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % Update the axes's colors to visualize the current selection
        for n = 1:size(hA, 1)
            for m = 1:size(hA, 2)
                if (i >= n) && (j >= m)
                    set(hI(n, m), 'CData', 0);
                else
                    set(hI(n, m), 'CData', 256);
                end
            end
        end
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        
        iSizeOut = [i, j]; % Update output variable
        drawnow expose
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fGridMouseMoveFcn
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

end
% =========================================================================
% *** END FUNMRION fGridSelect (and its nested functions)
% =========================================================================



% =========================================================================
% *** FUNMRION fColormapSelect
% ***
% *** Creates a tiny GUI to select the colormap.
% ***
% =========================================================================
function sColormap = fColormapSelect(hText)

iWIDTH = 128;
iBARHEIGHT = 32;

% -------------------------------------------------------------------------
% List the MATLAB built-in colormaps
csColormaps = {'gray', 'bone', 'copper', 'pink', 'hot', 'jet', 'hsv', 'cool'};
iNColormaps = length(csColormaps);
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Add custom colormaps (if any)
sColormapPath = [fileparts(mfilename('fullpath')), filesep, 'colormaps'];
SDir = dir([sColormapPath, filesep, '*.m']);
for iI = 1:length(SDir)
    iNColormaps = iNColormaps + 1;
    [sPath, sName] = fileparts(SDir(iI).name); %#ok<ASGLU>
    csColormaps{iNColormaps} = sName;
end
% -------------------------------------------------------------------------


% -------------------------------------------------------------------------
% Create a new figure at the current mouse pointer position
iPos = get(0, 'PointerLocation');
iHeight = iNColormaps.*iBARHEIGHT;
hColormapFig = figure(...
    'Position'             , [iPos(1), iPos(2) - iHeight, iWIDTH, iHeight], ...
    'WindowStyle'          , 'modal', ...
    'Name'                 , '', ...
    'WindowButtonMotionFcn', @fColormapMouseMoveFcn, ...
    'WindowButtonDownFcn'  , 'uiresume(gcbf)', ... % continues the execution of this function after the uiwait when the mousebutton is pressed
    'NumberTitle'          , 'off', ...
    'Resize'               , 'off');
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Make the true-color image with the colormaps
dImg = zeros(iNColormaps, iWIDTH, 3);
dLine = zeros(iWIDTH, 3);
for iI = 1:iNColormaps
    eval(['dLine = ', csColormaps{iI}, '(iWIDTH);']);
    dImg(iI, :, :) = permute(dLine, [3, 1, 2]);
end

% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Create axes and image for selection
hA = axes(...
    'Units'     , 'pixels', ...
    'Position'  , [1, 1, iWIDTH, iHeight], ...
    'Parent'    , hColormapFig, ...
    'Color'     , 'w', ...
    'XLim'      , [0.5 128.5], ...
    'YLim'      , [0.5 length(csColormaps) + 0.5]);

image(dImg, 'Parent',  hA);

axis(hA, 'off');
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Handle GUI interaction
iLastInd = 0;
uiwait(hColormapFig); % Wait until the uiresume function is called (happens when mouse button is pressed, see creation of the figure above)

try % Button was pressed, return the amount of selected panels
    dPos = get(hA, 'CurrentPoint');
    iInd = round(dPos(1, 2));
    sColormap = csColormaps{iInd};
    delete(hColormapFig); % close the figure
catch %#ok<MRCH> % if figure could not be deleted (dialog aborted), return [0 0]
    sColormap = 'gray';
end
% -------------------------------------------------------------------------


% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION fColormapMouseMoveFcn (nested in fColormapSelect)
% * *
% * * Determine whether axes are linked
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
    function fColormapMouseMoveFcn(hObject, eventdata)
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % Determine over which colormap the mouse pointer is located
        dPos = get(hA, 'CurrentPoint');
        iInd = round(dPos(1, 2));
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % Update the figure's colormap if desired
        if iInd ~= iLastInd
            set(hText, 'String', csColormaps{iInd});
            iLastInd = iInd;
        end
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION fColormapMouseMoveFcn
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

end
% =========================================================================
% *** END FUNMRION fColormapSelect (and its nested functions)
% =========================================================================


% =========================================================================
% *** FUNMRION fSelectEvalFcns
% ***
% *** Lets the user select the eval functions for evaluation
% ***
% =========================================================================
function csFcns = fSelectEvalFcns(csActive, sPath)
% return;
iFIGUREWIDTH = 300;
iFIGUREHEIGHT = 400;
iBUTTONHEIGHT = 24;

csFcns = 0;
iPos = get(0, 'ScreenSize');

SDir = dir([sPath, filesep, '*.m']);
lActive = false(length(SDir), 1);
csNames = cell(length(SDir), 1);
for iI = 1:length(SDir)
    csNames{iI} = SDir(iI).name(1:end-2);
    for iJ = 1:length(csActive);
        if strcmp(csNames{iI}, csActive{iJ}), lActive(iI) = true; end
    end
end

% -------------------------------------------------------------------------
% Create figure and GUI elements
hF = figure( ...
    'Position'              , [(iPos(3) - iFIGUREWIDTH)/2, (iPos(4) - iFIGUREHEIGHT)/2, iFIGUREWIDTH, iFIGUREHEIGHT], ...
    'WindowStyle'           , 'modal', ...
    'Name'                  , 'Select Eval Functions...', ...
    'NumberTitle'           , 'off', ...
    'KeyPressFcn'           , @SelectEvalCallback, ...
    'Resize'                , 'off');

hList = uicontrol(hF, ...
    'Style'                 , 'listbox', ...
    'Position'              , [1 iBUTTONHEIGHT + 1 iFIGUREWIDTH iFIGUREHEIGHT - iBUTTONHEIGHT], ...
    'String'                , csNames, ...
    'Min'                   , 0, ...
    'Max'                   , 2, ...
    'Value'                 , find(lActive), ...
    'KeyPressFcn'           , @SelectEvalCallback, ...
    'Callback'              , @SelectEvalCallback);

hButOK = uicontrol(hF, ...
    'Style'                 , 'pushbutton', ...
    'Position'              , [1 1 iFIGUREWIDTH/2 iBUTTONHEIGHT], ...
    'Callback'              , @SelectEvalCallback, ...
    'String'                , 'OK');

uicontrol(hF, ...
    'Style'                 , 'pushbutton', ...
    'Position'              , [iFIGUREWIDTH/2 + 1 1 iFIGUREWIDTH/2 iBUTTONHEIGHT], ...
    'Callback'              , 'uiresume(gcf);', ...
    'String'                , 'Cancel');
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% Set default action and enable gui interaction
sAction = 'Cancel';
uiwait(hF);
% -------------------------------------------------------------------------

% -------------------------------------------------------------------------
% uiresume was triggered (in fMouseActionFcn) -> return
if strcmp(sAction, 'OK')
    iList = get(hList, 'Value');
    csFcns = cell(length(iList), 1);
    for iI = 1:length(iList)
        csFcns(iI) = csNames(iList(iI));
    end
end
try %#ok<TRYNC>
    close(hF);
end
% -------------------------------------------------------------------------


% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * *
% * * NESTED FUNMRION SelectEvalCallback (nested in fSelectEvalFcns)
% * *
% * * Determine whether axes are linked
% * *
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =


    function SelectEvalCallback(hObject, eventdata)
        if isfield(eventdata, 'Key')
            switch eventdata.Key
                case 'escape', uiresume(hF);
                case 'return'
                    sAction = 'OK';
                    uiresume(hF);
            end
        end
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        % React on action depending on its source component
        switch(hObject)
            
            case hList
                if strcmp(get(hF, 'SelectionType'), 'open')
                    sAction = 'OK';
                    uiresume(hF);
                end
                
            case hButOK
                sAction = 'OK';
                uiresume(hF);
                
            otherwise
                
        end
        % End of switch statement
        % - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        
        
    end
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
% * * END NESTED FUNMRION SelectEvalCallback
% = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =

end
% =========================================================================
% *** END FUNMRION fSelectEvalFcns (and its nested functions)
% =========================================================================


