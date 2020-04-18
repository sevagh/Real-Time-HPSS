function [h, p] = HPSS(x, fs)
    % STFT parameters
    winLen = 1024;
    fftLen = winLen*2;
    overlapLen = winLen/2;
    win = sqrt(hann(winLen,"periodic"));
    
    % STFT of original signal
    S = stft(x, "Window", win, "OverlapLength", overlapLen, "FFTLength", fftLen, "Centered", true);
    halfIdx = 1:ceil(size(S,1)/2); % only half the STFT matters
    Shalf = S(halfIdx, :);
    Smag = abs(Shalf); % use the magnitude STFT for creating masks

    % median filters
    lHarm = 0.2/((fftLen - overlapLen)/fs); % 200ms in samples
    H = movmedian(Smag, lHarm, 2);
    lPerc = 500/(fs/fftLen); % 500Hz in samples
    P = movmedian(Smag, lPerc, 1);

    % binary masks with separation factor, Driedger et al. 2014
    beta = 2;
    Mh = (H./(P + eps)) > beta;
    Mp = (P./(H + eps)) >= beta;

    % soft masks, Fitzgerald 2010 - p is usually 1 or 2
    %p = 2; Hp = H.^p; Pp = P.^p; total = Hp + Pp;
    %Mh = Hp./total;
    %Mp = Pp./total;

    % recover the complex STFT H and P from S using the masks
    H = Mh.*Shalf;
    P = Mp.*Shalf;

    % we previously dropped the redundant second half of the fft - recreate it
    H = cat(1, H, flipud(conj(H)));
    P = cat(1, P, flipud(conj(P)));
    
    % finally istft to convert back to audio
    h = istft(H, "Window", win, "OverlapLength", overlapLen, "FFTLength", fftLen, "ConjugateSymmetric", true);
    p = istft(P, "Window", win, "OverlapLength", overlapLen, "FFTLength", fftLen, "ConjugateSymmetric", true);
end