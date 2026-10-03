function out = gob_merge(left,right)
out = left; names = fieldnames(right);
for k = 1:numel(names), out.(names{k}) = right.(names{k}); end
end
