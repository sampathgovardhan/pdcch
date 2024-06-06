%% script to generate the stimulus for wn_cordic.v
clear all
len = 1000;
rng(10);

cordic_in = 1 - 2*rand(len,1) + 1i * (1 - 2*rand(len,1));
% add corner cases to input stimulus

% find reference sign out
sign_out(:,1) = real(cordic_in) < 0;
sign_out(:,2) = imag(cordic_in) < 0;

% find reference angle out
data_temp = abs(real(cordic_in)) + 1i * abs(imag(cordic_in));
angle_out = angle(data_temp);

% converting angle_in to fxp for rtl. /pi as rtl uses binary angles
angle_fxp = fi(angle_out/pi, 0, 16, 16);

% converting to fixed point
out_fxp = sfi(cordic_in, 24, 23);

fp = fopen("./stimulus/cordic_in.csv", "w");
fprintf(fp, "cos_tsin_t\n" );
for i = 1:len
    fprintf(fp, "%s%s\n", hex(imag(out_fxp(i))),hex(real(out_fxp(i))));
end
fclose(fp);

fp_out = fopen("./stimulus/cordic_out.csv", "w");
fprintf(fp_out, "angle_out, sign_out\n" );
for i = 1:len
    fprintf(fp_out, "%s, %d\n", hex(angle_fxp(i)), bi2de(sign_out(i,:)));
end
fclose(fp_out);