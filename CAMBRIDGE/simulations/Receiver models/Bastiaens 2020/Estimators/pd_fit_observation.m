function a = pd_fit_observation(a,y)
[value,a.reference]=max(y);
a.ratio_valid=value>0;
a.ratio_indices=[1:a.reference-1 a.reference+1:numel(y)];
a.ratio_target=nan(numel(y)-1,1);
a.ratio_covariance=nan(numel(y)-1);
if a.ratio_valid
    a.ratio_target=y(a.ratio_indices)/value;
    C=diag(a.variance(a.ratio_indices))+a.variance(a.reference)*(a.ratio_target*a.ratio_target');
    C=C/max(diag(C));
    a.ratio_covariance=C;
    a.ratio_cholesky=chol(C,'lower');
end
end
