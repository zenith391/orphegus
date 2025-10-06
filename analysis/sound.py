
import math
import matplotlib.pyplot as plt
import numpy as np

from matplotlib.widgets import Button, Slider

def read_data(path):
    f = open(path, "r")
    lines = f.readlines()
    Yt = []
    Ytp = []
    for i in range(int(len(lines) / 2)):
        data1 = lines[2*i].split(",")
        data2 = lines[2*i+1].split(",")
        Y = []
        for point in data1:
            Y.append(float(point))
        Yp = []
        for point in data2:
            Yp.append(float(point))
        Yt.append(Y)
        Ytp.append(Yp)
    return Yt, Ytp

Yt, _ = read_data("../string_analysis.csv")

STRING_POINTS = len(Yt[0])
numero_point = int(STRING_POINTS * 2 / 10)
# X = np.linspace(0, 1, STRING_POINTS)
T = np.linspace(0, 1, len(Yt))
Y = [y[numero_point] for y in Yt]

plt.plot(T, Y)
plt.xlabel('Temps [s]')
plt.ylabel("Déplacement transversal [m]")
plt.show()
plt.close()
