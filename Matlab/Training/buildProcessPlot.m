function buildProcessPlot(mrs, ROIlog, samefigure, name, color, initmask)

if ~exist('samefigure', 'var')
    samefigure = 0;
end
if ~samefigure
    figure
else
    hold on
end

groundT = mrs.masks{3};
if ~exist('initmask', 'var')
    initmask = zeros(size(groundT));
end
if sum2(groundT) == 0
    error(['Empty ground truth in MR ' mrs.UID]);
end
if ~isempty(ROIlog)
    buildAxis(groundT, ROIlog, name, color, initmask);
end
legend('show')


function buildAxis(groundT, ROIlog, type, color, newMask)
xAdd = [];
yAdd = [];
xRem = [];
yRem = [];
xTrain = [];
yTrain = [];
leg = cell(0);
timeCount = 0;



for j = size(groundT, 3):-1:1
    if ~isempty(find(groundT(:,:,j),1))
        lastSlice = j;
        break;
    end
end

for j = 1:size(groundT, 3)
    if ~isempty(find(groundT(:,:,j),1))
        firstSlice = j;
        break;
    end
end

numOfLogs = length(ROIlog);
h = waitbar(0, 'Building plot...');
for i = 1:length(ROIlog)
    waitbar(i/numOfLogs);
    if (ROIlog{i}.sliceNum > lastSlice) || (ROIlog{i}.sliceNum < firstSlice)
        continue;
    end
    timeCount = timeCount + ROIlog{i}.time;

    newMask(:,:,ROIlog{i}.sliceNum) = ROIlog{i}.slice;
    evalSeg = evaluateSegmentation(newMask, groundT,'VOD');
    x = timeCount;
    if isfield(evalSeg,'vod')
        y = evalSeg.vod;
    else
        y = 100;
    end
    switch lower(ROIlog{i}.type)
        case 'add'
            if ~ismember('Add',leg)
                leg = [leg {'Add'}];
            end
            xAdd = [xAdd x];
            yAdd = [yAdd y];
        case 'remove'
            if ~ismember('Remove',leg)
                leg = [leg {'Remove'}];
            end
            xRem = [xRem x];
            yRem = [yRem y];
            hold on
        case 'training'
            if ~ismember('Training',leg)
                leg = [leg {'Training'}];
            end
            xTrain = [xTrain x];
            yTrain = [yTrain y];
            hold on
    end
    
end
% if strcmpi(type, 'Our method')
%     headColor = 'r';
% else
%     headColor = 'b';
% %     xAdd = xAdd;
% %     xRem = xRem;
% end
plot(xAdd,yAdd,'o','Color', color, 'DisplayName',[type ' - adding']);
xlabel('Seconds');
ylabel('VOD');
title('Progress of VOD as function of time during fully manual segmentation'); 
hold on
plot(xRem,yRem, 's', 'Color', color,  'DisplayName',[type ' - removing']);
close(h);
hold on
plot(xTrain,yTrain, '*', 'Color', color,  'DisplayName',[type ' - training']);



% if length(leg) > 1
%     l = legend(leg{1},leg{2});
% else
%     l = legend(leg{1});
% end
