function im = draw_object(im, det, pattern, color)

det(1:4) = round(det(1:4));

mask = zeros(size(im));
    
h = det(4) - det(2) + 1;
w = det(3) - det(1) + 1;

ptn = imresize(pattern{det(5)}, [h w], 'nearest');

xrange = det(1):det(3);
yrange = det(2):det(4);

xi = find(xrange > 0 & xrange <= size(im, 2));
yi = find(yrange > 0 & yrange <= size(im, 1));

mask(yrange(yi), xrange(xi), 1) = (ptn(yi, xi) == 1) .* color(1);
mask(yrange(yi), xrange(xi), 2) = (ptn(yi, xi) == 1) .* color(2);
mask(yrange(yi), xrange(xi), 3) = (ptn(yi, xi) == 1) .* color(3);

im(mask > 0) = 0.1 .* im(mask > 0) + uint8(0.9 .* mask(mask > 0));

return;

box = zeros(size(im, 1), size(im, 2));

box(max(1, det(2)-1):max(1, det(2)+1), max(1, det(1)):min(size(im, 2), det(3))) = 1;
box(min(size(im, 1), det(4)-1):min(size(im, 1), det(4)+1), max(1, det(1)):min(size(im, 2), det(3))) = 1;
box(max(1, det(2)):min(size(im, 1), det(4)), max(1, det(1)-1):max(1, det(1)+1)) = 1;
box(max(1, det(2)):min(size(im, 1), det(4)), min(size(im, 2), det(3)-1):min(size(im, 2), det(3)+1)) = 1;

im(:,:,1) = im(:,:,1) + uint8(box .* color(1));
im(:,:,2) = im(:,:,2) + uint8(box .* color(2));
im(:,:,3) = im(:,:,3) + uint8(box .* color(3));

end