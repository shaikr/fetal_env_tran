function [imdb] = genImdbFCN(label,ppfunc,varargin)
%% GENIMDBBYLABELFCN recieves texual label, postprocessing function handle
%  and varargin option for the slices and labels it creates.
%  The function exctracts the data and calculates the labels
%  on the scans it finds relevant, saves it to the disk and generates an
%  imdb
%
%  According to the label, the function retreives all CTscans with that label and
%  the ROIs where this label appears. It applies the post processing function on matching
%  ROI masks to create the labels for training. After label generation,
%  all of the scan's slices are saves in files together with the labels.
%  In the end, and imdb struct is generated and saved in the given folder.
%
%  As agreed upon - if the file size does not divide the total amount of
%  slices in a scan THESE SLICES WILL NOT BE SAVED.
%  I.e. - residual slices (top of the head) are discarded in this case.
%
%   varargin opts:
%               'destfolder':   This keyword argument MUST be passed to the
%                               function - this is where the data will be
%                               saved.
%                               Example: 'destfolder', 'c:\MyFolder'
%               'kernel':       the kernel with which the block in the mask is selected.
%                               Example: 'kernel',[zeros(10,32);ones(12,32);zeros(10,32)]
%                               would make sure that a block is seleceted if
%                               the 12 middle rows of the block are all in the mask
%               'lo_ratio', 'hi_raio': For every patch in the image -
%                               If less than 'lo_ratio' of the kernel's
%                               voxels are in the mask - this is a negative
%                               example. If more than 'hi_ratio' - this is
%                               a positive example. If between - this is an
%                               ambiguous example
%                               Example: 'lo_ratio', 0.3, 'hi_ratio', 0.4
%               'ambig':        True if ambiguous samples are to be labeled
%                               as ambiguous (label 0). If flase -
%                               ambiguous labels are considered as
%                               negative.
%               'normalizewindow':
%                               The window for normalization of the data.
%                               every scan c will go through
%                               imnormalize(c,normalizewindow) before being
%                               saved to the disk.
%               'filesize':     How many slices to put in every file
%                               (defualt is 1). Example: 'filesize',5
%               'naming_conv':  Naming convention for the files in the DB.
%                               This is a string that must contain exactly
%                               one '%d' in it for the index of the file.
%               'uidsToFilter': a list of UIDs out of which you want
%                               to take the blocks. Use it to save time
%                               instead of searching all of the DB.
%               'append':       boolean that specifies wheter
%                               to append the output to existing
%                               imdb in the destination folder or overwrite
%                               the folder's contents.
%               'valuids':      UIDs specifically chosen to be in the
%                               validation set of the imdb.
%                               If given an empty list - 30% will be taken
%                               randomly to be the validation set.
%               'poolfactor':   For FCN training you need the label to be
%                               the size of the net's output calculated on
%                               an entire slice. therefore when you save
%                               the label - you need to know how many
%                               pooling layers the net has. for example of
%                               there are 3 layers the pooling factor is 8
%                               and the label will be taken in stride of 8.
%               'version':      string to append to imdb filename to
%                               specify the version of ths imdb.
%               'ppfunc':       post processing function that will be
%                               applied over the ground truth mask - useful
%                               to remove small irrelevant blobs from the
%                               ground truth

%
%               Defaults: ratio = 1, filesize = 1, uidsToFilter =
%                         empty, mode = overwrite.
%
%
%   Syntax example:
%   kernel = zeros(64, 64);
%   kernel(25:40,25:40) = 1;
%   imdb = genIMDBByLabelFCN('hyperdense',@hyperdensePostProc,...
%    'lo_ratio',0.5, 'hi_ratio', 0.5...
%    'kernel',kernel, 'destfolder','c:\myFolder');
%
%   Syntax example for speedup:
%
%  kernel = zeros(64, 64);
%  kernel(25:40,25:40) = 1;
%  [uidlist ~] = filterByLabel('hyperdense');
%  imdb = genIMDBByLabelFCN(...
%    'hyperdense',@hyperdensePostProc,...
%    'hi_ratio',0.4, 'lo_ratio', 0.2,...
%    'kernel',kernel, 'destfolder','c:/tmp.deleteme',...
%    'uidsToFilter',uidlist,'append',0);
%
%   and then you can call getBlocksByFilter again and it will save the time of
%   filterByLabel.
%
%
% @TailorMed 2016
% TODO do canonization on the fly and load data beforeahnd

