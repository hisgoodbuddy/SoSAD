%==========DPsti-TSE nonrigid motion correction simulation============
cd('/home/qzhang/lood_storage/divi/Users/qzhang/SoSND/SoSND/simulations')
clear; close all; clc
load('test_data.mat')

%% reference
tic;
kx_dim = size(ima_k_spa_ideal,1);
max_ky = max(TSE.ky_matched); max_kz = max(TSE.kz_matched);
ky_dim = max_ky* 2 + 1; %consider half scan
kz_dim = max_kz * 2 + 1; %consider half scan
ch_dim = TSE.ch_dim;
kspa_xyz_ref = zeros(kx_dim, ky_dim, kz_dim, TSE.ch_dim);

for prof_idx = 1:size(ima_k_spa_ideal, 2)
    ky_idx = TSE.ky_matched(prof_idx) + max_ky + 1;
    kz_idx = TSE.kz_matched(prof_idx) + max_kz + 1;
    ch_idx = mod(prof_idx, ch_dim) + 1;
    kspa_xyz_ref(:,ky_idx,kz_idx,ch_idx) = ima_k_spa_ideal(:,prof_idx);
end
size(kspa_xyz_ref)

% remove stupid checkerboard pattern
che=create_checkerboard([1,size(kspa_xyz_ref,2),size(kspa_xyz_ref,3)]);
kspa_xyz_ref=bsxfun(@times,kspa_xyz_ref,che);
kspa_xyz_ref=squeeze(kspa_xyz_ref);

ima_ref = ifft3d(kspa_xyz_ref);
ima_ref_rss = bart('rss 8', ima_ref);
figure(1); montage(permute(abs(ima_ref_rss),[1 2 4 3]),'displayrange',[]);


sense_map_3D = bart('ecalib -S -m1', kspa_xyz_ref);
figure(2);  montage(angle(sense_map_3D(:,:,25,:)),'displayrange',[]);
figure(3);  montage(abs(sense_map_3D(:,:,25,:)),'displayrange',[]);
sense_map_3D = normalize_sense_map(sense_map_3D);
toc;
%% Preprocessing
simulation = true; noiselevel = 1;

tic;
if(simulation)
    
    kx_dim = size(ima_k_spa_ideal,1);
    max_ky = max(abs(TSE.ky_matched)); max_kz = max(abs(TSE.kz_matched));
    ky_dim = max_ky * 2 + 1; %consider half scan
    kz_dim = max_kz * 2 + 1; %consider half scan
    ch_dim = TSE.ch_dim;
    % sh_dim = 10; %simulate 10 shots
    sh_dim = max(TSE.shot_matched) - min(TSE.shot_matched) + 1;
    
    ky_labels = TSE.ky_matched + max_ky + 1;
    ky_labels = ky_labels(1:ch_dim:end);
    kz_labels = TSE.kz_matched + max_kz + 1;
    kz_labels = kz_labels(1:ch_dim:end);
    prof_per_shot = length(ky_labels)/sh_dim;
    
    mask = [];
    for sh = 1:sh_dim
        range = (sh-1)*prof_per_shot+1:sh*prof_per_shot;
        m = sparse(ky_labels(range), kz_labels(range), ones(prof_per_shot,1), ky_dim, kz_dim);
        mask(1,:,:,1,sh) =full(m);
    end
    
    %================phase error for every shot============================
    phase_error_3D = [];
    for shot = 1:sh_dim
        %% global phase error
        %         pe_temp = exp(1i .* shot .* ones(kx_dim, ky_dim, kz_dim));
        %         phase_error_3D = cat(5, phase_error_3D, pe_temp);
        %% linear phase error
%         pe_2D = linear2Dmap(shot*3, 0.2, kx_dim, ky_dim);
%         pe_temp = exp(1i .* pe_2D);
%         phase_error_3D = cat(5, phase_error_3D, pe_temp);
        
        %% random phase error
                rand_phase = 50 * pi *random_phase_map(kx_dim, ky_dim, kz_dim,1);
                pe_temp = exp(1i.*rand_phase);
                phase_error_3D = cat(5, phase_error_3D, pe_temp);
    end
    if(size(phase_error_3D, 3)~=kz_dim)
        phase_error_3D = repmat(phase_error_3D, [1 1 kz_dim 1 1 ]);
    end   
    %corrupted ima_ref
    im_pe = bsxfun(@times,ima_ref,phase_error_3D);
    %======================================================================
    
    %================self_navigator size===================================
    mask(:,47:57,20:30,:,:) = 1; 
    %================SENSE undersampling===================================
%     mask(:,1:2:end,:,:,:) = 0;    
    
    kspa_xyz = bsxfun(@times, fft3d(im_pe), mask);
    %     kspa_xyz = fft3d(im_pe);
    clear im_pe;
    
    %add noise
    
    if noiselevel>0
        kspa_xyz=kspa_xyz+(randn(size(kspa_xyz)).*mean(kspa_xyz(find(abs(kspa_xyz)>0))).*noiselevel).*(abs(kspa_xyz)>0);
    end
    
    
    %to hybrid space
    clear kspa_x_yz;
    kspa_x_yz = ifft1d(kspa_xyz);
    
    
    %direct recon
    kk=sum(kspa_xyz,5);
    pp=ifft3d(kk);
    im_recon_direct=bart('rss 8',pp);
    figure(4); montage(permute(abs(im_recon_direct),[1 2 4 3]),'displayrange',[]); title('direct recon');
    clear kk pp
    
end
toc;
%% recon
tic;

k0_idx = [floor(kx_dim/2)+1 floor(ky_dim/2)+1 floor(kz_dim/2)+1];
for sh =1:sh_dim
    if(abs(kspa_xyz(k0_idx(1),k0_idx(2),k0_idx(3), 1, sh))>0)
        ref_shot = sh;
    end
end
phase_error_3D = bsxfun(@rdivide, phase_error_3D, phase_error_3D(:,:,:,ref_shot)); %difference with the first
phase_error_3D = permute(normalize_sense_map(squeeze(phase_error_3D)),[1 2 3 5 4]); %miss use normalize_sense_map

%=========select data. fixed=============================================
kspa = squeeze(kspa_x_yz(recon_x_loc, :, :, :, :));
sense_map = squeeze(sense_map_3D(recon_x_loc,:,:,:));
phase_error = permute(squeeze(phase_error_3D(recon_x_loc,:,:,:,:)),[1 2 4 3]);
%========================================================================

recon_x_loc = 90;

%recon parameter
pars = initial_msDWIrecon_Pars;
pars.CG_SENSE_I.lamda=0.1;
pars.CG_SENSE_I.nit=30;

pars.POCS.Wsize = [15 15];  %no point to be bigger than navigator area
pars.POCS.nit = 50;
pars.POCS.tol = 1e-10;
pars.POCS.lamda = 1;
pars.POCS.nufft = false;

pars.method='POCS_ICE'; %POCS_ICE CG_SENSE_I CG_SENSE_K LRT

image_corrected = msDWIrecon(kspa, (sense_map), (phase_error), pars);


%display
figure(102);
subplot(131);imshow(squeeze(abs(ima_ref_rss(recon_x_loc,:,:))),[]); title('reference');
subplot(132);imshow(squeeze(abs(im_recon_direct(recon_x_loc,:,:))),[]); title('direct recon');
subplot(133);imshow(squeeze(abs(image_corrected)),[]); title('msDWIrecon'); xlabel(pars.method);

toc;