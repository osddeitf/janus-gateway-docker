
echo Watching $1...

inotifywait --monitor -e close_write --format %f $1 |\
  grep --line-buffered '\.mjr' | \
  xargs -d'\n' -n1 -I{} \
    sh -c "tsp ./post-process.sh {} > /dev/null && echo [tsp]: Added \'{}\' to post-process queue."
