function shift=get_best_shift(sf,bw,cr)
    if bw == 1625e3
        
        shifts = [0;0;2300;2100;0;0;0;0];
    elseif bw == 203e3
        shifts = [700;0;0;0;0;0;0;0];
    else
        error("no shift for bw");
    end
    shift = shifts(sf-4);
end