myOpts = parseVarargin(varargin);


myOpts = updateDefaults(myOpts,...
    'uidstofilter',[],'naming_conv',DEFAULT_NAMING_CONV,...
    'valuids',{},'version','1','srcfolder',[], 'ppfunc' , [], ...
    'hi_ratio' , .5 , 'lo_ratio' , .5, 'append' ,  0 , 'ambig' , 0 , 'filesize' , 1);
checkArgs(myOpts);

if myOpts.append
    imdb = load(fullfile(myOpts.destfolder,'imdb.mat'));
    checkIMDBandOpts(imdb, myOpts);
else
    imdb = init_imdb(myOpts);
end

savefname = sprintf('imdb_ver_%s.mat',myOpts.version);

disp(['genImdbFCN: running filterByLabel on label "'...
    label '" ']);
if ~isempty(myOpts.uidstofilter)
    disp(['filtering out of ' num2str(length(myOpts.uidstofilter))...
        ' UIDs']);
end
%% Get Uids of scans to generate labels from
[uids_pos,maskNums] = filterByLabel(label,myOpts.uidstofilter,myOpts.srcfolder);

%unite the masks so we don't label positive blocks as negative by accident
%If A is a matrix or array, then C = A(ia) and A(:) = C(ic).
[unique_uids_pos, ~ ,ic] = unique(uids_pos);
unique_uids_pos = unique_uids_pos';
unique_uids = unique(myOpts.uidstofilter);

intersecting = util.cell.cellStringIntersect(imdb.meta.uids,unique_uids);
if numel(intersecting)>0
    error('some of the given uids already appear in the imdb');
end

disp(['genImdbFCN: found ' num2str(length(uids_pos))...
    ' scans, out of which '...
    num2str(length(unique_uids_pos)) ' are unique']);

if myOpts.append
    if isempty(imdb.images.filenums)
        uid_lo_ind = 0;
    else
        uid_lo_ind = numel(imdb.images.filenums);
    end
else
    uid_lo_ind = 0;
end

%% Iterate over scans
imdb.meta.maxslicesize = [0 0];
inputSize = myOpts.kernel;
if numel(inputSize) > 3
    inputSize  = size(inputSize);
end
if numel(inputSize) == 2
    inputSize(3) = 1;
end

tic

for i = 1:length(unique_uids)
    fprintf('Scan %d/%d, uid: %s - exctracting slices\n',...
        i, length(unique_uids),unique_uids{i});
    
    fname = getScanFilename ( myOpts.srcfolder , unique_uids{i} );
    cts = CTscan(fname);
    
    maskIdx = find(ismember(unique_uids_pos,unique_uids{i}));
    if ~isempty(maskIdx)
        maskIdx = maskNums(ic == maskIdx);
    end
 
    [ mask , volume ] = getVolume( cts , maskIdx );
    if ~isempty(myOpts.ppfunc)
        mask = myOpts.ppfunc(mask, volume);
    end
    
    sz = size(volume);
    imdb.meta.maxslicesize = max(imdb.meta.maxslicesize, [sz(1) sz(2)]);
    
    [ downSampledLabel ] = getFCNLabelWithKernel( mask , myOpts.kernel , myOpts.poolfactor , myOpts );
    
    fprintf('saving uid %d\n' , i+uid_lo_ind);
    destfolder = fullfile(myOpts.destfolder,unique_uids{i});
    
    [numWrittenFiles, writtenFileSize, writtenFilenames] = writeToDiskFCN(destfolder ,  volume, mask , downSampledLabel , inputSize , myOpts);
    
    toc
    % append to imdb
    imdb.meta.uids = cat(1,imdb.meta.uids,unique_uids{i});
    imdb.images.filenums = [imdb.images.filenums ; numWrittenFiles];
    imdb.images.totalimages = [imdb.images.totalimages ...
        numWrittenFiles*writtenFileSize];
    imdb.images.filenames = cat(1,imdb.images.filenames,...
        writtenFilenames);
    
    if ~isempty(myOpts.valuids) && any2(match(myOpts.valuids,unique_uids{i}))
        imdb.images.set = cat(1,imdb.images.set,2*ones(numWrittenFiles,1));
    else
        %% TODO make this randomize the validation set here and not in the end,
        %  so if the run is stopped in the middle then there is a
        %  viable set to the DB.
        imdb.images.set = cat(1,imdb.images.set,ones(numWrittenFiles,1));
    end
    
    save(fullfile(myOpts.destfolder,savefname),'-struct','imdb');
