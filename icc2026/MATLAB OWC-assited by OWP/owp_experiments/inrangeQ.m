function flag = inrangeQ(Q, pos_x, pos_y)

    if pos_x <= Q(2)
        if pos_x >= Q(1)
            if pos_y <= Q(4)
                if pos_y >= Q(3)
                    flag = 1;
                else
                    flag = 0;
                end
            else
                flag = 0;
            end
        else
            flag = 0;
        end
    else
        flag = 0;
    end
               

end