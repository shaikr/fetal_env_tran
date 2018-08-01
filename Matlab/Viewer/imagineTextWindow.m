function varargout = imagineTextWindow(varargin)
% IMAGINETEXTWINDOW MATLAB code for imagineTextWindow.fig
%      IMAGINETEXTWINDOW, by itself, creates a new IMAGINETEXTWINDOW or raises the existing
%      singleton*.
%
%      H = IMAGINETEXTWINDOW returns the handle to a new IMAGINETEXTWINDOW or the handle to
%      the existing singleton*.
%
%      IMAGINETEXTWINDOW('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in IMAGINETEXTWINDOW.M with the given input arguments.
%
%      IMAGINETEXTWINDOW('Property','Value',...) creates a new IMAGINETEXTWINDOW or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before imagineTextWindow_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to imagineTextWindow_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help imagineTextWindow

% Last Modified by GUIDE v2.5 03-Dec-2015 16:55:33

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @imagineTextWindow_OpeningFcn, ...
    'gui_OutputFcn',  @imagineTextWindow_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before imagineTextWindow is made visible.
function imagineTextWindow_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to imagineTextWindow (see VARARGIN)

% Choose default command line output for imagineTextWindow
handles.output = hObject;
% set(gcf, 'Units' , 'Normalized');
% set(gcf, 'Position', [1, 1, 100, 200]);
% Update handles structure

if length(varargin)>0
    handles.ROICallback = varargin{1};
else
    handles.ROICallback = [];
end

N_MASKS = 10;
handles.rois = [];
handles.texts = cell(1,N_MASKS);
handles.shownMasks = [];
set ( handles.roilist , 'String' ,'');
handles.ctscan = [];
guidata(hObject, handles);

if length(varargin)>1
    cts= varargin{2};
    handles = updateROI(hObject , cts );
end

updateMaskFcn = @(cts, idxToUpdate) updateROI(hObject, cts , idxToUpdate);
linkingFunction.updateWindow = updateMaskFcn;
roiClickedFcn = @(id) roiClicked ( hObject , id ) ;
linkingFunction.roiClickedFcn = roiClickedFcn;

roiContext = uicontextmenu(handles.figure1);
uimenu(roiContext, 'Label', 'Delete', 'Callback', @deleteROI);
set ( handles.roilist , 'UIContextMenu' , roiContext);

set(hObject,'UserData' ,linkingFunction);
guidata(hObject, handles);


% UIWAIT makes imagineTextWindow wait for user response (see UIRESUME)
% uiwait(handles.figure1);
function deleteROI(source,callbackdata)
handles = guidata(source);
maskval = get( handles.roilist , 'value' ) ;
if isempty(maskval) || maskval > numel(handles.shownMasks )
    return;
end
maskid = handles.shownMasks ( maskval ) ;
handles.ctscan.masks{maskid} = [];
updateROI( source );
fprintf('Deleted %d roi',1);
msdbox('deleted roi. Please scroll the volume for it to also update');


function handles = updateROI( hObject , cts , idxToUpdate)

handles = guidata(hObject);
N_MASKS = 10;
handles.texts = cell(1,N_MASKS);
handles.shownMasks = [];

if exist('cts' ,'var')
    handles.ctscan = cts;
else
    cts = handles.ctscan ;
end

texts = cts.roitexts;
handles.texts(1:length(texts)) = texts;
set ( handles.clinicaltext , 'String' , cts.clinicaltext);
guidata(hObject , handles);
if ~exist('idxToUpdate' ,'var') || isempty(idxToUpdate)
    idxToUpdate = 1:length(cts.masks);
end

% update masks
shownMasks = find ( cellfun(@(m) ~isempty(m)  , cts.masks) );
idxToUpdate = intersect ( idxToUpdate , shownMasks ) ;
for k = idxToUpdate
    slicesum = fun3( cts.masks{k} , @sum2  )  ;
    handles.rois(k).area = sum(slicesum);
    z = find(slicesum>0);
    
    meanSlice = mean(z);
    diffFromMean = abs ( z - round(meanSlice) ) ;
    [ ~ , minIdx ] = min(diffFromMean);
    if isempty(z)
        cts.masks{k} = [];
        shownMasks(shownMasks ==k ) = [];
    else
        handles.rois(k).meanSlice = z(minIdx);
        handles.rois(k).sliceRange = [ min(z) max(z) ];
    end
end

newString = '';

for k = shownMasks
    meanSlice = handles.rois(k).meanSlice;
    if isempty(meanSlice)
        meanSlice = 0;
    end
    
    sliceRange = handles.rois(k).sliceRange;
    if isempty(sliceRange)
        sliceRange = [ 0 0 ] ;
    end
    %     if ~isnan(meanslice)
    maskStr = maskStrFromId(k);
    newString = [ newString sprintf('%s roi - slice %d [%d-%d]\n' , maskStr,meanSlice, sliceRange)];
    %         newString = [ newString sprintf('%s roi \n' , maskStr)];
    %     end
end
handles.shownMasks = shownMasks;
if isempty(newString)
    %     newString = 'no rois';
else
    newString = newString(1:end-1); %remove last newline
end
set ( handles.roilist ,'String' , newString);
guidata(hObject, handles);
% update currently selected roi text
updateRoiText(handles);



function roiClicked( hObject , maskID )
if isempty(maskID)
    return;
end
handles = guidata(hObject);
newval = find( handles.shownMasks == maskID );

if isempty(newval)
    %     set( handles.roilist , 'value' , 1);
else
    set( handles.roilist , 'value' , newval);
    % update text
    updateRoiText(handles);
end
% 02.07.13 : Left fronto-parietal Hemorrhagic Stroke detected
% 02.07.13: Left Fronto-parietal Craniotomy
% 12.07.13: Follow up , No significant change
%  03.09.14 : Blood test
% Frequent complications

% --- Outputs from this function are returned to the command line.
function varargout = imagineTextWindow_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;





% --- Executes on selection change in roilist.
function roilist_Callback(hObject, eventdata, handles)
% hObject    handle to roilist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns roilist contents as cell array
%        contents{get(hObject,'Value')} returns selected item from roilist
if ~isempty(handles.ROICallback)
    handles.ROICallback(hObject, eventdata, handles)
end

updateRoiText(handles);

function updateRoiText(handles)
id = currentRoiID(handles);
if ~isempty(id)
    set ( handles.roitexts ,'String' , handles.texts{id} );
    infoString = sprintf('area %dpx' , handles.rois(id).area);
    set ( handles.roiinfo , 'String' , infoString ) ;
end

function id = currentRoiID(handles)
val = get ( handles.roilist , 'value' );
id = [];
if val <= length(handles.shownMasks)
    id = handles.shownMasks(val);%find ( val ==  );
end

% --- Executes during object creation, after setting all properties.
function roilist_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roilist (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function roitexts_Callback(hObject, eventdata, handles)
% hObject    handle to roitexts (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of roitexts as text
%        str2double(get(hObject,'String')) returns contents of roitexts as a double

id = currentRoiID(handles);
handles.texts{id} = get( handles.roitexts ,'String' );
handles.ctscan.roitexts = handles.texts;
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function roitexts_CreateFcn(hObject, eventdata, handles)
% hObject    handle to roitexts (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function clinicaltext_Callback(hObject, eventdata, handles)
% hObject    handle to clinicaltext (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.ctscan.clinicaltext = get ( hObject , 'String' ) ;
% Hints: get(hObject,'String') returns contents of clinicaltext as text
%        str2double(get(hObject,'String')) returns contents of clinicaltext as a double


% --- Executes during object creation, after setting all properties.
function clinicaltext_CreateFcn(hObject, eventdata, handles)
% hObject    handle to clinicaltext (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
