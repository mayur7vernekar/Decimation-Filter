%% ========================================================================
% VERILOG OUTPUT VERIFICATION SCRIPT
% Reads 'pcm_verify_output.csv' from VCS simulation and calculates ENOB
% ========================================================================

clear; clc;

% 1. Load Data
filename = 'pcm_verify_output.csv';
if ~isfile(filename)
    error('File %s not found! Run the Verilog simulation first.', filename);
end

fprintf('Loading %s...\n', filename);
data_table = readtable(filename);

% Extract the PCM column (Assuming 2nd column is values)
% If your CSV has a header, 'readtable' handles it automatically.
pcm_data = data_table.PCM_Value;

% 2. Simulation Parameters (Must match your design)
Fs_out = 1280;      % Output Sample Rate
Fin    = 80;        % Input Signal Frequency
BW_sig = 80;        % Bandwidth of Interest for Noise Integration

% 3. Check Data Length
L = length(pcm_data);
fprintf('Loaded %d samples.\n', L);

if L < 1024
    warning('Data length is very short. FFT results may be inaccurate.');
end

% 4. Pre-process (Remove DC Offset & Windowing)
% Remove initial transient (warm-up garbage) - e.g., first 10%
warmup = floor(L * 0.1);
pcm_stable = pcm_data(warmup:end);

% Remove DC
pcm_stable = pcm_stable - mean(pcm_stable);

% Truncate to power of 2 for clean FFT
N_fft = 2^nextpow2(length(pcm_stable));
pcm_fft_in = pcm_stable(1:min(length(pcm_stable), N_fft)); % Use exact power of 2 if available
% Or better: Zero-pad to N_fft if short, or just use N_fft length from available data
% Let's stick to the Dynamic ISRO helper logic for consistency

% 5. Calculate Metrics (Using the same ISRO logic)
Calc_OSR = (Fs_out/2) / BW_sig;
[sndr, enob] = local_calc_isro_sndr_dynamic(pcm_stable, Fs_out, Fin, Calc_OSR);

% 6. Display Results
fprintf('\n========================================\n');
fprintf('VERILOG SIMULATION RESULTS\n');
fprintf('========================================\n');
fprintf('SNDR: %.2f dB\n', sndr);
fprintf('ENOB: %.2f bits\n', enob);
fprintf('========================================\n');

% 7. Pass/Fail Check
if sndr >= 100
    fprintf('STATUS: [ PASS ] (Targets met)\n');
else
    fprintf('STATUS: [ FAIL ] (SNDR < 100 dB)\n');
end

% 8. Plot
figure('Name', 'Verilog Output Verification');
subplot(2,1,1);
plot(pcm_stable(1:min(200,end)), '.-'); 
title('Verilog Output (Time Domain - Zoomed)'); grid on;
xlabel('Samples'); ylabel('PCM Value');

subplot(2,1,2);
[P, f] = periodogram(pcm_stable, hanning(length(pcm_stable)), N_fft, Fs_out);
semilogx(f, 10*log10(P)); 
title(sprintf('Spectrum (SNDR = %.2f dB)', sndr));
xlim([10 Fs_out/2]); grid on;
xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)');


%% ========================================================================
%  HELPER FUNCTION (Same as before)
% ========================================================================
function [sndr, enob] = local_calc_isro_sndr_dynamic(v_in, Fs, Fin, Calc_OSR)
    v_in = v_in - mean(v_in);
    % Use nearest power of 2 length
    L_trunc = 2^floor(log2(length(v_in)));
    if L_trunc < 256, L_trunc = length(v_in); end % Safety for very short signals
    v_in = v_in(1:L_trunc);
    
    L = length(v_in);
    NFFTv = 2^nextpow2(L);
    
    fft_outv = fft(v_in .* hanning(L), NFFTv);
    Ptot = (abs(fft_outv)).^2;
    fft_onesided = abs(Ptot(1:NFFTv/2+1));
    f_axis = Fs * (0:NFFTv/2) / NFFTv;
    
    [~, center_idx] = min(abs(f_axis - Fin));
    width = 5; 
    sigbin = max(1, center_idx-width) : min(length(fft_onesided), center_idx+width);
    
    sigpow = sum(fft_onesided(sigbin));
    
    limit_idx = floor(length(fft_onesided) / Calc_OSR);
    limit_idx = max(limit_idx, max(sigbin) + 1);
    
    P_in_band = sum(fft_onesided(3:limit_idx));
    npow = P_in_band - sigpow;
    
    if npow <= 1e-20, npow = 1e-12; end
    
    sndr = 10*log10(sigpow./npow);
    enob = (sndr - 1.76) / 6.02;
end
