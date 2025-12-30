%% ==============================================================================
% FINAL PRODUCTION FILTER (SNDR & ENOB)
% Architecture: CIC(8x) -> CIC(2x) -> FIR(4x)
% ==============================================================================

if ~exist('y', 'var')
    error('Error: Variable "y" not found! Please run your DSM generation script first.');
end

% --- Parameters ---
Fs_in = 81920;   
Fin   = 80;      % Signal Frequency
BW_sig = 80;     % Bandwidth of Interest (for Noise Integration)

fprintf('========================================\n');
fprintf('PROCESSING WITH SNDR & ENOB\n');
fprintf('Input Rate: %.0f Hz | Signal: %.0f Hz\n', Fs_in, Fin);
fprintf('========================================\n');

x_in = double(y);

%% STAGE 1: CIC Filter (8x)
% Rate: 81.92 -> 10.24 kHz
R1 = 8; N1 = 7; 
Fs1 = Fs_in/R1;

% Filter & Decimate
b_cic1 = 1; box = ones(1, R1);
for k=1:N1, b_cic1=conv(b_cic1,box); end
b_cic1 = b_cic1/sum(b_cic1);

y_s1 = filter(b_cic1, 1, x_in);
y_s1 = y_s1(1:R1:end);

% Calc Metrics (Noise BW = 80 Hz)
Calc_OSR1 = (Fs1/2) / BW_sig;
[sndr1, enob1] = local_calc_metrics(y_s1, Fs1, Fin, Calc_OSR1);

fprintf('Stage 1 (CIC 8x): SNDR = %.2f dB | ENOB = %.2f bits\n', sndr1, enob1);

%% STAGE 2: CIC Filter (2x)
% Rate: 10.24 -> 5.12 kHz
R2 = 2; N2 = 7; 
Fs2 = Fs1/R2;

% Filter & Decimate
b_cic2 = 1; box = ones(1, R2);
for k=1:N2, b_cic2=conv(b_cic2,box); end
b_cic2 = b_cic2/sum(b_cic2);

y_s2 = filter(b_cic2, 1, y_s1);
y_s2 = y_s2(1:R2:end);

% Calc Metrics
Calc_OSR2 = (Fs2/2) / BW_sig;
[sndr2, enob2] = local_calc_metrics(y_s2, Fs2, Fin, Calc_OSR2);

fprintf('Stage 2 (CIC 2x): SNDR = %.2f dB | ENOB = %.2f bits\n', sndr2, enob2);

%% STAGE 3: FIR Filter (4x)
% Rate: 5.12 -> 1.28 kHz
R3 = 4; 
Fs_out = Fs2/R3;

% Filter & Decimate
b3 = fir1(120, 0.2, 'low', kaiser(121, 16)); 
y_s3 = filter(b3, 1, y_s2);
y_out = y_s3(1:R3:end);

% Calc Metrics
Calc_OSR3 = (Fs_out/2) / BW_sig;
[sndr_out, enob_out] = local_calc_metrics(y_out, Fs_out, Fin, Calc_OSR3);

fprintf('\n========================================\n');
fprintf('FINAL RESULT\n');
fprintf('   SNDR: %.2f dB\n', sndr_out);
fprintf('   ENOB: %.2f bits\n', enob_out);
fprintf('   Rate: %.2f Hz\n', Fs_out);
fprintf('========================================\n');

% --- Plots ---
figure('Name', 'Final Output Analysis'); 
subplot(2,1,1);
[P, f] = periodogram(y_out, hanning(length(y_out)), 2^nextpow2(length(y_out)), Fs_out);
semilogx(f, 10*log10(P)); grid on; xlim([10 Fs_out/2]);
title(sprintf('Spectrum (ENOB = %.1f bits)', enob_out)); 
xlabel('Hz'); ylabel('dB');

subplot(2,1,2);
t_axis = (0:length(y_out)-1)/Fs_out;
limit = min(100, length(y_out));
plot(t_axis(1:limit), y_out(1:limit), '.-'); grid on;
title('Time Domain'); xlabel('Seconds');

%% ========================================================================
%  HELPER FUNCTION: SNDR & ENOB
% ========================================================================
function [sndr, enob] = local_calc_metrics(v_in, Fs, Fin, Calc_OSR)
    % 1. Pre-process
    v_in = v_in - mean(v_in);
    v_in = v_in(1:2^(nextpow2(length(v_in))-1)); 
    L = length(v_in);
    NFFTv = 2^nextpow2(L);
    
    % 2. Compute PSD
    fft_outv = fft(v_in .* hanning(L), NFFTv);
    Ptot = (abs(fft_outv)).^2;
    fft_onesided = abs(Ptot(1:NFFTv/2+1));
    f_axis = Fs * (0:NFFTv/2) / NFFTv;
    
    % 3. DYNAMIC SIGNAL BIN SELECTION
    [~, center_idx] = min(abs(f_axis - Fin));
    width = 5; 
    sigbin = max(1, center_idx-width) : min(length(fft_onesided), center_idx+width);
    
    % 4. Signal Power
    sigpow = sum(fft_onesided(sigbin));
    
    % 5. Noise Power (Integrate up to BW_sig)
    limit_idx = floor(length(fft_onesided) / Calc_OSR);
    limit_idx = max(limit_idx, max(sigbin) + 1);
    
    % Total power in band (start from bin 3 to avoid DC leakage)
    P_in_band = sum(fft_onesided(3:limit_idx));
    npow = P_in_band - sigpow;
    
    if npow <= 1e-20, npow = 1e-12; end
    
    % 6. Calculate Metrics
    sndr = 10*log10(sigpow./npow);
    enob = (sndr - 1.76) / 6.02;
end
