% Script para resetear posiciones en positions3D.txt basado en un archivo CSV
% Autor: Script generado automáticamente
% Fecha: 2024

clear; clc;

% Solicitar el nombre del archivo CSV
csv_filename = "data_20251218_134033.csv";

% Rutas de archivos
csv_path = fullfile('database3D', csv_filename);
positions_file = 'positions3D.txt';
output_file = 'positions3D_updated.txt';

% Verificar que el archivo CSV existe
if ~exist(csv_path, 'file')
    error('El archivo CSV no existe: %s', csv_path);
end

% Verificar que el archivo positions3D.txt existe
if ~exist(positions_file, 'file')
    error('El archivo positions3D.txt no existe');
end

fprintf('Leyendo archivo CSV: %s\n', csv_filename);

% Leer el archivo CSV
data = readtable(csv_path);

% Extraer posiciones únicas (x, y, z)
unique_positions = unique(data(:, {'x', 'y', 'z'}), 'rows');

fprintf('\n=== POSICIONES ÚNICAS ENCONTRADAS EN EL CSV ===\n');
fprintf('Total de posiciones únicas: %d\n\n', height(unique_positions));
fprintf('    X       Y       Z\n');
fprintf('---------------------------\n');
for i = 1:height(unique_positions)
    fprintf('%6.1f  %6.1f  %6.1f\n', unique_positions.x(i), unique_positions.y(i), unique_positions.z(i));
end

% Leer el archivo positions3D.txt
fprintf('\nLeyendo archivo positions3D.txt...\n');
fid = fopen(positions_file, 'r');
positions_data = {};
line_num = 0;
while ~feof(fid)
    line = fgetl(fid);
    if ischar(line)
        line_num = line_num + 1;
        positions_data{line_num} = line;
    end
end
fclose(fid);

% Contar posiciones con done=1 antes de resetear
count_before = 0;
for i = 1:length(positions_data)
    parts = strsplit(strtrim(positions_data{i}));
    if length(parts) == 4
        done_status = str2double(parts{4});
        if done_status == 1
            count_before = count_before + 1;
        end
    end
end

fprintf('Posiciones con done=1 ANTES del reseteo: %d\n', count_before);

% Resetear las posiciones que coinciden con las del CSV
fprintf('\nResetando posiciones a done=0...\n');
reset_count = 0;

for i = 1:length(positions_data)
    parts = strsplit(strtrim(positions_data{i}));
    if length(parts) == 4
        x_pos = str2double(parts{1});
        y_pos = str2double(parts{2});
        z_pos = str2double(parts{3});
        done_status = str2double(parts{4});
        
        % Buscar si esta posición está en las posiciones únicas del CSV
        match_found = false;
        for j = 1:height(unique_positions)
            if abs(x_pos - unique_positions.x(j)) < 0.01 && ...
               abs(y_pos - unique_positions.y(j)) < 0.01 && ...
               abs(z_pos - unique_positions.z(j)) < 0.01
                match_found = true;
                break;
            end
        end
        
        % Si hay coincidencia, resetear a 0
        if match_found
            positions_data{i} = sprintf('%.1f %.1f %.1f 0', x_pos, y_pos, z_pos);
            if done_status == 1
                reset_count = reset_count + 1;
            end
        end
    end
end

fprintf('Posiciones reseteadas de 1 a 0: %d\n', reset_count);

% Escribir el archivo actualizado
fprintf('\nEscribiendo archivo actualizado: %s\n', output_file);
fid = fopen(output_file, 'w');
for i = 1:length(positions_data)
    fprintf(fid, '%s\n', positions_data{i});
end
fclose(fid);

% Contar posiciones con done=1 después de resetear
count_after = 0;
for i = 1:length(positions_data)
    parts = strsplit(strtrim(positions_data{i}));
    if length(parts) == 4
        done_status = str2double(parts{4});
        if done_status == 1
            count_after = count_after + 1;
        end
    end
end

fprintf('\n=== RESUMEN ===\n');
fprintf('Posiciones con done=1 ANTES:   %d\n', count_before);
fprintf('Posiciones con done=1 DESPUÉS: %d\n', count_after);
fprintf('Diferencia (reseteadas):       %d\n', count_before - count_after);
fprintf('\nArchivo generado: %s\n', output_file);
fprintf('\nProceso completado exitosamente.\n');
