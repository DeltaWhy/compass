def ellipse(xdia, ydia)
    a = xdia/2.0 - 0.5
    b = ydia/2.0 - 0.5

    if a < 1 or b < 1
        return nil
    end

    #grid = []
    #ydia.times {grid.push ' '*xdia}

    #plot = lambda do |x, y|
    #    grid[(b+y).to_i][(a+x).to_i] = '#'
    #    grid[(b-y).to_i][(a+x).to_i] = '#'
    #    grid[(b+y).to_i][(a-x).to_i] = '#'
    #    grid[(b-y).to_i][(a-x).to_i] = '#'
    #end

    def abs(x); x < 0 ? -x : x; end

    x = a
    y = (ydia%2 == 1 ? 0 : 0.5)
    segs = []
    seg = 1
    while x.to_i > 0
        #plot.call(x,y)
        e_xy = (x-1)**2*b**2 + (y+1)**2*a**2 - a**2*b**2
        e_x = x**2*b**2 + (y+1)**2*a**2 - a**2*b**2
        e_y = (x-1)**2*b**2 + y**2*a**2 - a**2*b**2
        _x, _y = x, y
        x -= 1 if (abs(e_xy) < abs(e_x))
        y += 1 if (abs(e_xy) < abs(e_y))
        if _x == x or _y == y
            seg += 1
        else
            segs.insert(0,seg)
            seg = 1
        end
    end
    while y < b
        #plot.call(x,y)
        y += 1
        seg += 1
    end

    segs.insert(0,seg)
    #plot.call(x,y)
    #grid.each {|line| puts line}
    segs.inspect
end
