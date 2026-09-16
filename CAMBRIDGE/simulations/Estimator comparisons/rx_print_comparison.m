function rx_print_comparison(p, normals, e)
fprintf('\nESTIMATOR COMPARISON: %s\n', strjoin(e.methods, ', '));
fprintf('K=%d, m_R=%g, Phi=%g deg, FOV=%g deg, P_t=%g W, A=%g mm^2\n', ...
    size(normals, 2), rx_receiver_order(p), p.transmitter.half_angle_power_deg, p.receiver.fov_deg, ...
    p.transmitter.power_W, p.receiver.area_m2*1e6);
fprintf('LED position=%s m; normal=%s; angular asymmetry=%g\n', mat2str(p.transmitter.position_m'), ...
    mat2str(p.transmitter.normal'), p.transmitter.pattern_asymmetry);
fprintf('ROI x=%s, y=%s, z=%s m\n', mat2str(p.environment.x_m), mat2str(p.environment.y_m), mat2str(p.environment.z_m));
fprintf('Noise variance=%g W^2/sample; budget=%s; N=%d; M_total=%d\n', p.noise.variance_W2, ...
    e.budget, p.acquisition.samples_per_orientation, p.acquisition.total_samples);
fprintf('Monte Carlo trials=%d per position; seed=%d; identical RSS data across all methods.\n', e.trials, e.seed);
fprintf('All methods assume complete visibility. No truth mask, room prior or RSS clipping is supplied.\n');
fprintf('Failed estimates keep their probability mass in CDFs; conditional RMSE is reported separately.\n');
end
