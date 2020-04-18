[x, fs] = audioread("../audio/perc_driedger_nonrealtime.wav");
[x2, fs] = audioread("../audio/drum.wav");

plot(x);
hold on;
plot(x2, 'r--');
ylabel('amplitude');
xlabel('samples');
legend('separated', 'original');