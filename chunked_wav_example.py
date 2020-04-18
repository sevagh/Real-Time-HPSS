#!/usr/bin/env python3.7

from hpss_rt import HPSSRT
import sys
import time
import numpy
import scipy
import scipy.io.wavfile
import matplotlib.pyplot as plt


if __name__ == "__main__":
    infile = ""
    try:
        infile = sys.argv[1]
    except:
        print("usage: {0} /path/to/wav/file", file=sys.stderr)
        sys.exit(1)

    fs, x = scipy.io.wavfile.read(infile)
    hpss = HPSSRT(fs)

    h = numpy.ndarray(shape=x.shape)
    p = numpy.ndarray(shape=x.shape)

    x_ptr = 0
    total = 0
    while x_ptr < len(x):
        if len(x[x_ptr : x_ptr + hpss.hop]) != hpss.hop:
            # skip uneven/non-hop-sized last chunk
            break
        start = time.time()
        h_, p_ = hpss.process_next_hop(x[x_ptr : x_ptr + hpss.hop])
        total += time.time() - start
        h[x_ptr : x_ptr + hpss.hop] = h_
        p[x_ptr : x_ptr + hpss.hop] = p_
        x_ptr += hpss.hop

    total /= x_ptr / hpss.hop
    print("average time per loop iter: {0}".format(total))

    scipy.io.wavfile.write("h_rt_sep_python.wav", fs, h)
    scipy.io.wavfile.write("p_rt_sep_python.wav", fs, p)

    fs, xm = scipy.io.wavfile.read(infile)
    fs, xh = scipy.io.wavfile.read("h_rt_sep_python.wav")
    fs, xp = scipy.io.wavfile.read("p_rt_sep_python.wav")
    _, _, _, im = plt.specgram(xm, Fs=fs, NFFT=1024, noverlap=256)
    plt.show()
    _, _, _, im = plt.specgram(xh, Fs=fs, NFFT=1024, noverlap=256)
    plt.show()
    _, _, _, im = plt.specgram(xp, Fs=fs, NFFT=1024, noverlap=256)
    plt.show()
