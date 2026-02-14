function chan = es_channel_flip(chan)
    % "flip" the es cable stim connector and output the equivalent channel number
    % cerestim omnetics cable pinout
    pinout = [
        01 02;
        03 04;
        05 06;
        07 08;
        09 10;
        11 12;
        13 14;
        15 16;
        17 18;
        19 20;
        21 22;
        23 24;
        25 26;
        27 28;
        29 30;
        31 32
        ];
    
    flippedpinout = rot90(pinout, 2);
    
    % find chan index and flip. Account for banks.
    bank_num = floor((chan-1)/32);
    mchan = mod(chan-1, 32) + 1;
    
    mchan = flippedpinout(find(pinout == mchan, 1));
    chan = mchan + bank_num*32;
end