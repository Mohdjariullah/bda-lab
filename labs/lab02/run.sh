#!/usr/bin/env bash
# Lab 2 - Data Visualization in Python (manual: lab2_visualization.py)

lab_main() {
  ensure_python || die "Python is not available"
  ensure_pymods numpy:numpy:python3-numpy pandas:pandas:python3-pandas \
                matplotlib:matplotlib:python3-matplotlib seaborn:seaborn:python3-seaborn \
    || die "Required Python packages are missing"

  lab_workdir lab02
  cp "$LAB_DIR/lab2_visualization.py" .
  rm -f visualization_output.png

  step 1 "Program source"
  show "cat lab2_visualization.py"; cat lab2_visualization.py

  step 2 "Run the program"
  if has_display; then
    run python3 lab2_visualization.py || die "Program failed"
  else
    # no display: force the file backend so matplotlib does not look for a window
    run env MPLBACKEND=Agg python3 lab2_visualization.py || die "Program failed"
  fi
  [ -f visualization_output.png ] || die "visualization_output.png was not created"
  cp visualization_output.png "$LAB_RESULTS/"
  run ls -l visualization_output.png

  if has_display && have xdg-open; then
    step 3 "Open the image"
    show "xdg-open visualization_output.png &"
    (xdg-open "$LAB_WORK/visualization_output.png" >/dev/null 2>&1 &)
  fi
  note_ok "visualization_output.png saved in $LAB_WORK (copy in $LAB_RESULTS)"
}
