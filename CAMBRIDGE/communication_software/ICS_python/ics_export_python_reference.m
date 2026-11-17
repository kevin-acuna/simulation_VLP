function path = ics_export_python_reference(experiment,capture,result)
%ICS_EXPORT_PYTHON_REFERENCE Offline reference export; no instrument access.
% Run once in your working MATLAB folder, with existing successful variables.
% The Python port can decode these SAME samples with the SAME known TX packet.
assert(strcmp(capture.experimentSignature,experiment.signature), ...
    'ICS:ReferenceMismatch','Capture and prepared experiment do not match.');
packet=experiment.packet; core_config=experiment.cfg; plan=experiment.plan;
reference_capture=struct('YData',capture.YData,'XData',capture.XData, ...
    'FsCapture',capture.FsCapture,'capturedAt',capture.capturedAt);
expected_summary=table2struct(result.summary);
path=fullfile(pwd,'matlab_reference_for_python.mat');
assert(~isfile(path),'ICS:ReferenceExists', ...
    'Reference file exists. Rename or move it first to retain your earlier reference.');
save(path,'packet','core_config','plan','reference_capture','expected_summary','-v7');
fprintf('Python comparison reference saved: %s\n',path);
end
