#!/usr/bin/python3
import sys, os
from math import sqrt

if len(sys.argv) != 2 and len(sys.argv) != 3:
    print("Usage: %s x-dia [y-dia]"%os.path.basename(sys.argv[0]))
    sys.exit(-1)
xdia = int(sys.argv[1])
a = xdia/2.0 - 0.5
if len(sys.argv) == 3:
    ydia = int(sys.argv[2])
else:
    ydia = xdia
b = ydia/2.0 - 0.5

if a < 1 or b < 1:
    print("Diameter must be a positive integer!")
    sys.exit(-1)

grid = [[' ' for x in range(xdia)] for y in range(ydia)]

def plot(x,y):
    grid[int(b+y)][int(a+x)] = '#'
    grid[int(b-y)][int(a+x)] = '#'
    grid[int(b+y)][int(a-x)] = '#'
    grid[int(b-y)][int(a-x)] = '#'
def printGrid():
    for line in grid:
        print(''.join(line))

x = a
y = 0 if ydia%2 == 1 else 0.5
segs = []
seg = 1
while int(x) > 0:
    plot(x,y)
    e_xy = (x-1)**2*b**2 + (y+1)**2*a**2 - a**2*b**2
    e_x = x**2*b**2 + (y+1)**2*a**2 - a**2*b**2
    e_y = (x-1)**2*b**2 + y**2*a**2 - a**2*b**2
    _x, _y = x, y
    if (abs(e_xy) < abs(e_x)):
        x -= 1
    if (abs(e_xy) < abs(e_y)):
        y += 1
    if _x == x or _y == y:
        seg += 1
    else:
        segs.insert(0,seg)
        seg = 1
while y < b:
    plot(x,y)
    y += 1
    seg += 1

segs.insert(0,seg)
plot(x,y)
printGrid()
print(segs)
