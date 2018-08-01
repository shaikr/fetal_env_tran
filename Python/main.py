import numpy as np
import scipy.io as sio
import os
from viewer import multi_slice_viewer
from utils import getFetalFolder
#import keras

A = sio.loadmat(r'C:\Users\Shai\Documents\MSc\Project\FromMichael\Fetal envelope\MRscans\78.mat')
print(A.keys())
print(A['UID'])

im3d = A['volume']
gt = A['masks'][0, 2]
seg = A['masks'][0, 9]
print(im3d.shape)
#multi_slice_viewer(im3d)

p = getFetalFolder('MRscans')
l = os.listdir(p)
cnt = 0
for x in l:
    A = sio.loadmat(os.path.join(p, x))
    if A['masks'][0, 2].sum() == 0:
        cnt = cnt + 1
        print(f'Empty gt in scan {x}')
print(f'No gt in {cnt} mris')


