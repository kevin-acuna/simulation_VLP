function summary = gob_bound_summary(m,points,noise,dimensions,gainMode)
if nargin<4, dimensions = 3; end
if nargin<5, gainMode = 'known'; end
a = gob_information(m,points,noise,dimensions,gainMode); peb = a.peb;
summary = struct('peb_median_m',gob_quantile(peb,.5,false),'peb_p95_m',gob_quantile(peb,.95,false), ...
    'peb_max_m',max(peb),'fraction_peb_1cm',mean(peb<.01),'fraction_peb_10cm',mean(peb<.1), ...
    'fraction_full_rank',mean(a.rank==dimensions),'minimum_visible_5sigma',min(a.visible_5sigma));
end
