function [evaluation] = evaluateSegmentation(mask, groundT, varargin)
%% EVALUATESEGMENTATION Measures quality of segmentation with different metrics
%   Available metrics:
%     'VOD'  - Volume Overlap Difference 
%     'VD'   - Volume Difference
%     'DICE' - Dice Coefficient
%     'FP'   - False Possitive (returns how many voxels where wrongly detected)
%     'FN'   - False Negative (returns how many voxels where misdetected)               
%     'USR'  - Under Segmentation Ratio (which part of the mask is not within the GT)
%     'OSR'  - Over Segmentation Ratio (which part of the GT is not within the mask)
%
%   @TailorMed 2016

if ~all(size(mask) == size(groundT))
    error('Mask and Ground-Truth are of different sizes');
end

if ~exist('varargin','var') || isempty(varargin)
    varargin = [{'vod'},{'vd'},{'dice'},{'fp'},{'fn'},{'usr'},{'osr'}];
end

maskFullVol = sum2(logical(mask));
maskTotVol = sum2(mask);
GTVol = sum2(groundT);

if maskTotVol == 0 || GTVol == 0
    missingVol = 1;
else
    missingVol = 0;
end

matAddition = mask+groundT;
matIntersection = sum2(matAddition>1);
matUnion = sum2(matAddition>0);


                

evaluation = struct;
toPercent = 100;

for i = 1:length(varargin)
    switch lower(varargin{i})
        case 'vd'
            if ~missingVol
                VD = (abs(maskFullVol-GTVol)/GTVol) * toPercent;
                evaluation.vd = VD;
            end
        case 'vod'
            if ~missingVol
                VOD = (1-matIntersection/matUnion) * toPercent;
                evaluation.vod = VOD;
            end
        case 'dice'
            if ~missingVol
                DICE = (1-(2*matIntersection/(maskFullVol + GTVol))) * toPercent;
                evaluation.dice = DICE;
            end
        case 'usr'
            if ~missingVol
                usr = (maskFullVol-matIntersection) / maskFullVol * toPercent;
                evaluation.usr = usr;
            end
        case 'osr'
            if ~missingVol
                osr = (GTVol-matIntersection) / GTVol * toPercent;
                evaluation.osr = osr;
            end
        case 'fp'
            if maskTotVol > 0 && GTVol == 0
                evaluation.fp = maskTotVol;
            end
        case 'fn'
            if maskTotVol == 0 && GTVol > 0
                evaluation.fp = GTVol;
            end
    end
end

end

