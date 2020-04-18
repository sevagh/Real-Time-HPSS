function HPSSRtWav(mixFile, harmFile, percFile)
    nfft = 2048; nwin = 1024; hop = 512; beta = 2;
    
    mixIn = dsp.AudioFileReader(mixFile,'SamplesPerFrame',hop);
    fs = mixIn.SampleRate;
    harmOut = dsp.AudioFileWriter('harm_rt.wav','FileFormat','WAV','SampleRate',fs);
    percOut = dsp.AudioFileWriter('perc_rt.wav','FileFormat','WAV','SampleRate',fs);
    
    win = sqrt(hann(nwin, "periodic"));
    
    lHarm = 0.2/((nfft - hop)/fs);  % 200ms in samples
    lPerc = 500/(fs/nfft);          % 500Hz in samples
    STFT = zeros(nfft, ceil(lHarm/2));  % preallocate the sliding stft
    
    % nwin-framed ringbuffers to store input and output
    x = zeros(nwin, 1); h = x; p = x;
    
    eof = 0;
    totalTime = 0;
    iters = 0;
        
    while eof == 0
        [nextHop, eof] = mixIn();
        
        tic
        x = vertcat(x(hop+1:nwin), nextHop); % append latest hop samples
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
        percOut(p(1:hop)); % play percussion stream in real-time
        harmOut(h(1:hop)); % play harmonic stream in real-time
        
        % shift for future weighted OLA
        h = vertcat(h(hop+1:nwin), zeros(hop, 1));
        p = vertcat(p(hop+1:nwin), zeros(hop, 1));
        
        totalTime = totalTime + toc;
        iters = iters + 1;
    end
    totalTime = totalTime/iters;
    
    fprintf("time per loop iter: %f\n", totalTime);
    release(percOut);
    release(harmOut);
    release(mixIn);

    xIn = audioread(mixFile);
    xh = audioread(harmFile);
    xp = audioread(percFile);
    harmOut = audioread('harm_rt.wav');
    percOut = audioread('perc_rt.wav');
    minimum = min(length(xh), min(length(xp), min(length(harmOut), length(percOut))));
    nh = 1:minimum;
    np = 1:minimum;
    
    figure;
    plot(nh(512:length(nh)), xIn(512:length(xIn)), 'b--');
    xlabel('samples');
    ylabel('amplitude');
    legend('Mixed original');
    
    figure;
    plot(nh(512:length(nh)), harmOut(512:length(nh)), 'b--');
    hold on;
    plot(np(512:length(np)), percOut(512:length(np)), 'm-');
    xlabel('samples');
    ylabel('amplitude');
    legend('H recovered', 'P recovered');
    hold off;

    figure;
    spectrogram(harmOut,1024,512,1024,fs,"yaxis");
    figure;
    spectrogram(percOut,1024,512,1024,fs,"yaxis");    
end