freq_res = randsample(45,45);
numbRxAnt = 1;
test_case = 1000;
file_config = fopen("./angle_repeator_config.csv","w");
file_datain = fopen("./angle_repeator_datain.csv","w");
file_out = fopen("./angle_repeator_out.csv","w");
fprintf(file_out,"real, imag, tlast\n");
fprintf(file_config,"int_flag,symbols, prb\n");
fprintf(file_datain,"real_A1, imag_A1, tlast\n");


for i=1:test_case
    sym = randi([1,3],1,1);
    prb = freq_res(mod(i, 45) + 1);
   
% int_flag = randi([0,1],1,1);
    int_flag=0;
   
  if int_flag == 1
      Length = prb * 6;
      count_max = 1;
  else
      if sym == 2
      Length = prb * 2;
      count_max = 3;
      
  elseif sym == 3
          Length = prb * 3;
          count_max = 2;
      else
          Length = prb;
          count_max = 6;
      end
  end

      DW = 1;
 fprintf(file_config,"%d,%d,%d\n",int_flag,sym,prb);



hMat(1).Est=zeros(Length,1) ;
hMat(2).Est=zeros(Length,1) ;



%% Data generation for data_in port
%generate random data corresponding to each RX antenna
%Qm.n fixed point format
m = DW;
n = 23;
for j=1:numbRxAnt



maxv = ((2^(m - 1)) - (2^(-n))) ;
minv = -(2^(m - 1));
mplusn = m + n;
%generate random data corresponding to each RX antenna
real1 = (rand(Length,1)*(maxv - minv) + minv);
real1 = sfi(real1, mplusn,n); % to convert to fixed point Q1.23 (signed)

imag1 = (rand(Length,1)*(maxv - minv) + minv);
imag1 = sfi(imag1, mplusn,n); % to convert to fixed point Q1.23 (signed)
hMat(j).Est(:,1) = complex(real1,imag1 );




%fprintf(file_out,"%0f\n",real(hMat(j).Est));
end

r_t_1 = fi(hMat(1).Est,1,24,23);
    r_t_2 = fi(hMat(2).Est,1,24,23);
    l = 1;

     for k=1:Length
        if(k == Length)
            tlast = 1;
        else
            tlast = 0;
        end
    fprintf(file_datain,"%s, %s, %d\n",hex(real(r_t_1(k,1))),hex(imag(r_t_1(k,1))),tlast);
    
     end

     if(sym == 2)

         for count= 1:sym
         for k=1:Length
             for counter = 1:count_max
        if(k == Length && counter == count_max)
            tlast = 1;
        else
            tlast = 0;
        end
fprintf(file_out,"%s, %s, %d\n",hex(real(r_t_1(k,1))),hex(imag(r_t_1(k,1))),tlast);             end
     end
     end
     elseif(sym == 3)
     for count= 1:sym
         for k=1:Length
             for counter = 1:count_max
        if(k == Length && counter == count_max)
            tlast = 1;
        else
            tlast = 0;
        end
fprintf(file_out,"%s, %s, %d\n",hex(real(r_t_1(k,1))),hex(imag(r_t_1(k,1))),tlast);             end
     end
     end

     else
     for count= 1:sym
         for k=1:Length
             for counter = 1:count_max
        if(k == Length && counter == count_max)
            tlast = 1;
        else
            tlast = 0;
        end
fprintf(file_out,"%s, %s, %d\n",hex(real(r_t_1(k,1))),hex(imag(r_t_1(k,1))),tlast);
             end
     end
     end
     end

end