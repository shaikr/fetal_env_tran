import numpy as np


def evaluate_segmentation(seg, gt, measures=['VOD']):
    assert all(seg.shape == gt.shape), "GT and segmentation image are different sizes"

    addition = seg + gt
    seg_full_vol = np.sum(seg)
    gt_full_vol = np.sum(gt)
    intersection = np.sum(addition > 1)
    union = np.sum(addition > 0)
    eval_dict = {}
    measures = [x.lower() for x in measures]
    flag_issing = np.sum(gt) == 0 or np.sum(seg) == 0
    if flag_issing:
        print('NOTE - either the segmentation or the gt are empty')

    # All measures should be low!!!
    if 'vd' in measures and not flag_issing:
        eval_dict['vd'] = np.abs(seg_full_vol - gt_full_vol) / gt_full_vol
    if 'vod' in measures and not flag_issing:
        eval_dict['vod'] = 1-intersection / union
    if 'dice' in measures and not flag_issing:
        eval_dict['dice'] = 1 - (2 * intersection / (seg_full_vol + gt_full_vol))
    if 'usr' in measures and not flag_issing:
        eval_dict['usr'] = (seg_full_vol - intersection) / seg_full_vol
    if 'osr' in measures and not flag_issing:
        eval_dict['osr'] = (gt_full_vol - intersection) / gt_full_vol
    tmp_subtract = seg - fn  # anything that 1, was a false detection, anything that is -1, was missed
    if 'fp' in measures:
        eval_dict['fp'] = np.sum(tmp_subtract == 1)
        eval_dict['fp_normed'] = eval_dict['fp'] / seg_full_vol # wrongly detected / all that was detected
    if 'fn' in measures:
        eval_dict['fn'] = np.sum(tmp_subtract == -1)
        eval_dict['fn_normed'] = eval_dict['fn'] / gt_full_vol # missed / how much we needed to discover

    return eval_dict