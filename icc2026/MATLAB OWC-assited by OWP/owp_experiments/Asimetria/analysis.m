clc, clear all, close all

data = csvread('database.csv',1);

x = data(1:3:end,1);
y = data(1:3:end,2);
rss = data(1:3:end,6);

figure(1)
plot3(x,y,rss,'o')
grid minor

% Obtener la matrix
x_unique = unique(x);
y_unique = unique(y);
RSS = zeros(length(x_unique), length(y_unique));
for i = 1:length(x_unique)
    for j = 1:length(y_unique)
        idx = find(x == x_unique(i) & y == y_unique(j));
        if ~isempty(idx)
            RSS(i,j) = rss(idx);
        end
    end
end

RSS

error = RSS - RSS'