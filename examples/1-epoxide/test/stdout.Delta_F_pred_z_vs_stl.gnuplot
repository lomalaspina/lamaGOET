# ==================
# Gnuplot input file
# ==================
#
# To see this plot type:
#
#    gnuplot -persist 'stdout.Delta_F_pred_z_vs_stl.gnuplot'
#
# Alter the lines below to get the plot you want.

# Check version
if (GPVAL_VERSION<6.0) print 'Use gnuplot 6.0 or greater'; exit

set xlabel 'sin({/Symbol q})/{/Symbol l}'
set ylabel '[ F^{c}(no ext) - F^{c}(ext) ] / {/Symbol s}'

# Plot options
set size square
unset key
set grid xtics
set grid ytics

# Axis ranges. The (h k l) labels were placed against these,
# so widen them and the labels drift; rerun Tonto to replace.
set xrange [0.000000E+00:0.600000E+00]
set yrange [-0.100000E+01:0.700000E+01]

# Plot
plot 'stdout.Delta_F_pred_z_vs_stl' using 1:2 \
        with points pt 7 ps 0.3 lc rgb 'dark-violet', \
     'stdout.Delta_F_pred_z_vs_stl.labels' using 1:2:($5-$1):($6-$2) \
        with vectors nohead lw 1 lc rgb 'gray50', \
     'stdout.Delta_F_pred_z_vs_stl.labels' using 3:4:7 \
        with labels center font ',8' tc rgb 'red'

# PDF output
# Uncomment, or do it from the Qt window
# set terminal pdfcairo size 5,5
# set output 'stdout.Delta_F_pred_z_vs_stl.gnuplot.pdf'
# replot
