function im_recon_nufft_cor = Perform_2D_SN_DPsti_recon(ima_k_spa_data, TSE, PE_estimation,  varargin)
%
%INPUT
%
%ima_k_spa_data:        uncorrected and unsorted TSE k-space image in size of [kx, profiles]
%TSE:                   TSE structure contains profile labels for ima_k_spa_data
%PE_estimation:         Phase error structure contains estimated phase error
%(linear and global);
%correction_shot_range:     (optional) user defined correction shots range. All shots by default
%filenames for sense mpas:  (optional) sense maps for reconstruction
%
%OUTPUT
%
%im_recon_nufft_cor:    corrected TSE image reconstruction in size of [x, y, z].  cpx data
gen_sense_map = 0; %defualt don't use sense maps
if nargin == 4
    correction_shot_range=varargin{1};
elseif nargin == 5
    correction_shot_range=varargin{1};
    raw_fn = varargin{2};
    gen_sense_map = 1;
end

%% ------Data Correction Initialization-----------------------------------
display('Data Correction Initialization...')

ch_dim = TSE.ch_dim;
ky_matched = TSE.ky_matched;
kz_matched = TSE.kz_matched;
shot_matched = TSE.shot_matched;

linear_phase_xy = PE_estimation.linear_phase_xy_all;
global_phase = PE_estimation.global_phase_all;
nav_kx_dim = PE_estimation.nav_kx_dim;
nav_ky_dim = PE_estimation.nav_ky_dim;

if(length(ima_k_spa_data)~=length(TSE.shot_matched))|(length(ima_k_spa_data)~=length(TSE.ky_matched))
    error('k space data matrix has different size as shot label!')
end
% Sort channel
kx_dim = size(ima_k_spa_data, 1);



profiles = size(ima_k_spa_data, 2)/ch_dim;
ima_k_spa_data_sort_ch = reshape(ima_k_spa_data, kx_dim, ch_dim,  profiles);
ky_matched_profiles = ky_matched(1:ch_dim:end);
kz_matched_profiles = kz_matched(1:ch_dim:end);
kx_matched_profiles = repmat([-1* kx_dim/2 :  kx_dim/2-1],length(ky_matched_profiles),1);
shot_matched_profiles = shot_matched(1:ch_dim:end);

%% correction
% linear_phase_xy(2,ch,shot) is used for trajctory correction in x and y(linear phase error)
% global_phase(ch,shot) is used for global phase error correction

display('Data Correction...')

nav_shot = max(shot_matched_profiles(:));



traj_1D_x_cor =kx_matched_profiles; % [klines, kx_points]
traj_1D_y_cor =ky_matched_profiles; % [klines, 1]
traj_1D_z_cor =kz_matched_profiles; % [klines, 1]

%pi shift of raw data? YES! PLEASE (Checkerboard correction)
for prof = 1:size(ima_k_spa_data_sort_ch, 3)
    ima_k_spa_data_sort_ch_pi_shifted(:,:,prof) = ima_k_spa_data_sort_ch(:,:,prof) .* ...
        (-1)^(double(ky_matched_profiles(prof))+double(kz_matched_profiles(prof)) );
    
end

DP_Ks_data_all_cor = ima_k_spa_data_sort_ch_pi_shifted; % [kx_points, ch, klines]


j = sqrt(-1);
% dummyshot = 3;

if (~exist('correction_shot_range'))
    correction_shot_range=[1:nav_shot];
end

for nr_shot_count = 1:length(correction_shot_range)   %dyn for spiral is the same as shot for DP
    
    nr_shot = correction_shot_range(nr_shot_count);
    disp(['Correction shot: ', num2str(nr_shot)]);
    %  correction points
    indx = find(shot_matched_profiles == nr_shot);  % size(Sorted_shot_lable_1dyn_all_channel) = kx ky kz
    
    %     if((abs(global_phase(ch_idx,nr_shot))>50)||(abs(linear_phase_xy(1,ch_idx,nr_shot))>2*pi)) %global_phase in rad, linear_phase_xy in rad/navigator_pixel
    %         disp('discard');
    %         DP_Ks_data_all_cor(indx) = 0; %exlcude this shot
    if(0)
    else
        disp('Corrected');
        %-------------------------------------------------------------------
        %        Perform correction
        %-------------------------------------------------------------------
        % linear_phase_xy in rad/navigator_pixel (measured from navigator)
        traj_1D_x_cor(indx,:) = traj_1D_x_cor(indx,:) - linear_phase_xy(1,1,nr_shot) * nav_kx_dim / 2 / pi;  %a pixel in DP kspace is (1/0.152)/m
        traj_1D_y_cor(indx) = traj_1D_y_cor(indx) - linear_phase_xy(2,1,nr_shot) * nav_ky_dim / 2 / pi;
        %         global phase error in rad
        DP_Ks_data_all_cor(:,:,indx) = DP_Ks_data_all_cor(:,:,indx) .* exp(-j*global_phase(1,nr_shot) ); %the simulated introduced phase is doubled by the navigator
        
        % >>>>>>>>>>>>>> use true phase error to correct (for simulation only)<<<<<<<<<<<<<<<<<<<<<
        %         traj_1D_x_cor(indx,:) = traj_1D_x_cor(indx,:) - linear_phase_error_input_x_in_TSEksp_pixel(dummyshot + nr_shot ) ;
        %         traj_1D_y_cor(indx) = traj_1D_y_cor(indx) - linear_phase_error_input_y_in_TSEksp_pixel(dummyshot + nr_shot );
        %         traj_1D_z_cor(indx) = traj_1D_z_cor(indx) - linear_phase_error_input_z_in_TSEksp_pixel(dummyshot + nr_shot  );
        %         % global phase error in rad
        %         DP_Ks_data_all_cor(:,:,indx) = DP_Ks_data_all_cor(:,:,indx) .* exp(-j*global_phase_error_input_match_rad(dummyshot + nr_shot ) );
        %         if(nr_shot~=3)
        %             DP_Ks_data_all_cor(:,:,indx) = 0;
        %         end
        
        
        
    end
    
