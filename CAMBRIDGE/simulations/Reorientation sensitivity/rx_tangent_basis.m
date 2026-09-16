function E = rx_tangent_basis(n)
[~, index] = min(abs(n));
axis = zeros(3, 1);
axis(index) = 1;
a = axis-n*(n'*axis);
a = a/norm(a);
E = [a cross(n, a)];
end
