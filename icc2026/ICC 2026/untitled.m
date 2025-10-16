I = imread('TEST2.jpeg');
if size(I,3)==3, I = rgb2gray(I); end

% 1) Invertir (trazos negros -> brillantes) y mejorar contraste
Iinv = imcomplement(I);
Ieq  = adapthisteq(Iinv,'ClipLimit',0.01);

% 2) Binarizar (foreground brillante)
BW = imbinarize(Ieq);    % prueba también 'adaptive' si la iluminación varía

% 3) Quedarse sólo con trazos GRUESOS usando distancia euclídea
D = bwdist(~BW);         % distancia al fondo (≈ semianchura del trazo, en px)
r = 1;                 % <-- umbral de grosor en píxeles (ajusta 1.6–2.5)
BW_thick = D > r;

% 4) Limpieza y conexión
BW_thick = bwareaopen(BW_thick, 200);       % quita motas
BW_thick = imclose(BW_thick, strel('disk',2));
BW_thick = imdilate(BW_thick, strel('disk',1));

% 5) (Opcional) quedarte sólo con el componente mayor
CC = bwconncomp(BW_thick);
if CC.NumObjects>0
    stats = regionprops(CC,'Area');
    [~,idx] = max([stats.Area]);
    mask = false(size(BW_thick));
    mask(CC.PixelIdxList{idx}) = true;
else
    mask = BW_thick;
end

% 6) (Opcional) esqueleto del patrón
skel = bwmorph(mask,'skel',Inf);
skel = bwmorph(skel,'spur',5);

imshow(mask); title('Patrón aislado');
figure; imshow(skel); title('Esqueleto del patrón');
