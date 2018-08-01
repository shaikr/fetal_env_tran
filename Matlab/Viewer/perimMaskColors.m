function colors = perimMaskColors(idx)
% defines color rgb values for maskColor enumartion
% @see maskColor

colors = [ 0 1 0 ; 1 0 0 ];
colors = [colors ; repmat([1 0 0], [8 1])];

% so that when the perimeter will be added to the mask we will get that the
% perimeter is independent of the mask color
colors = colors - maskColors;

if exist('idx' , 'var') && ~isempty(idx)
    colors = colors(idx,:);
end