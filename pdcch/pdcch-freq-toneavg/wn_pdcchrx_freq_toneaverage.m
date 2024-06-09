%%
% Copyright (c) 2016-2018, WiSig Networks Pvt Ltd. All rights reserved.
% www.wisig.com
%
% All information contained herein is property of WiSig Networks Pvt Ltd.
% unless otherwise explicitly mentioned.
%
% The intellectual and technical concepts in this file are proprietary
% to WiSig Networks and may be covered by granted or in process national
% and international patents and are protect by trade secrets and
% copyright law.
%
% Redistribution and use in source and binary forms of the content in
% this file, with or without modification are not permitted unless
% permission is explicitly granted by WiSig Networks.
% If WiSig Networks permits this source code to be used as a part of
% open source project, the terms and conditions of CC-By-ND (No Derivative) license
% (https://creativecommons.org/licenses/by-nd/4.0/) shall apply.
%%
clear all;


freq_res = randsample(45,45);
numbRxAnt = 2;
test_case = 1000;
file_config = fopen("freq_toneaverage_config.csv","w");
file_datain = fopen("freq_toneaverage_datain.csv","w");
file_out = fopen("freq_toneaverage_out.csv","w");
fprintf(file_out,"freq_TA1_real, freq_TA1_imag, freq_TA2_real, freq_TA2_imag\n");
fprintf(file_config,"symbols, avg_factor\n");
fprintf(file_datain,"real_A1, imag_A1, real_A2, imag_A2, tlast\n");

for i=1:test_case
    sym = randi([1,3],1,1);
    prb = freq_res(mod(i, 45) + 1);
     
    Length = prb * 3 * 6;
    temp = randi(3);
if temp == 1
    avg_factor        =   2;      % Value: 2,3,6
elseif temp == 2
    avg_factor       =   3;      % Value: 2,3,6
else
    avg_factor        =   6;      % Value: 2,3,6
end
    
DW = 2;
 fprintf(file_config,"%d, %d\n",sym,avg_factor);
%real = zeros(numbRxAnt,Length);
%imag = zeros(numbRxAnt,Length);

hMat(1).Est=zeros(Length,sym) ;
hMat(2).Est=zeros(Length,sym) ;



%% Data generation for data_in port
%generate random data corresponding to each RX antenna
%Qm.n fixed point format
m = DW;
n = 14;
for j=1:numbRxAnt

for cnt=1:sym

maxv = ((2^(m - 1)) - (2^(-n))) ;
minv = -(2^(m - 1));
mplusn = m + n;
%generate random data corresponding to each RX antenna
real1 = (rand(Length,1)*(maxv - minv) + minv);
real1 = sfi(real1, mplusn,n); % to convert to fixed point Q2.14 (signed)

imag1 = (rand(Length,1)*(maxv - minv) + minv);
imag1 = sfi(imag1, mplusn,n); % to convert to fixed point Q2.14 (signed)
hMat(j).Est(:,cnt) = complex(real1,imag1 );
end

%fprintf(file_out,"%0f\n",real(hMat(j).Est));
end

hAvg=wnNrPhyChnlAvgFreq(...
    avg_factor,...
    sym,...
    prb*6,...
    hMat,...
    numbRxAnt...
    );
    
  value_fp1 = fi(hAvg(1).Est,1,16,14);
  value_fp2 = fi(hAvg(2).Est,1,16,14);
  
  if avg_factor == 2
      count_max = prb *6 * 2;
      
  elseif avg_factor == 3
          count_max = prb * 6;
      else
          count_max = prb * 3;
          
  end
  for k1=1:sym
  for count1=1:count_max
          fprintf(file_out,"%s, %s, %s, %s\n",hex(real(value_fp1(count1,k1))),hex(imag(value_fp1(count1,k1))),hex(real(value_fp2(count1,k1))),hex(imag(value_fp2(count1,k1))));

  end
  end
  
  %fprintf(file_out,"%s, %s, %s, %s\n",hex(real(value_fp(l)));
  
  
  
r_t_1 = fi(hMat(1).Est,1,16,14);
    r_t_2 = fi(hMat(2).Est,1,16,14);
for count=1:sym
    for k=1:Length
        if(k == Length)
            tlast = 1;
        else
            tlast = 0;
        end
    fprintf(file_datain,"%s, %s, %s, %s, %d\n",hex(real(r_t_1(k,count))),hex(imag(r_t_1(k,count))),hex(real(r_t_2(k,count))),hex(imag(r_t_2(k,count))),tlast);
    
    end
    end

end
%% Channel averaging in Frequency 

function [hAvg]=wnNrPhyChnlAvgFreq(...
    channelAvgFactor,...
    Nsymb,...
    RBs,...
    hMat,...
    numbRxAnt...
    )

 hAvg(numbRxAnt).Est=[];
 
if(channelAvgFactor == 2)
    for rxAntIndx = 1:numbRxAnt
        
        for sym_ind=1:Nsymb
            index = 1;
            index1 = 1;
            for indx = 1:RBs
                
                hAvg(rxAntIndx).Est(index1,sym_ind) = ((hMat(rxAntIndx).Est(index,sym_ind)+hMat(rxAntIndx).Est(index+1,sym_ind))*0.707)/2;
                
                hAvg(rxAntIndx).Est(index1 + 1,sym_ind) = ((hMat(rxAntIndx).Est(index+1,sym_ind)+hMat(rxAntIndx).Est(index+2,sym_ind))*0.707)/(2);
                
                index = index+3;
                index1 = index1 + 2;
                
            end
        end
    end
end


if(channelAvgFactor == 3)
    for rxAntIndx = 1:numbRxAnt
        
        for sym_ind = 1:Nsymb
            index = 1;
            index1 = 1;
            for indx = 1:RBs
                
                hAvg(rxAntIndx).Est(index1,sym_ind) = ((hMat(rxAntIndx).Est(index,sym_ind)+hMat(rxAntIndx).Est(index+1,sym_ind)+hMat(rxAntIndx).Est(index+2,sym_ind))*0.707)/(3);
                index = index+3;
                index1= index1 + 1;
            end
        end
    end
end

if(channelAvgFactor == 6)
    for rxAntIndx = 1:numbRxAnt
        for sym_ind = 1:Nsymb
            index1 = 1;
            index = 1;
            for indx = 1:RBs/2
                
                hAvg(rxAntIndx).Est(index1,sym_ind) = ((hMat(rxAntIndx).Est(index,sym_ind)+hMat(rxAntIndx).Est(index+1,sym_ind)+hMat(rxAntIndx).Est(index+2,sym_ind)+hMat(rxAntIndx).Est(index+3,sym_ind)+hMat(rxAntIndx).Est(index+4,sym_ind)+hMat(rxAntIndx).Est(index+5,sym_ind))*0.707)/(6);
                index = index+6;
                index1 = index1 + 1;
                
            end
        end
    end
end
end
