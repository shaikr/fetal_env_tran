function requestedPath = getFetalFolder(folderName)
%GETCTSCANPATH
%returns the path of the folder containing all CTscans

uname = getenv('username');
if strcmpi(uname, 'DaffyDell')
    baseFolder = 'C:\Users\DaffyDell\Dropbox\fetalEnv';
elseif strcmpi(uname, 'user')
    baseFolder = 'C:\Users\user\Dropbox\fetalEnv';
elseif strcmpi(uname, 'Mikey')
    baseFolder = 'C:\Users\Mikey\Dropbox (Aidoc)\fetalEnv';
elseif strcmpi(uname, 'dafi')
    baseFolder = 'C:\Users\dafi\Dropbox\fetalEnv';
elseif strcmpi(uname,'Elad Gut')
    baseFolder = 'C:\Users\Elad Gut\Dropbox\fetalEnv';
elseif strcmpi(uname, 'Michael')
    baseFolder = 'E:\Dropbox\Dropbox (Aidoc)\fetalEnv';
elseif strcmpi(uname, '')
    baseFolder = '/Users/michaelbraginsky/Dropbox (Aidoc)/fetalEnv';
else
    baseFolder = 'C:\Users\Michael\Dropbox (Aidoc)\fetalEnv';
end


if ~exist('folderName' ,'var')
    folderName = 'Data';
end


if exist(fullfile(baseFolder, folderName), 'file')
    
    requestedPath = [fullfile(baseFolder, folderName) filesep];
else
    error('No such folder exists');
end
