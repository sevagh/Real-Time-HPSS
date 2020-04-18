function HPSSWav(mixFile)
    [x, fs] = audioread(mixFile);
    
    tic
    [h, p] = HPSS(x, fs); % call our HPSS function
    toc
    
    %sound(h, fs);
    %disp('Playing recovered harmonic - paused');
    %pause;
    %sound(p, fs);
    %disp('Playing recovered percussive - paused');
    %pause;
    
    audiowrite('harm_non_realtime.wav', h, fs);
    audiowrite('perc_non_realtime.wav', p, fs);
end