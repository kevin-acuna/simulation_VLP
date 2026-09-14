function value = gob_quantile(values,p,interpolate)
if nargin<3, interpolate = true; end
ordered = sort(values(:)); index = 1+(numel(ordered)-1)*p;
lo = floor(index); hi = ceil(index);
value = ordered(lo);
if interpolate && hi~=lo && ordered(lo)~=ordered(hi)
    value = ordered(lo)+(index-lo)*(ordered(hi)-ordered(lo));
end
end
