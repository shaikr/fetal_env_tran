import os

def getFetalFolder(folderName):

    folders_dict = {'DaffyDell' : r'C:\Users\DaffyDell\Dropbox\fetalEnv',
                    'user' : r'C:\Users\user\Dropbox\fetalEnv',
                    'Mikey' : r'C:\Users\Mikey\Dropbox (Aidoc)\fetalEnv',
                    'dafi' : r'C:\Users\dafi\Dropbox\fetalEnv',
                    'Elad Gut' : r'C:\Users\Elad Gut\Dropbox\fetalEnv',
                    'Michael' : r'E:\Dropbox\Dropbox (Aidoc)\fetalEnv',
                    '' : r'/Users/michaelbraginsky/Dropbox (Aidoc)/fetalEnv',
                    'Shai' : r'C:\Users\Shai\Documents\MSc\Project\FromMichael\Fetal envelope'}

    username = os.getenv('username')
    if username in folders_dict:
        return os.path.join(folders_dict[username], folderName)
    else:
        return os.path.join(folders_dict['Shai'], folderName)