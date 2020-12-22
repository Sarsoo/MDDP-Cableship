function power = get_extra_p(length, offset, seconds, power)
%GET_EXTRA_P Summary of this function goes here

power = [zeros(1, offset) repmat(power, 1, seconds) zeros(1, (length - offset - seconds))];

end

