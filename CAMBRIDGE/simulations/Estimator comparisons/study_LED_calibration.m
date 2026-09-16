function r = study_LED_calibration(p, e)
r.parameters = p;
r.experiment = e;
r.runs = cell(numel(e.true_asymmetries), 2);
rows = cell(size(r.runs));
for ie = 1:numel(e.true_asymmetries)
    truth = p;
    truth.transmitter.pattern_asymmetry = e.true_asymmetries(ie);
    normals = rx_cone_normals(e.K, e.tilt_deg);
    rx_print_comparison(truth, normals, e);
    for calibrated = 0:1
        assumed = truth;
        if ~calibrated
            assumed.transmitter.pattern_asymmetry = 0;
            assumed.transmitter.half_angle_power_deg = e.assumed_half_angle_deg;
        end
        run = rx_monte_carlo(truth, assumed, normals, e);
        r.runs{ie, calibrated+1} = run;
        rows{ie, calibrated+1} = addvars(run.table, repmat(e.true_asymmetries(ie), height(run.table), 1), ...
            repmat(logical(calibrated), height(run.table), 1), 'Before', 1, 'NewVariableNames', {'TrueAsymmetry', 'CalibratedPattern'});
    end
end
r.table = vertcat(rows{:});
end