end


%% RECON
% =========================================================
%                    NUFFT Recon
% =========================================================

shot_matched_profiles_rs = repmat(shot_matched_profiles', [kx_dim, 1]);
shot_all_points_1d = col(shot_matched_profiles_rs);

%columnized trj and data for nufft recon
% reshape trajectory to m*3; data to m*1

% uncorrected
kx_matched_profiles_rs = col(kx_matched_profiles');
ky_matched_profiles_rs = col(repmat(ky_matched_profiles', [ kx_dim 1]));
kz_matched_profiles_rs = col(repmat(kz_matched_profiles', [ kx_dim 1]));
traj_nufft_uncor = double(cat(1, kx_matched_profiles_rs', ky_matched_profiles_rs', kz_matched_profiles_rs'));

sig_nufft_uncor = reshape(permute(ima_k_spa_data_sort_ch_pi_shifted, [1 3 2]), kx_dim*profiles, ch_dim);

% corrected
traj_1D_x_cor_rs = col(traj_1D_x_cor');
traj_1D_y_cor_rs = col(repmat(traj_1D_y_cor', [ kx_dim 1]));
traj_1D_z_cor_rs = col(repmat(traj_1D_z_cor', [ kx_dim 1]));
traj_nufft_cor = double(cat(1, traj_1D_x_cor_rs', traj_1D_y_cor_rs', traj_1D_z_cor_rs'));


sig_nufft_cor = reshape(permute(DP_Ks_data_all_cor, [1 3 2]), kx_dim*profiles, ch_dim);

%>>>>>>choose recon range: the same as correction range
recon_range = find((shot_all_points_1d >= correction_shot_range(1)) &(shot_all_points_1d <= correction_shot_range(end)) ); 

% recon_range = find(mod(shot_all_points_1d,10)==1 ); %use the 3rd shot only
% recon_range = [1:length(shot_all_points_1d)]; %all shots

% Uncorrected

nufft_uncor_dim = round(max(traj_nufft_uncor,[],2) - min(traj_nufft_uncor,[],2)+1)';

% scale trajectory [-pi pi]
scale_factor_x = pi / max(abs(traj_nufft_uncor(1,:)));
scale_factor_y = pi / max(abs(traj_nufft_uncor(2,:)));
scale_factor_z = pi / max(abs(traj_nufft_uncor(3,:)));

traj_nufft_ideal_scaled(:,1) = traj_nufft_uncor(1,:) * scale_factor_x;
traj_nufft_ideal_scaled(:,2) = traj_nufft_uncor(2,:) * scale_factor_y;
traj_nufft_ideal_scaled(:,3) = traj_nufft_uncor(3,:) * scale_factor_z;
traj_nufft_ideal_scaled = double(traj_nufft_ideal_scaled);

clear im_recon_nufft_uncor im_recon_nufft_uncor_fftshifted

oversample_factor = 3;
if( gen_sense_map )  %use sense imformation
    
    TSE_sense_map = get_sense_map_external(raw_fn.sense_ref_fn, raw_fn.data_fn, raw_fn.coil_survey_fn, nufft_uncor_dim);
    TSE_sense_map = normalize_sense_map(TSE_sense_map);
    
    A=nuFTOperator(traj_nufft_ideal_scaled(recon_range,:),nufft_uncor_dim,TSE_sense_map,oversample_factor);
else
    A=nuFTOperator(traj_nufft_ideal_scaled(recon_range,:),nufft_uncor_dim,ones(nufft_uncor_dim),oversample_factor);
end
% im_recon_nufft_uncor=regularizedReconstruction(A,col(sig_nufft_uncor),@L2Norm,0.5,'maxit',25);
im_recon_nufft_uncor=A'*col(sig_nufft_uncor(recon_range,:));

figure(22); montage(permute(abs(im_recon_nufft_uncor),[1 2 4 3]),'displayrange',[]); title('uncor')



% Corrected

% scale trajectory [-pi pi]
nufft_cor_dim = round(max(traj_nufft_cor,[],2) - min(traj_nufft_cor,[],2)+1)';


scale_factor_x = pi / max(abs(traj_nufft_cor(1,:)));
scale_factor_y = pi / max(abs(traj_nufft_cor(2,:)));
scale_factor_z = pi / max(abs(traj_nufft_cor(3,:)));

traj_nufft_cor_scaled(:,1) = traj_nufft_cor(1,:) * scale_factor_x;
traj_nufft_cor_scaled(:,2) = traj_nufft_cor(2,:) * scale_factor_y;
traj_nufft_cor_scaled(:,3) = traj_nufft_cor(3,:) * scale_factor_z;

clear im_recon_nufft_cor im_recon_nufft_cor_fftshifted

oversample_factor = 3;
if( gen_sense_map )   %use sense imformation
    
    TSE_sense_map = get_sense_map_external(raw_fn.sense_ref_fn, raw_fn.data_fn, raw_fn.coil_survey_fn, nufft_cor_dim);
    TSE_sense_map = normalize_sense_map(TSE_sense_map);
    
    A=nuFTOperator(traj_nufft_cor_scaled(recon_range,:),nufft_cor_dim,TSE_sense_map,oversample_factor);
else
    A=nuFTOperator(traj_nufft_cor_scaled(recon_range,:),nufft_cor_dim,ones(nufft_cor_dim),oversample_factor);
end



im_recon_nufft_cor=regularizedReconstruction(A,col(sig_nufft_cor(recon_range,:)),@L2Norm,0.5,'maxit',25);
% im_recon_nufft_cor=A'*col(sig_nufft_cor(recon_range,:));

figure(24); montage(permute(abs(im_recon_nufft_cor ),[1 2 4 3]),'displayrange',[]); title('cor')


%% BART RECON 
%{
% =========================================================
%                      BART Recon
% =========================================================
clear DP_uncorrected DP_uncorrected_fftshifted DP_corrected DP_corrected_fftshifted
% Uncorrected
traj_matrix_ideal_rs = cat(3, kx_matched_profiles', repmat(ky_matched_profiles', [ kx_dim 1]), repmat(kz_matched_profiles', [ kx_dim 1]));
traj_matrix_ideal_rs = permute(traj_matrix_ideal_rs,[3 1 2]); % [3 kx profiles]
DP_Ks_data_all_uncor_pm = permute(ima_k_spa_data_sort_ch_pi_shifted, [4 1 3 2]); %[1 kx profiles ch]

DP_uncorrected = bart('nufft -i -l0.01 ', traj_matrix_ideal_rs, DP_Ks_data_all_uncor_pm);
% DP_uncorrected_fftshifted = fftshift(fftshift(DP_uncorrected,2),3);

% figure(20); montage(permute(abs(DP_uncorrected),[1 2 4 3]),'displayrange',[]); colormap gray
ch_idx = 6;
figure(20); montage(permute(abs(DP_uncorrected(:,:,:,ch_idx)),[1 2 4 3]),'displayrange',[]); colormap gray
figure(201); montage(abs(DP_uncorrected(:,:,2,:)),'displayrange',[]); colormap gray

% Corrected
traj_matrix_cor_rs = cat(3, traj_1D_x_cor', repmat(traj_1D_y_cor', [ kx_dim 1]), repmat(traj_1D_z_cor', [ kx_dim 1]));
traj_matrix_cor_rs = permute(traj_matrix_cor_rs,[3 1 2]); % [3 kx profiles]
DP_Ks_data_all_cor_pm = permute(DP_Ks_data_all_cor, [4 1 3 2]); %[1 kx profiles ch]

DP_corrected = bart('nufft -i -l0.1 ', traj_matrix_cor_rs, DP_Ks_data_all_cor_pm);
% DP_corrected_fftshifted = fftshift(fftshift(DP_corrected,2),3);
figure(21); montage(permute(abs(DP_corrected(:,:,:,ch_idx)),[1 2 4 3]),'displayrange',[]); colormap gray
figure(211); montage(abs(DP_corrected(:,:,2,:)),'displayrange',[]); colormap gray

% PICS
%%--------SCANER SENSE-----------------------------------------
%   sens = gen_sense_map( raw_data_fn, [ 68 60 2]);
%   sens_shifted = fftshift(fftshift(sens,2),3);
%%--------ESPiRIT SENSE----------------------------------------
%     [x, y, z, c] = size(DP_corrected_fftshifted);
%     DP_corrected_fftshifted_2FOV = bart('resize -c 0 132 1 116 2 3', DP_corrected_fftshifted); %bigger FOV
%     for slice =1:z
%
%         fullres_ksp = bart('fft -u 7', DP_corrected_fftshifted_2FOV(:,:,slice,:));
%
%         sens_ecalib(:,:,slice,:) = bart('ecalib -m1', fullres_ksp); %high res sense
%     end

DP_correctedPICS = ((bart('pics -S  -r0.01 -t', traj_matrix_cor_rs, DP_Ks_data_all_cor_pm, fftshift(fftshift(sens_ecalib,2),3))));
DP_correctedPICS_fftshifted = fftshift(fftshift(DP_correctedPICS,2),3);
figure(211); montage(permute(abs(DP_correctedPICS_fftshifted),[1 2 4 3]),'displayrange',[]); colormap gray
%}

end