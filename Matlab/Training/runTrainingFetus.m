function runTrainingFetus(dbopts, trainopts, netInitFunc, optimizer)
%% runTraining runs a training using dbopts and trainopts
% defined by getBatch, initCNN , getIMDB
% initFunc is a function that returns a net and defines the 
% net architecture
% 
% use sandbox.runCNNdisk or sandbox.runCNNram to run
%
% @TailorMed 2016
%

%% Input validation and setting defaults

trainopts = updateDefaults(trainopts, 'prefetch',0);
if ~exist('optimizer', 'var')
    optimizer = 'adam';
end
if ~exist('netInitFunc','var')
    error('Missing net initialization function');
end

if trainopts.disk
    if ~isfield(dbopts,'datapath')
        error('Missing input: datapath field has to be provided');
    end
    if ~isfield(dbopts,'valuids')
        imdb = hemmc.getIMDBDisk(dbopts.datapath,'version',dbopts.version);
    else
        imdb = hemmc.getIMDBDisk(dbopts.datapath,'version',dbopts.version,'valuids',dbopts.valuids);
    end
else
    imdb = hemmc.getIMDB();
end

% --------------------------------------------------------------------
%                          Train
% --------------------------------------------------------------------

%% Run CNN

net = netInitFunc();

if ~arefields(trainopts,'numepochs','learningrate','batchsize')
    error('Missing training parameters');
else   
    net.meta.trainOpts.numEpochs = trainopts.numepochs;
    net.meta.trainOpts.learningRate = trainopts.learningrate;
    net.meta.trainOpts.batchSize = trainopts.batchsize;
end

batchFcn = trainopts.batchfcn;

if isa(net,'dagnn.DagNN')
    [~, ~] = cnn_train_dag(net, imdb, batchFcn , ...
        'expDir', trainopts.expdir, ...
        net.meta.trainOpts, ...
        'trainingFcn',optimizer ,...
        'batchSize', trainopts.batchsize, ...
        'gpus', trainopts.gpus) ;
else
    [~, ~] = cnn_train(net, imdb, batchFcn , ...
        'expDir', trainopts.expdir, ...
        net.meta.trainOpts, ...
        'errorFunction' , 'none' ,...
        'trainingFcn',optimizer ,...
        'batchSize', trainopts.batchsize, ...
        'gpus', trainopts.gpus) ;
end
