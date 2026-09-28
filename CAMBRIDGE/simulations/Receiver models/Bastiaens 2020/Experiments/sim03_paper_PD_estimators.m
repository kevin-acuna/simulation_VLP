addpath(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
cambridge_setup();
base=system_parameters();
base.environment.x_m=[-0.4 0 0.4];
base.environment.y_m=0;
base.environment.z_m=[0.2 0.8 1.4];
experiment=struct('device','PDA100A2','truth_family','SQ','outer_fov_deg',90, ...
    'K',5,'tilt_deg',20,'azimuth_offset_deg',0,'budget','per_orientation', ...
    'sample_values',[100 1000 10000],'trials',500,'seed',20260927,'pose_std_deg',0);
experiment.methods={'joint_nls','profile_nls','ratio_gls','ratio_wls','cosine_NLS_mismatch'};
experiment.solver=struct('starts',3);
style=ieee_plot_style();
transcript=evalc('pd_print_settings(base,experiment);'); fprintf('%s',transcript);
result=study_pd_estimators(base,experiment);
transcript=[transcript evalc('disp(result.model_table);')];
result=pd_paper_save(result,'estimators',transcript);
figures=plot_pd_estimators(result,style);
rx_export_figures(figures,result.output_directory,style);
