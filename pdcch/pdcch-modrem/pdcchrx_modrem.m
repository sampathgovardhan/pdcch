numbRxAnt = 2;
test_case = 1000;
length = 20;
file_dmrs_in = fopen("./modrem_dmrs_in.csv","w");
file_datain = fopen("./modrem_datain.csv","w");
file_out = fopen(".modrem_out.csv","w");
fprintf(file_out,"real_A1, imag_A1, real_A2, imag_A2, tlast\n");
fprintf(file_dmrs_in,"dmrs\n");
fprintf(file_datain,"real_A1, imag_A1, real_A2, imag_A2, tlast\n");



for i=1:test_case
    %sym = randi([1,3],1,1);
    %prb = freq_res(mod(i, 45) + 1);
   
dmrs_complex = zeros(length,1);
dmrs = zeros(length,1);

dmrs_real = randi([0,1],length,1);
dmrs_imag = randi([0,1],length,1);
dmrs = dmrs_real + 2*dmrs_imag;
dmrs_real1 = 1- 2 * dmrs_real;
dmrs_imag1 = 1- 2 * dmrs_imag;


dmrs_complex(:,1) = complex(dmrs_real1,dmrs_imag1 );



      DW = 1;
 %fprintf(file_config,"%d, %d\n",sym,prb);



hMat(1).Est=zeros(length,1) ;
hMat(2).Est=zeros(length,1) ;



%% Data generation for data_in port
%generate random data corresponding to each RX antenna
%Qm.n fixed point format
m = DW;
n = 15;
for j=1:numbRxAnt



maxv = ((2^(m - 1)) - (2^(-n))) ;
minv = -(2^(m - 1));
mplusn = m + n;
%generate random data corresponding to each RX antenna
real1 = (rand(length,1)*(maxv - minv) + minv);
real1 = sfi(real1, mplusn,n); % to convert to fixed point Q1.15 (signed)

imag1 = (rand(length,1)*(maxv - minv) + minv);
imag1 = sfi(imag1, mplusn,n); % to convert to fixed point Q1.15 (signed)
hMat(j).Est(:,1) = complex(real1,imag1 );




%fprintf(file_out,"%0f\n",real(hMat(j).Est));
end

r_t_1 = fi(hMat(1).Est,1,16,15);
    r_t_2 = fi(hMat(2).Est,1,16,15);

    modrem_r_tt_1 = r_t_1.*conj(dmrs_complex);
    modrem_r_tt_2 =  r_t_2.*conj(dmrs_complex);

     modrem_r_t_1 = fi(modrem_r_tt_1,1,16,14);
    modrem_r_t_2 =  fi(modrem_r_tt_2,1,16,14);

    for k=1:length
        if(k == length)
            tlast = 1;
        else
            tlast = 0;
        end
     fprintf(file_datain,"%s, %s, %s, %s, %d\n",hex(real(r_t_1(k,1))),hex(imag(r_t_1(k,1))),hex(real(r_t_2(k,1))),hex(imag(r_t_2(k,1))),tlast);
     fprintf(file_dmrs_in,"%d\n",dmrs(k,1));
      fprintf(file_out,"%s, %s, %s, %s, %d\n",hex(real(modrem_r_t_1(k,1))),hex(imag(modrem_r_t_1(k,1))),hex(real(modrem_r_t_2(k,1))),hex(imag(modrem_r_t_2(k,1))),tlast);
     end

end

fclose(file_dmrs_in);
fclose(file_out);
fclose(file_datain);