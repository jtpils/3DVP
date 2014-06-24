% create annotations with occlusion masks for KITTI dataset
function create_annotations

opt = globals();
pad_size = 1000;

% load PASCAL3D+ cad models
cls = 'car';
filename = sprintf('../Geometry/%s.mat', cls);
object = load(filename);
cads = object.(cls);

% load mean model
filename = sprintf('../Geometry/%s_mean.mat', cls);
object = load(filename);
cad_mean = object.(cls);

root_dir = opt.path_kitti_root;
data_set = 'training';

% get sub-directories
cam = 2; % 2 = left color camera
image_dir = fullfile(root_dir,[data_set '/image_' num2str(cam)]);
label_dir = fullfile(root_dir,[data_set '/label_' num2str(cam)]);
calib_dir = fullfile(root_dir,[data_set '/calib']);

% get number of images for this dataset
nimages = length(dir(fullfile(image_dir, '*.png')));

% main loop
for img_idx = 0:nimages-1
  fprintf('image %06d\n', img_idx);
  record.folder = data_set;
  record.filename = sprintf('%06d.png', img_idx);
  
  % read image
  I = imread(sprintf('%s/%06d.png',image_dir, img_idx));
  [h, w, d] = size(I);
  
  record.size.width = w;
  record.size.height = h;
  record.size.depth = d;
  record.imgsize = [w h d];
  
  mask = zeros(h, w);
  mask = padarray(mask, [pad_size pad_size]);

  % load projection matrix
  P = readCalibration(calib_dir, img_idx, cam);
  record.projection = P;
  
  % load labels
  objects = readLabels(label_dir,img_idx);
  
  % sort objects from large distance to small distance
  index = sort_objects(objects);
 
  % for all annotated objects do
  num = numel(index);
  BWs = cell(num, 1);
  for i = 1:num
    obj_idx = index(i);
    % plot 2D bounding box
    object = objects(obj_idx);
    
    if strcmp(object.type, 'Car') == 1
        cad_index = find_closest_cad(cads, object);
        x3d = compute_3d_points(cads(cad_index).vertices, object);
        x2d = projectToImage(x3d, P);
        face = cads(cad_index).faces;
        x2d = x2d';
        
        flag = min(x2d(:,1)) < 0 & max(x2d(:,1)) > w;
        if flag == 1
            continue;
        end
        
        x2d = x2d + pad_size;
        vertices = [x2d(face(:,1),2) x2d(face(:,1),1) ...
                    x2d(face(:,2),2) x2d(face(:,2),1) ...
                    x2d(face(:,3),2) x2d(face(:,3),1)];

        BWs{obj_idx} = mesh_test(vertices, h+2*pad_size, w+2*pad_size);
        
        mask(BWs{obj_idx}) = obj_idx;
    end
  end
  mask = mask(pad_size+1:h+pad_size, pad_size+1:w+pad_size);
  mask = padarray(mask, [pad_size pad_size]);
  record.pad_size = pad_size;
  record.mask = mask;
  
  % create occlusion patterns
  index_object = index;
  for i = 1:num
      azimuth = objects(i).alpha*180/pi;
      if azimuth < 0
          azimuth = azimuth + 360;
      end
      azimuth = azimuth - 90;
      if azimuth < 0
          azimuth = azimuth + 360;
      end
      distance = norm(objects(i).t);
      elevation = asind(objects(i).t(2)/distance);
      objects(i).azimuth = azimuth;
      objects(i).elevation = elevation;
      objects(i).distance = distance;      
      
      if isempty(BWs{i}) == 1
          objects(i).pattern = [];
          objects(i).occ_per = 0;
          objects(i).grid = [];
          continue;
      end
      
      pattern = uint8(BWs{i});
      pattern = 2*pattern;  % occluded
      pattern(mask == i) = 1;  % visible
      [x, y] = find(pattern > 0);
      pattern = pattern(min(x):max(x), min(y):max(y));
      objects(i).pattern = pattern;
      
      % compute occlusion percentage
      occ = numel(find(pattern == 2)) / numel(find(pattern > 0));
      objects(i).occ_per = occ;
      
      % 3D occlusion mask
      [visibility_grid, visibility_ind] = check_visibility(cad_mean, azimuth, elevation);
      
      % check the occlusion status of visible voxels
      index = find(visibility_ind == 1);
      x3d = compute_3d_points(cad_mean.x3d(index,:), objects(i));
      x2d = projectToImage(x3d, P);
      x2d = x2d' + pad_size;
      occludee = find(index_object == i);
      for j = 1:numel(index)
          x = round(x2d(j,1));
          y = round(x2d(j,2));
          ind = cad_mean.ind(index(j),:);
          if x > pad_size && x <= size(mask,2)-pad_size && y > pad_size && y <= size(mask,1)-pad_size
              if mask(y,x) > 0 && mask(y,x) ~= i % occluded by other objects
                  occluder = find(index_object == mask(y,x));
                  if occluder > occludee
                    visibility_grid(ind(1), ind(2), ind(3)) = 2;
                  end
              end
          else
              visibility_grid(ind(1), ind(2), ind(3)) = 2;
          end
      end
      objects(i).grid = visibility_grid;
  end
  
  % save annotation
  record.objects = objects;
  filename = sprintf('Annotations/%06d.mat', img_idx);
  save(filename, 'record');
end