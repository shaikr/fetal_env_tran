function MRscanObj = loadMRscan(UID)
% LOADMRSCAN
% UID - MRscan UID to be loaded into MRscanObj
% flagAll - load all MRscans that are with this UID (possible
% when the same MRscan is registered to different MRs
% Path - when a specific path exists for the MRscan file

dirInfo = [];
path = getFetalFolder('MRscans');
if exist(UID, 'file')
    fullpath = UID;
    dirInfo = {''};
elseif exist([path UID '.mat'],'file')
    dirInfo = dir([path UID '.mat']); 
    fullpath = [path dirInfo(1).name];
end
%%
if (length(dirInfo) == 1)
        temp = load(fullpath);

    %     temp = temp.MRscan;
    MR = MRscan();
    MR = structToMRscan(MR, temp);
    MRscanObj = MR;
else
    MRscanObj = cell(0);
    for i = 1: length(dirInfo)
        MR = load([path dirInfo(i).name]);
        if strcmp(MR.getUID(), UID)
            MRscanObj{length(MRscanObj) + 1} = MR;
        end
    end
end
end