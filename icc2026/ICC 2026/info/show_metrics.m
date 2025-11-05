% ======================
% Metrics
% ======================
% Input:
% est_pos (Npos,2)
% true_pos (Npos,2)

err = sqrt(sum((est_pos - true_pos).^2,2));
APE = mean(err);
RMSE = sqrt(mean(err.^2));
CDF_90 = prctile(err, 90);
fprintf('APE  : %.3f cm\n', APE*100);
fprintf('RMSE : %.3f cm\n', RMSE*100);
fprintf('CDF_90 : %.3f cm\n', CDF_90*100);

figure;
plot(true_pos(:,1), true_pos(:,2), '.k'); hold on;
plot(est_pos(:,1), est_pos(:,2), 'r.');
legend('ref','est');
xlabel('x [m]'); ylabel('y [m]'); axis equal; grid on;
xaxis([testbed.x(1)-0.2 testbed.x(2)+0.2])
yaxis([testbed.y(1)-0.2 testbed.y(2)+0.2])


% ======================
% Heatmap
% ======================

err_cm = err * 100;
cmax = prctile(err_cm, 95);   % avoid outliers
cmin = 0;

figure; hold on

plot(true_pos(:,1), true_pos(:,2), '.', 'Color', [0.3 0.3 0.3]);
scatter(est_pos(:,1), est_pos(:,2), 12, err_cm, 'filled', ...
    'MarkerFaceAlpha', 0.85);  % smooths the point

cmax=8;
colormap(turbo);
caxis([cmin cmax]);            
cb = colorbar; ylabel(cb, 'Error [cm]');
xlabel('x [m]'); ylabel('y [m]');
box on;
axis equal;
xlim([testbed.x(1)-0.1, testbed.x(2)+0.1])
ylim([testbed.y(1)-0.1, testbed.y(2)+0.1])