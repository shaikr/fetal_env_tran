ppath = '/Users/michaelbraginsky/Dropbox (Aidoc)/Michael Leo/Data for thesis/trainedMasks';
d = dir(fullfile(ppath, '*.mat'));
for i = 2:length(d)
    m = load(fullfile(ppath, d(i).name));
    maskreturn = m.maskreturn;
    maskreturn = maskreturn(33:end-32, 33:end-32, 3:end-2);
    save(fullfile(ppath, d(i).name), 'maskreturn');
end


fetals = {'78','255', '222','180'};
for i = 1:length(fetals)
    mrs = MRscan(fetals{i});
    mrs.masks{4} = mrs.masks{2};
    mrs.roitexts{4} = 'Corrected from initialization';
    oldmrs = load(fullfile('/Users/michaelbraginsky/Downloads/', [fetals{i} '.mat']));
    mrs.roitexts{2} = 'Test';
    mrs.masks{2} = oldmrs.masks{2};
    mrs.masks{10} = oldmrs.masks{2};
    mrs.roitexts{10} = 'Initialization';
    mrs.roitexts{3} = 'gt';
    mrs.saveMRscan;
end