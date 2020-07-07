
rec_name=$(echo $1 | sed -E 's/-(audio|video).mjr$//')
rec_type=$(echo $1 | sed -E 's/.*-(audio|video).mjr$/\1/')
mux_name=$(echo $1 | sed -E 's/^videoroom-(\w+)-.*$/videoroom-\1.mp4/')

video_in=$RECORD_DIR/${rec_name}-video.mjr
audio_in=$RECORD_DIR/${rec_name}-audio.mjr
object=$S3_BUCKET/$mux_name

video_pp=/tmp/${rec_name}-video.mp4
audio_pp=/tmp/${rec_name}-audio.opus
mux_output=/tmp/$mux_name

# Janus post-process .mjr
if [ $rec_type = 'video' ]; then
  janus-pp-rec $video_in $video_pp
fi

if [ $rec_type = 'audio' ]; then
  janus-pp-rec $audio_in $audio_pp
fi

# Process if inputs are adequate
if [ -f $video_pp ]; then
  if [ -f $audio_pp ]; then
    # ffmpeg muxing -> upload to minio
    ffmpeg -i $video_pp -i $audio_pp $mux_output && \
    mc cp $mux_output s3/$object && \
    rm -f $audio_pp $video_pp $mux_output && \
    rm -f $video_in $audio_in
  fi
fi
