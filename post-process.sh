
REC_NAME=$(echo $1 | sed -E 's/-(audio|video).mjr$//')
REC_TYPE=$(echo $1 | sed -E 's/.*-(audio|video).mjr$/\1/')
MUX_NAME=$(echo $1 | sed -E 's/^videoroom-(\w+)-.*$/videoroom-\1.mp4/')

INPUT=/data/$1
VIDEO_PP=/tmp/${REC_NAME}-video.mp4
AUDIO_PP=/tmp/${REC_NAME}-audio.opus
MUX_OUTPUT=/tmp/$MUX_NAME

# Janus post-process .mjr $INPUT
if [ $REC_TYPE = 'video' ]; then
  janus-pp-rec $INPUT $VIDEO_PP
fi

if [ $REC_TYPE = 'audio' ]; then
  janus-pp-rec $INPUT $AUDIO_PP
fi

# Process if inputs are adequate
if [ -f $VIDEO_PP ]; then
  if [ -f $AUDIO_PP ]; then
    # ffmpeg muxing -> upload to minio
    ffmpeg -i $VIDEO_PP -i $AUDIO_PP $MUX_OUTPUT && \
    mc cp $MUX_OUTPUT s3/$S3_BUCKET/$MUX_NAME && \
    rm -f $AUDIO_PP $VIDEO_PP $MUX_OUTPUT && \
    rm -f /data/${REC_NAME}-video.mjr /data/${REC_NAME}-audio.mjr
  fi
fi
