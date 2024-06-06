

clear all;
%rng(10);
%frequencyoffset_flag = 1;
%interleaver_flag = 1;
freq_res = randsample(45,45);
%disp(freq_res);
numbRxAnt = 2;
test_case =1000;
file_config = fopen("frequencyoffset_config.csv","w");
file_datain = fopen("frequencyoffset_datain.csv","w");
file_out = fopen("frequencyoffset_out.csv","w");
fprintf(file_out,"real, imag\n");
fprintf(file_config,"frequencyoff_flag, symbols, interleave_flag, prbs\n");
fprintf(file_datain,"real_A1, imag_A1, real_A2, imag_A2, tlast\n");

for i=1:test_case
    sym = randi([1,3],1,1);
    prb = freq_res(mod(i, 45) + 1);
   % disp(prb);
    Length = prb * 3 * 6;
    frequencyoffset_flag = randi([0,1],1,1);
    interleaver_flag = randi([0,1],1,1);
DW = 2;
 fprintf(file_config,"%d, %d, %d, %d\n",frequencyoffset_flag,sym,interleaver_flag,prb);
%real = zeros(numbRxAnt,Length);
%imag = zeros(numbRxAnt,Length);

hMat(1).Est=zeros(Length,sym) ;
hMat(2).Est=zeros(Length,sym) ;
%total_testcases = 150;

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
counter = 0;
 r_t_1 = fi(hMat(1).Est,1,16,14);
    r_t_2 = fi(hMat(2).Est,1,16,14);
   % im_t=real(r_t);
    %end
    for count=1:sym
    for k=1:Length
        

       % if(interleaver_flag)
           % counter = counter + 1;
            %if(counter == 3)
             %  tlast = 1;
               %counter = 0;
           % else
            %tlast=0;
            %end

        %else
         if(k == Length)
            tlast = 1;
          else
            tlast = 0;
        end
       %end
    fprintf(file_datain,"%s, %s, %s, %s, %d\n",hex(real(r_t_1(k,count))),hex(imag(r_t_1(k,count))),hex(real(r_t_2(k,count))),hex(imag(r_t_2(k,count))),tlast);
    
    end
    end
if(frequencyoffset_flag == 1 && sym > 1)

    value = wnNrPhyFreqOffsetEstimation(prb*6,...                         % Number of resource blocks
    sym,...                                                               % Number of symbols
    hMat,...
    interleaver_flag,...
    numbRxAnt...                                                          % Number of receiver antennas  
    );

%a=real(value);
%b=imag(value);
    %for k=1:prb/6
    value_fp = fi(value,1,24,23);


    if(interleaver_flag == 1)
    for l=1:(prb*6)
    fprintf(file_out,"%s, %s\n",hex(real(value_fp(l))),hex(imag(value_fp(l))));
    end
        
    else
    for l=1:(prb*6*sym)/6
    fprintf(file_out,"%s, %s\n",hex(real(value_fp(l))),hex(imag(value_fp(l))));
    end
    end
   
    
else
    if(interleaver_flag == 1)
        count_0 = prb*6;
    else
        count_0 = prb*sym;
    end
    %for k=0:sym - 1
    for count=0:count_0 - 1
        real_t = 0.999999;
        imag_t = 0.00000;
        real_t = fi(real_t,1,24,23);
        imag_t = fi(imag_t,1,24,23);
        fprintf(file_out,"%s, %s\n",hex(real(real_t)),hex(imag(imag_t)));
    end
    %end
end
end

fclose(file_config);
fclose(file_out);
fclose(file_datain);

function[value_rx]=wnNrPhyFreqOffsetEstimation(RBs,...                       % Number of resource blocks
    Nsymb,...                                                               % Number of symbols
    hMat,...
    interleaver_flag,...
    numbRxAnt...                                                            % Number of receiver antennas
    )


nCCEs = (RBs*Nsymb)/6;

value = zeros(numbRxAnt,nCCEs);

for rxAntIndx = 1 : numbRxAnt
    
    if  interleaver_flag==0
        
        temp = 1;
        
        for CCEindex = 1 : nCCEs
            
            count=0;
            
            sum1=0;
            
            for RBind=1 : 6/Nsymb
                tempSymb=Nsymb;
                
                
                while tempSymb ~= 1
                    
                    sum1 = sum1+sum([hMat(rxAntIndx).Est(temp,tempSymb).*conj(hMat(rxAntIndx).Est(temp,tempSymb-1)),...
                        hMat(rxAntIndx).Est(temp+1,tempSymb).*conj(hMat(rxAntIndx).Est(temp+1,tempSymb-1)),...
                        hMat(rxAntIndx).Est(temp+2,tempSymb).*conj(hMat(rxAntIndx).Est(temp+2,tempSymb-1))]);
                    
                    count=count+3;
                    
                    tempSymb=tempSymb-1;
                    
                end
                
                temp = temp+3;
            end
            
            if Nsymb == 1
                value(rxAntIndx,CCEindex) = sum1;
            else
            value(rxAntIndx,CCEindex) = sum1/count;
            end
        end
        
    else
        
        temp = 1;
        
        for RBind = 1 : RBs
            
            count=0;
            
            sum1=0;
            
            tempSymb=Nsymb;
            
            
            while tempSymb ~= 1
                
                  sum1 = sum1+sum([hMat(rxAntIndx).Est(temp,tempSymb).*conj(hMat(rxAntIndx).Est(temp,tempSymb-1)),...
                        hMat(rxAntIndx).Est(temp+1,tempSymb).*conj(hMat(rxAntIndx).Est(temp+1,tempSymb-1)),...
                        hMat(rxAntIndx).Est(temp+2,tempSymb).*conj(hMat(rxAntIndx).Est(temp+2,tempSymb-1))]);
                
                count=count+3;
                
                tempSymb=tempSymb-1;
                
            end
            
            temp = temp+3;
            value(rxAntIndx,RBind) = (sum1/count);
        end
        
        
    end
end

value_rx=sum(value)/(numbRxAnt*4);

%theta=angle(value_rx);

%if  interleaver_flag == 0
    
    
   % for CCEindex = 1 : nCCEs
        
       % expBeta((CCEindex-1)*(6/Nsymb)*12+1:(CCEindex)*(6/Nsymb)*12) =  theta(CCEindex);
        
    %end
    
    
%else
    
   % for RBind = 1 : RBs
        
       % expBeta((RBind-1)*12+1:(RBind)*12) =  theta(RBind);
        
    %end
    
%end
end
