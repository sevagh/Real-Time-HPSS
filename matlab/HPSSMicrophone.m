function HPSSMicrophone()
    fs = 48000; nfft = 2048; nwin = 1024; hop = 512; beta = 2;
    win = sqrt(hann(nwin, "periodic"));
    
    lHarm = 0.2/((nfft - hop)/fs);  % 200ms in samples
    lPerc = 500/(fs/nfft);          % 500Hz in samples
    STFT = zeros(nfft, ceil(lHarm/2));  % preallocate the sliding stft
    
    recorder = audioDeviceReader(fs, hop); % hop-sized i/o streams
    output = audioDeviceWriter('SampleRate', fs);
    setup(output, zeros(hop, 1));

    % nwin-size ringbuffers to store input and output
    x = zeros(nwin, 1); h = x; p = x;
    
    while true
        x = vertcat(x(hop+1:nwin), recorder()); % append latest hop samples
        X = fft(x.*win, nfft); Xhalf = X(1:(nfft/2)); % FFT current frame
        
        STFT = STFT(:, 2:size(STFT, 2)); % remove oldest stft frame 
        STFT(:, size(STFT, 2)+1) = X; % append latest frame

        Smag = abs(STFT(1:(nfft/2), :));  % median filter and binary mask
        H = movmedian(Smag, lHarm, 2); P = movmedian(Smag, lPerc, 1);
        Mh = (H./(P + eps)) > beta; Mp = (P./(H + eps)) >= beta;

        % recover h and p from the half FFT using masks + IFFT
        H = Mh(:, size(Mh, 2)).*Xhalf; H = cat(1, H, flipud(conj(H)));
        P = Mp(:, size(Mp, 2)).*Xhalf; P = cat(1, P, flipud(conj(P)));
        hw = real(ifft(H, nfft)); pw = real(ifft(P, nfft));
        
        % Weighted-OLA with previous hop samples
        h = h + hw(1:(nfft/2)).*nfft/sum(win.*win);
        p = p + pw(1:(nfft/2)).*nfft/sum(win.*win);
                
        % first hop samples are finalized after the previous OLA
        output(p(1:hop)); % play percussion stream in real-time
        %output(h(1:hop)); % play harmonic stream in real-time         
        
        % shift for future weighted OLA
        h = vertcat(h(hop+1:nwin), zeros(hop, 1));
        p = vertcat(p(hop+1:nwin), zeros(hop, 1));
    end
end
