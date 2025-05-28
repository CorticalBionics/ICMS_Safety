function [year1,year2,year3,year4,year5,year6,year7,year8,year9,last_year] = sort_dates(dates)

[a,i] = sort(dates,'ascend');
first_date = dates(i(1));
last_date = dates(i(end));
year1 = last_date;
year2 = last_date;
year3 = last_date;
year4 = last_date;
year5 = last_date;
year6 = last_date;
year7 = last_date;
year8 = last_date;
year9 = last_date;
last_year = last_date;
in_between = calmonths(between(first_date,last_date));
for d=1:numel(dates) % determine 4 equally spaced time points for this person
    current = calmonths(between(first_date,dates(i(d))));
    if current < 12
        year1 = dates(i(d));
    elseif current >= 12 && current < 2*12
        year2 = dates(i(d));
    elseif current >= 2*12 && current < 3*12
        year3 = dates(i(d));
    elseif current >= 3*12 && current < 4*12
        year4 = dates(i(d));
    elseif current >= 4*12 && current < 5*12
        year5 = dates(i(d));
    elseif current >= 5*12 && current < 6*12
        year6 = dates(i(d));
    elseif current >= 6*12 && current < 7*12
        year7 = dates(i(d));
    elseif current >= 7*12 && current < 8*12
        year8 = dates(i(d));
    elseif current >= 8*12 && current < 9*12
        year9 = dates(i(d));
    end
    if calmonths(between(dates(i(d)),max(dates))) <= 12
        last_year = dates(i(d));
        break;
    end
end
