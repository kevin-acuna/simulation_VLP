function frontier = rx_feasible_tradeoffs(candidates)
feasible = candidates(candidates.Feasible, :);
feasible = sortrows(feasible, {'TotalSamples', 'Area_mm2', 'RMS_full_cm'});
[~, first] = unique([feasible.TotalSamples, feasible.Area_mm2], 'rows', 'stable');
feasible = feasible(first, :);
keep = true(height(feasible), 1);
for i = 1:height(feasible)
    dominates = feasible.TotalSamples<=feasible.TotalSamples(i) & feasible.Area_mm2<=feasible.Area_mm2(i) ...
        & (feasible.TotalSamples<feasible.TotalSamples(i) | feasible.Area_mm2<feasible.Area_mm2(i));
    keep(i) = ~any(dominates);
end
frontier = feasible(keep, {'BaseIndex', 'HalfAngle_deg', 'FOV_deg', 'K', 'Pattern', 'Budget', 'Area_mm2', ...
    'TotalSamples', 'RMS_full_cm', 'Worst_cm', 'TargetCoverage_percent', 'RequiredArea_mm2'});
end
