# ==================
# Gnuplot input file
# ==================
#
# To see this plot type:
#
#    gnuplot -persist 'my_job.QQ_plot.gnuplot'
#
# Alter the lines below to get the plot you want.

# Check version
if (GPVAL_VERSION<6.0) print 'Use gnuplot 6.0 or greater'; exit

set xlabel 'F_z (Gaussian)'
set ylabel 'F_z (exp) = ( F^{o} - F^{c} ) / {/Symbol s}'

# Plot options
set size square
unset key
set grid xtics
set grid ytics

# Axis ranges. The (h k l) labels were placed against these,
# so widen them and the labels drift; rerun Tonto to replace.
set xrange [-0.400000E+01:0.400000E+01]
set yrange [-0.100000E+02:0.100000E+02]

# Line of best fit
set fit quiet
l(x) = a*x + b
a = 1
b = 0.1
fit l(x) 'my_job.QQ_plot_with_hkl' using 1:2 via a,b

# Its equation, centred along the bottom of the plot
set label 1 sprintf('y = %.3f x + %.3f', a, b) at graph 0.5, graph 0.045 center front

# Plot
plot 'my_job.QQ_plot_with_hkl' using 1:2 \
        with points pt 7 ps 0.3 lc rgb 'dark-violet', \
     l(x) with lines lw 2 lc rgb 'skyblue', \
     'my_job.QQ_plot.labels' using 1:2:($5-$1):($6-$2) \
        with vectors nohead lw 1 lc rgb 'gray50', \
     'my_job.QQ_plot.labels' using 3:4:7 \
        with labels center font ',8' tc rgb 'red'

# PDF output
# Uncomment, or do it from the Qt window
# set terminal pdfcairo size 5,5
# set output 'my_job.QQ_plot.gnuplot.pdf'
# replot
