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
X = np.linspace(0, 1, STRING_POINTS)

fig, ax = plt.subplots()
line, = ax.plot(X, Yt[0], lw=2)
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
    # ax.relim()
    # ax.autoscale_view()
    fig.canvas.draw_idle()

freq_slider.on_changed(update)
plt.show()
plt.close()