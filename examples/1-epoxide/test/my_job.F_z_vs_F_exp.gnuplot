# ==================
# Gnuplot input file
# ==================
#
# To see this plot type:
#
#    gnuplot -persist 'my_job.F_z_vs_F_exp.gnuplot'
#
# Alter the lines below to get the plot you want.

# Check version
if (GPVAL_VERSION<6.0) print 'Use gnuplot 6.0 or greater'; exit

set xlabel 'F^{o}'
set ylabel 'F_z = ( F^{o} - F^{c} ) / {/Symbol s}'

# Plot options
set size square
unset key
set grid xtics
set grid ytics

# Axis ranges. The (h k l) labels were placed against these,
# so widen them and the labels drift; rerun Tonto to replace.
set xrange [0.000000E+00:0.500000E+02]
set yrange [-0.100000E+02:0.100000E+02]

# Plot
plot 'my_job.F_z_vs_F_exp' using 1:2 \
        with points pt 7 ps 0.3 lc rgb 'dark-violet', \
     'my_job.F_z_vs_F_exp.labels' using 1:2:($5-$1):($6-$2) \
        with vectors nohead lw 1 lc rgb 'gray50', \
     'my_job.F_z_vs_F_exp.labels' using 3:4:7 \
        with labels center font ',8' tc rgb 'red'

# PDF output
# Uncomment, or do it from the Qt window
# set terminal pdfcairo size 5,5
# set output 'my_job.F_z_vs_F_exp.gnuplot.pdf'
# replot
