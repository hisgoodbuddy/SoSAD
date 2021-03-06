%BASED ON POCS-ICE paper by Guo Hua
%
%
% INPUT
%
% x:                  currect image estimation in [ky kz]
% sense_map:          cpx sense maps in [ky kz n_coil]
% kspa_1shot:         cpx phase inhoerent k space data for 1 shot in [ky kz n_coil], it contain navigator info
% trj:                trajectory for k_spa. TODO
%
% OUTPUT
%
% px:                 Updated image estimation [ky kz]
%
% (c) q.zhang 2017 Amsterdam

function px = POCS_projection(x, sense_map, kspa_1shot, trj)

%% cartesian kspa
mask = abs(kspa_1shot)>0;
sx = bsxfun(@times, x, sense_map);
fsx = fft2d(sx);
if(1)
    G_fsx = fsx;  %grid to sampled k points (cartesian, doesn't matter)
    G_fsx_diff = kspa_1shot - G_fsx;  %diff with measurement
    fsx_diff = mask.* G_fsx_diff;  %grid to cartesian (cartesian, doesn't matter)
    sx_diff = ifft2d(fsx_diff);
    spx = sx + sx_diff;
else
    %substute measurement directly. Seems to work as well
    fsx(find(mask)) = kspa_1shot(find(mask));
    spx = ifft2d(fsx);
end





%combine channels; div will be ones if sense_map is normalized
% div = zeros(size(sense_map,1),size(sense_map,2));
% for ch=1:size(sense_map,3)
%     div = div + conj(sense_map(:,:,ch)).*sense_map(:,:,ch);
% end
% px = sum(conj(sense_map).*spx, 3)./div;
px = sum(conj(sense_map).*spx, 3);

%% non-cartesian kspa (TODO make fft2d to nufft2d using trj)

end