
import math
import matplotlib.pyplot as plt
import numpy as np

from matplotlib.widgets import Button, Slider

def read_data(path):
    f = open(path, "r")
    lines = f.readlines()
    Yt = []
    for line in lines:
        data = line.split(",")
        Y = []
        for point in data:
            Y.append(float(point))
        Yt.append(Y)
    return Yt

Yt = read_data("../string_analysis.csv")

STRING_POINTS = len(Yt[0])
numero_point = int(STRING_POINTS / 10)
# X = np.linspace(0, 1, STRING_POINTS)
T = np.linspace(0, 1, len(Yt))
Y = [y[numero_point] for y in Yt]

plt.plot(T, Y)
# plt.set_xlabel('Temps [unité arbitraire]')
plt.show()
plt.close()