end

if isempty(myOpts.valuids)
    imdb = randomizeValSet(imdb);
    save(fullfile(myOpts.destfolder,savefname),'-struct','imdb');
end

alignBlockSizes(imdb, inputSize , myOpts);

toc
fprintf('genIMDBByLabelFCN done.\n');
end

function [numFiles, fileSize, writtenFilenames] = writeToDiskFCN(destfolder , vol , label , downSampledLabel , inputSize , opts)
%   WRITETODISK writes the data to files in TailorMed's patch file format
%
%   writes ONLY FULL CHUNKS of opts.filesize blocks in each file (default is
%   25 blocks/file). numFiles should be equal to
%   floor(length(label)/opts.filesize)
%

if ndims(vol) < 4
        vol = reshape(vol, size(vol,1) , size(vol,2) , 1, size(vol,3) );
end
    
kernelDepth = inputSize(3);
fileSize = opts.filesize;

numFiles = floor( (size(label,3) +1 - kernelDepth)...
    / opts.filesize) ;

fprintf('Saving in %d files... ',numFiles);

if ~isdir(destfolder)
    mkdir(destfolder);
end

writtenFilenames = cell(numFiles,1);
h = waitbar(0,sprintf('Saving in %d files...',numFiles));
sliceIdx = 1;
for k = 1:numFiles
    if mod (k,10) == 1
        waitbar(k/numFiles,h);
    end
    tmp.Blocks = zeros([size(vol,1) size(vol,2) kernelDepth fileSize]);
    tmp.SliceInds = zeros([kernelDepth 1 1 fileSize]);
    [ ~ , tmp.uid ] = fileparts(destfolder);
    for kk = 1:fileSize
        tmp.Blocks(:,:,:,kk) = ...
            imnormalize(vol(:,:,:,sliceIdx:sliceIdx+kernelDepth-1), ...
            opts.normalizewindow);
        tmp.Blocks = single(tmp.Blocks);
        tmp.FullLabels(:,:,:,kk) = label(:,:,sliceIdx);
        
        tmp.Labels(:,:,:,kk) = ...
            downSampledLabel(:,:,sliceIdx);
        tmp.SliceInds(:,:,:,kk) = sliceIdx:(sliceIdx+kernelDepth-1);
        sliceIdx = sliceIdx+1;
    end
    ftowrite = fullfile(destfolder,sprintf(opts.naming_conv,k));
    writtenFilenames{k} = ftowrite;
    save(ftowrite,'-struct','tmp');
end
close(h);
end

function naming_conv = DEFAULT_NAMING_CONV()
naming_conv = '%d.mat';
end

% function cod = RESIDUE_UID_CODE()
%     cod = randi([1e06 1e07]);
% end

function ok = checkIMDBandOpts(imdb,myOpts)

if isfield(myOpts,'naming_conv') &&...
        ~strcmp(imdb.meta.naming_conv,myOpts.naming_conv)
    error(['given naming convention should match the existing' ...
        'naming convention in the dest folder']);
end

if myOpts.filesize~=imdb.meta.filesize
    error(['given filesize ' num2str(myOpts.filesize) ...
        'does not match existing file size in the DB '...
        'which is ' num2str(imdb.filesize)]);
end

if myOpts.normalizewindow~=imdb.meta.normalizewindow
    error(['given normalization window ' num2str(myOpts.normalizewindow) ...
        'does not match existing window in the DB '...
        'which is ' num2str(imdb.noemalizeWindow)]);
end

if myOpts.ambig~=imdb.meta.ambig
    error(['given ambig ' myOpts.ambig ...
        'does not match existing ambig in the DB '...
        'which is ' imdb.ambig]);
end

if myOpts.kernel ~= imdb.meta.kernel
    error('given kernel does not match existing kernel in the DB ');
end

ok = true;

end

