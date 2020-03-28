#!/bin/bash

if pandoc_cmd=$( command -v pandoc ) ; then

  [[ -z $1 ]] && { echo "Need a filename." ; exit 1 ; }
  filename_md="$1"
  filename_pdf="${filename_md%.*}.pdf"
  "$pandoc_cmd" -V "geometry:margin=2.5cm,a4paper" "$filename_md" -o "$filename_pdf"

else

  echo "It appears that there is no pandoc installed."
  exit 1

fi
