function out = gob_update(base, overrides)
out = base;
if nargin<2 || isempty(overrides)
    return
end
names = fieldnames(overrides);
for k = 1:numel(names)
    assert(isfield(base,names{k}),'gob:Parameter','Unknown parameter: %s',names{k});
    out.(names{k}) = overrides.(names{k});
end
end