function imdb = init_imdb(myOpts)
ppfunc = myOpts.ppfunc;
imdb.images = [];
imdb.images = updateDefaults(imdb.images,...
    'filenums',[],...
    'totalimages',[],...
    'filenames',[],...
    'mean',0,...
    'set',[] );
imdb.meta = myOpts;
imdb.meta = updateDefaults(imdb.meta,...
    'uids',{},...
    'sets',{'train' 'val' 'test'},...
    'ppfunc',ppfunc,...
    'dataMean',0,...
    'subtractMean',false,...
    'creationtime',datetime('now'));
% The mean calculation and subtraction is not implemented yet
% here, that's why subtractMean is hard-coded to false. in the
% future we can make it optional...
end


function [ok] = checkArgs(myOpts)

if myOpts.lo_ratio > myOpts.hi_ratio
    error(['genIMDBByLabelFCN: lo_ratio' ...
        ' %f cant be bigger than hi_ratio %f ...'],...
        myOpts.lo_ratio, myOpts.hi_ratio );
end

if ~arefields(myOpts,'destfolder','filesize',...
        'normalizewindow','append', 'ambig')
    error('genIMDBByLabelFCN: opts has missing fields');
end

oldfname = fullfile(myOpts.destfolder,'imdb.mat');
if exist(oldfname,'file') && ~myOpts.append
    warning(['imdb.mat already exists in dir, '...
        'renaming old imdb']);
    s = sprintf('imdb_old_%d.mat',randi(10e7));
    newfname = fullfile(myOpts.destfolder,s);
    movefile(oldfname,...
        newfname);
end

if ~isfield(myOpts,'valuids') || isempty(myOpts.valuids)
    warning(['No UIDs are specified as validation.' ...
        ' Choosing validation randomly.']);
end

ok = true;
end

function out_imdb = randomizeValSet(in_imdb)
out_imdb = in_imdb;
numFiles = numel(out_imdb.images.set);

out_imdb.images.set = ones(numFiles,1);

test_files = randperm(numFiles);
test_files = test_files(1:round(numFiles*0.3));

out_imdb.images.set(test_files) = 2;
end


function alignBlockSizes(imdb,inputSize , opts)
% this function makes sure that all the blocks in the FCN has the same size
% by padding the image with 0's
n = numel(imdb.images.filenames);
h = waitbar(0,sprintf('canonizing slice size of %d files',n));

for k=1:n
    if mod(k,10) == 1
        waitbar(k/n,h);
    end
    fname = imdb.images.filenames{k};
    dataMat = load(fname);
    sz = size(dataMat.Blocks);
    lsz = size(dataMat.Labels);
    sdiff = [imdb.meta.maxslicesize-sz(1:2) 0];
    sls = smallerLabelSize(imdb.meta.maxslicesize,...
        opts.poolfactor, inputSize,true);
    smalldiff = [sls-lsz(1:2) 0];
    dataMat.Blocks = padarray(dataMat.Blocks,sdiff,0,'post');
    dataMat.FullLabels = padarray(dataMat.FullLabels,sdiff,0,'post');
    dataMat.Labels = padarray(dataMat.Labels, smalldiff, 0, 'post');
    save(fname,'-struct','dataMat');
end
close(h);
end

function sls = smallerLabelSize(fullLabelSize,poolfactor,inputsize,islabelpadded)

sz = fullLabelSize;
if islabelpadded
    limit = [sz(1)-inputsize(1) + 1 , sz(2)-inputsize(2) + 1];
else
    limit = sz;
end
pf = poolfactor;
sls = ceil(limit/pf);

end

function [ mask , volume ] = getVolume( cts , maskIdx )
volume = cts.volume;
mask = zeros(size(volume));

if ~isempty(maskIdx) % if the scan has a positive label
    
    % unite all the masks in the scan into one mask of
    % positively labeled voxels.
    % These are the mask nums of the current UID
    tmpMaskNums = maskIdx;
    
    for k=1:length(tmpMaskNums)
        mask = mask | cts.masks{tmpMaskNums(k)};
    end
    
end
end

function fname = getScanFilename ( srcfolder , unique_uid)
if isempty(srcfolder)
    fname = unique_uid;
else
    fname = fullfile(srcfolder,[string2hash(unique_uid) '.mat']);
end
end