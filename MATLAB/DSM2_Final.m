%% ==========================================
% 3rd Order DSM - 
% Table 1 coefficients: a1=2, a2=3, a3=4, b1=1/3, b2=1/4, b3=1/16, k1=2, k2=2, k3=1/2 
% ==========================================


% ---- Input signal ----
Fs  = 2*80*512;            
Fin = 80;             
N   = 534288;          
BW_sig = 80;          
t   = (0:N-1)'/Fs;

% ---- COEFFICIENTS [file:39] ----
k1 = 2.0;      % Input gain
k2 = 2.0;      % Feedback gain  
k3 = 0.5;      % Post-1st integrator scaling (CRITICAL)
c1 = 1/3;      % b1 = 1/3
c2 = 1/4;      % b2 = 1/4  
c3 = 1/16;     % b3 = 1/16
a1 = 2.0;      % Feedforward 1
a2 = 3.0;      % Feedforward 2
a3 = 4.0;      % Feedforward 3

% ---- LOW AMPLITUDE FOR SIMULATION STABILITY ----
opt_amp = 0.5;  % Paper handles full-scale, simulation needs lower
x = opt_amp * sin(2*pi*Fin*t);
fprintf('EXACT 3rd Order DSM from paper - amp: %.3f\n', opt_amp);

% ---- DSM SIMULATION (EXACT PAPER TOPOLOGY) ----
v1 = 0; v2 = 0; v3 = 0;
y  = zeros(N,1);

for n = 1:N
    if n == 1
        d = 0;
    else
        d = y(n-1);
    end
    
    % First summer (k1*x - k2*d) [file:39]
    e = k1 * x(n) - k2 * d;
    
    % First integrator
    v1 = v1 + c1 * e;
    
    % k3 SCALING AFTER FIRST INTEGRATOR (KEY INNOVATION) [file:39]
    v1_scaled = k3 * v1;
    
    % Second and third integrators
    v2 = v2 + c2 * v1_scaled;
    v3 = v3 + c3 * v2;
    
    % Feedforward summation (EXACT paper values)
    u = a1*v1_scaled + a2*v2 + a3*v3;
    
    y(n) = sign(u);
end


%% ======== FFT / Spectrum Visualization (for comparison with 1st-order DSM) ========
y_vis = y;                          % DSM bitstream
N_vis = length(y_vis);
f_vis = (0:N_vis/2) * Fs / N_vis;   % One-sided frequency axis

Y_vis = fft(y_vis .* hanning(N_vis), N_vis);
Y_mag = abs(Y_vis) / N_vis;
Y_mag(2:end-1) = 2 * Y_mag(2:end-1);
P_vis = (abs(Y_mag)).^2;
P1_vis = P_vis(1:N_vis/2+1);        % One-sided power spectrum

figure;
semilogx(f_vis, 20*log10(P1_vis));
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('FFT Spectrum of 3rd-Order DT DSM Output Bitstream');
grid on;

%% ======== Input vs Output Time-Domain Visualization ========
figure;
subplot(2,1,1)
plot(t(1:2000), x(1:2000), 'LineWidth', 1.1)
title('3rd-Order DSM Input Signal (First 2000 Samples)');
xlabel('Time (s)');
ylabel('Amplitude');
grid on;

subplot(2,1,2)
stem(t(1:2000), y(1:2000), 'Marker', 'none')
title('3rd-Order DSM Output Bitstream (First 2000 Samples)');
xlabel('Time (s)');
ylabel('Bits (-1 / +1)');
grid on;


%% =========================================
% SNDR CALCULATION
%% =========================================
[sndr, ENOB, ~, ~] = local_compute_sndr(y, Fs, BW_sig, Fin);
max_states = [max(abs(v1)), max(abs(v2)), max(abs(v3))];

fprintf("\n===== EXACT 3rd ORDER DSM (Paper Coefficients) =====\n");
fprintf("SNDR  = %.2f dB\n", sndr);
fprintf("ENOB  = %.3f bits\n", ENOB);

out.DT_DSM3_Paper.Data = y;
out.DT_DSM3_Paper.Time = t;

disp("3rd Order DSM");

%% ---------- FIXED SNDR FUNCTION ----------
function [sndr, ENOB, f, P1] = local_compute_sndr(y, Fs, BW_sig, f_sig)
    y = y(1:min(length(y), 2^18));  % 262k max
    y = y - mean(y);
    L = length(y);
    NFFT = 2^nextpow2(L);
    win = hanning(L);
    
    Y = fft(y .* win, NFFT);
    P1 = (2*abs(Y(1:NFFT/2+1)).^2)/L;  % Proper PSD scaling
    f = Fs*(0:NFFT/2)/NFFT;
    
    % In-band (0-BW_sig)
    inband = (f <= BW_sig);
    f_ib = f(inband);
    P_ib = P1(inband);
    
    % Find signal peak
    [~,k0] = max(P_ib(5:end)); k0 = k0 + 4;  % Skip DC/low freq
    k0 = min(k0, length(P_ib));
    
    % Signal power (±3 bins)
    sig_start = max(1, k0-3);
    sig_end = min(length(P_ib), k0+3);
    sig_pow = sum(P_ib(sig_start:sig_end));
    
    % Noise power (everything else)
    noise_bins = true(size(P_ib));
    noise_bins(1:8) = false;  % DC + harmonics
    noise_bins(sig_start:sig_end) = false;
    noise_pow = sum(P_ib(noise_bins));
    
    if noise_pow > 0 && sig_pow > noise_pow
        sndr = 10*log10(sig_pow/noise_pow);
    else
        sndr = 10*log10(sig_pow/max(noise_pow,1e-12));
    end
    ENOB = (sndr - 1.76) / 6.02;
end

% --- EXPORT DATA FOR VCS SIMULATION ---
% 1. Convert your DSM output 'y' (+1/-1) to binary (1/0)
dsm_binary = (y > 0); 

% 2. Save as a text file for Verilog $readmemb
% This creates a file with one bit per line (e.g., 1 \n 0 \n 1...)
fid = fopen('dsm_input.txt', 'w');
fprintf(fid, '%d\n', dsm_binary);
fclose(fid);

fprintf('Generated dsm_input.txt with %d samples.\n', length(dsm_binary));
