set terminal qt linewidth 3 font "Sans,12" size 1024,768
set size
set title "Compilation times with and without unity builds, Release with ccache."
set xlabel "Number of files modified before compiling."
set ylabel "Compilation time in seconds."

set key reverse above Left maxrows 2

set xrange [0:50]

plot "weak-function.data" using 1:3 title "wfl unity build" \
                with lines linetype 1, \
     "weak-function.data" using 1:4 title "wfl classic build" \
                with lines linetype 1 dashtype 2, \
     "tweenerspp.data" using 1:3 title "tweenerspp unity build" \
                       with lines linetype 6, \
     "tweenerspp.data" using 1:4 title "tweenerspp classic build" \
                       with lines linetype 6 dashtype 2, \
     "iscool-core.data" using 1:3 title "iscool::core unity build" \
                        with lines linetype 7, \
     "iscool-core.data" using 1:4 title "iscool::core classic build" \
                        with lines linetype 7 dashtype 2
     