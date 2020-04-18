import numpy
import numpy.fft
import scipy
import time
import scipy.signal


class HPSSRT(object):
    def __init__(self, fs, nwin=1024, nfft=2048, hop=512, beta=2):
        self.nwin = nwin
        self.nfft = nfft
        self.hop = hop
        self.beta = beta

        self.window = numpy.sqrt(scipy.signal.hann(self.nwin, sym=False))

        self.eps = numpy.finfo(numpy.float32).eps
        self.lharm = int(numpy.round(0.2 / ((nfft - hop) / fs)))
        self.lperc = int(numpy.round(500 / (fs / nfft)))

        if self.lharm % 2 == 0:
            self.lharm += 1
        if self.lperc % 2 == 0:
            self.lperc += 1

        self.stft = numpy.zeros(
            shape=(nfft, int(numpy.ceil(self.lharm / 2))), dtype=numpy.csingle
        )  # f32, f32 complex
        self.x = numpy.zeros(shape=(nwin,), dtype=numpy.float32)
        self.h = numpy.zeros(shape=(nwin,), dtype=numpy.float32)
        self.p = numpy.zeros(shape=(nwin,), dtype=numpy.float32)

    def median_filter(self):
        Shalfmag = numpy.abs(self.stft)
        H = scipy.signal.medfilt(Shalfmag, [1, self.lharm])
        P = scipy.signal.medfilt(Shalfmag, [self.lperc, 1])
        Mh = numpy.divide(H, P + self.eps) > self.beta
        Mp = numpy.divide(P, H + self.eps) >= self.beta
        return Mh, Mp

    def process_next_hop(self, hop):
        if len(hop) != self.hop:
            raise ValueError("feed me hop-sized chunks, please")
        self.x = numpy.concatenate((self.x[self.hop :], hop))
        xw = self.x * self.window
        X = numpy.fft.fft(xw, self.nfft)
        # X =
        self.stft = numpy.concatenate(
            (self.stft[:, 1:], numpy.reshape(X, (self.nfft, 1))), 1
        )
        Mh, Mp = self.median_filter()
        Xh = numpy.multiply(Mh[:, -1], X)
        Xp = numpy.multiply(Mp[:, -1], X)
        hw = numpy.fft.irfft(Xh, self.nfft)
        pw = numpy.fft.irfft(Xp, self.nfft)
        hw = hw / numpy.sum(numpy.multiply(self.window, self.window)) / (self.nfft / 2)
        pw = pw / numpy.sum(numpy.multiply(self.window, self.window)) / (self.nfft / 2)

        self.h = numpy.add(self.h, hw[:1024])
        self.p = numpy.add(self.p, pw[:1024])

        ret = (self.h[: self.hop], self.p[: self.hop])

        self.h = numpy.concatenate((self.h[self.hop :], numpy.zeros(shape=(self.hop,))))
        self.p = numpy.concatenate((self.p[self.hop :], numpy.zeros(shape=(self.hop,))))

        return ret
