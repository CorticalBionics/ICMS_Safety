function [subject_list, num_subjects] = GetSubjectList(alt)
    if nargin == 0
        alt = false;
    end

    if alt
        subject_list = {'C1', 'C2', 'P2', 'P3', 'P4'};
    else
        subject_list = {'BCI02', 'BCI03', 'CRS02b', 'CRS07', 'CRS08'};
    end
    num_subjects = length(subject_list);
end