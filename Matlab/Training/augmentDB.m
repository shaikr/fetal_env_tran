function uidlist = augmentDB(datadir)

d = dir(fullfile(datadir, '*.mat'));
dest = fullfile(datadir, 'augmented\');
if ~exist(dest,'file')
    mkdir(dest);
end
uidlist = cell(0);
for i = 1:length(d)
    fname = fullfile(datadir, d(i).name);
    cts = CTscan(fname);
    for k = 1:2:7
        for l = 1:2:7
            if k == 1 && l == 1
                continue;
            end
            ctsnew = cts.clone;
            ctsnew.volume = offsetVol(ctsnew.volume,k,l);
            for m=1:10
                if m~=3
                    ctsnew.masks{m} = [];
                else
                    ctsnew.masks{3} = offsetVol(ctsnew.masks{3},k,l);
                end
            end
            ctsnew.UID = [ctsnew.UID 'offset-' num2str(k) '-' num2str(l)];
            ctsnew.saveCTscan(dest);
            uidlist{end+1} = ctsnew.UID;
            disp(length(uidlist));
        end
    end
    
    for angle = -5:5
        if angle == 0
            continue;
        end
        
        ctsnew = cts.clone;
        ctsnew.volume = rotateVol(ctsnew.volume, angle);
        for m=1:10
            if m~=3
                ctsnew.masks{m} = [];
            else
                ctsnew.masks{3} = rotateVol(ctsnew.masks{3}, angle);
            end
        end
        ctsnew.UID = [ctsnew.UID 'rotate-' num2str(angle)];
        ctsnew.saveCTscan(dest);
        uidlist{end+1} = ctsnew.UID;
        disp(length(uidlist));
    end
end

function vol = offsetVol(vol, offsetRow, offsetCol)
vol = vol(offsetRow:end, offsetCol:end, :);

function vol = rotateVol(vol, angle)
vol = imrotate(vol, angle, 'nearest','crop');