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

Yt, Ytp = read_data("../string_analysis.csv")

STRING_POINTS = len(Yt[0])
X = np.linspace(0, 1, STRING_POINTS)

fig, ax = plt.subplots()
line, = ax.plot(X, Yt[0], lw=2)
fig2, ax2 = plt.subplots()
linep, = ax2.plot(X, Ytp[0], lw=2)
ax.set_xlabel('Position [m]')

# adjust the main plot to make room for the sliders
fig.subplots_adjust(left=0.25, bottom=0.25)

# Make a horizontal slider to control the frequency.
axfreq = fig.add_axes([0.25, 0.1, 0.65, 0.03])
freq_slider = Slider(
    ax=axfreq,
    label='Time [unité arbitraire]',
    valmin=0,
    valmax=len(Yt) - 1,
    valinit=0,
)

def update(val):
    line.set_ydata(Yt[math.floor(val)])
    linep.set_ydata(Ytp[math.floor(val)])
    ax2.relim()
    ax2.autoscale_view()
    fig.canvas.draw_idle()
    fig2.canvas.draw_idle()

freq_slider.on_changed(update)
plt.show()
plt.close()
