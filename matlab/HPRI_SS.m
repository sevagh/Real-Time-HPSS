% harmonic-percussive-residual iterative
function [h, p, r] = HPRI_SS(x, fs)
    % HPSS first pass with hop 4096
    hopLen = 4096;
    winLen = hopLen*2;
    fftLen = winLen*2;
    win = sqrt(hann(winLen,"periodic"));
    
    % STFT of original signal
    S = stft(x, "Window", win, "OverlapLength", hopLen, "FFTLength", fftLen, "Centered", true);
    halfIdx = 1:ceil(size(S,1)/2); % only half the STFT matters
    Shalf = S(halfIdx, :);
    Smag = abs(Shalf); % use the magnitude STFT for creating masks

    % median filters
    lHarm = 0.2/((fftLen - hopLen)/fs); % 200ms in samples
    H = movmedian(Smag, lHarm, 2);
    lPerc = 500/(fs/fftLen); % 500Hz in samples
    P = movmedian(Smag, lPerc, 1);

    % binary masks with separation factor, Driedger et al. 2014
    beta = 2;
    Mh = (H./(P + eps)) > beta;
    Mp = (P./(H + eps)) >= beta;
    Mr = 1 - (H + P);

    % recover the complex STFT H and P from S using the masks
    H = Mh.*Shalf;
    P = Mp.*Shalf;
    R = Mr.*Shalf;

    % we previously dropped the redundant second half of the fft - recreate it
    H = cat(1, H, flipud(conj(H)));
    P = cat(1, P, flipud(conj(P)));
    R = cat(1, R, flipud(conj(R)));
    
    % finally istft to convert back to audio
    % final harmonic xh1
    h = istft(H, "Window", win, "OverlapLength", hopLen, "FFTLength", fftLen, "ConjugateSymmetric", true);
    % intermediate xp1, xr1
    p_ = istft(P, "Window", win, "OverlapLength", hopLen, "FFTLength", fftLen, "ConjugateSymmetric", true);
    r_ = istft(R, "Window", win, "OverlapLength", hopLen, "FFTLength", fftLen, "ConjugateSymmetric", true);

    % now we repeat HPSS on xr1+xp1
    x2 = p_ + r_;
    
    hopLen = 256;
    winLen = hopLen*2;
    fftLen = winLen*2;
    win = sqrt(hann(winLen,"periodic"));
    
    % STFT of original signal
    S = stft(x2, "Window", win, "OverlapLength", hopLen, "FFTLength", fftLen, "Centered", true);
    halfIdx = 1:ceil(size(S,1)/2); % only half the STFT matters
    Shalf = S(halfIdx, :);
    Smag = abs(Shalf); % use the magnitude STFT for creating masks

    % median filters
    lHarm = 0.2/((fftLen - hopLen)/fs); % 200ms in samples
    H = movmedian(Smag, lHarm, 2);
    lPerc = 500/(fs/fftLen); % 500Hz in samples
    P = movmedian(Smag, lPerc, 1);

    % binary masks with separation factor, Driedger et al. 2014
    beta = 2;
    Mp = (P./(H + eps)) >= beta;
    Mr = 1 - (H + P);

    % recover the complex STFT H and P from S using the masks
    P = Mp.*Shalf;
    R = Mr.*Shalf;

    % we previously dropped the redundant second half of the fft - recreate it
    P = cat(1, P, flipud(conj(P)));
    R = cat(1, R, flipud(conj(R)));
    
    % finally istft to convert back to audio
    %h_ = istft(H, "Window", win, "OverlapLength", hopLen, "FFTLength", fftLen, "ConjugateSymmetric", true);
    p = istft(P, "Window", win, "OverlapLength", hopLen, "FFTLength", fftLen, "ConjugateSymmetric", true);
    r = istft(R, "Window", win, "OverlapLength", hopLen, "FFTLength", fftLen, "ConjugateSymmetric", true);
end