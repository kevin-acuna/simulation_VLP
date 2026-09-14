function result = rx_summarize_study(result)
raw = result.peb_m;
shape = size(raw);
shape = [shape(2:end), 1];
valid = isfinite(raw);
count = sum(valid, 1);
squared = raw.^2;
squared(~valid) = 0;
conditional = sqrt(sum(squared, 1)./count);
conditional(count==0) = NaN;
full = conditional;
full(count<size(raw, 1)) = Inf;
result.rms_full_m = reshape(full, shape);
result.rms_conditional_m = reshape(conditional, shape);
result.coverage = reshape(count/size(raw, 1), shape);
result.nonregular_fraction = reshape(sum(isnan(raw), 1)/size(raw, 1), shape);
end
