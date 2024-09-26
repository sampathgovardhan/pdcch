%% script to generate the stimulus for wn_cordic.v

len = 1;

% generates angle b/w 0 to pi/2
angle_in = 1/2 * rand(len,1);
disp(angle_in);
% generate random sign bits
sign_in = randi([0,3], len,1);
sign_in
% compute reference angle
cordic_out = exp(1i * angle_in);
disp(cordic_out);
% converting angle_in to fxp for rtl. /pi as rtl uses binary angles
angle_fxp = fi(angle_in, 0, 16, 16);

for i = 1:len
    if(sign_in(i) == 0)
        cordic_out_signed(i,1) = cordic_out(i);
    elseif(sign_in(i) == 1)
        cordic_out_signed(i,1) =  real(cordic_out(i)) + -1i*imag(cordic_out(i));
    elseif(sign_in(i) == 2)
        cordic_out_signed(i,1) = 1i * imag(cordic_out(i)) + -1*real(cordic_out(i));
    else 
        cordic_out_signed(i,1) = -1 * cordic_out(i);
    end
end

% converting to fixed point
out_fxp = fi(cordic_out_signed,1, 16, 15);
out_fxp
fp = fopen("./stimulus/cordic_in.csv", "w");
fprintf(fp, "angle_in_q2_14, sign_in\n" );
for i = 1:len
    fprintf(fp, "%s, %d\n", hex(angle_fxp(i)), sign_in(i));
end
fclose(fp);

fp_out = fopen("./stimulus/cordic_out.csv", "w");
fprintf(fp_out, "cos_t_sin_t\n" );
for i = 1:len
    fprintf(fp_out, "%s%s\n", hex(imag(out_fxp(i))), hex(real(out_fxp(i))));
end
fclose(fp_out);