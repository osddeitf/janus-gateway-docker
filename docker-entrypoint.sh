
# Config s3 host if not yet done.
mc config host list s3 > /dev/null 2>&1
status=$?
if [ $status != 0 ]; then
  # Try again upto 3 times, waiting 5s each
  for i in $(seq 1 3); do
    echo "Trying connect to s3..."
    mc config host add s3 $S3_ENDPOINT $S3_ACCESS_KEY $S3_SECRET_KEY && s=0 && break
    s=$?

    if [ $i = 3 ]; then
      echo "Error connecting to s3." >&2
      exit $s
    else
      sleep 5
    fi
  done;

  # Create bucket if not existed
  mc mb s3/$S3_BUCKET

  # If webhook enabled via MINIO_NOTIFY_WEBHOOK_ENDPOINT
  arn=$(mc admin info s3 --json | jq -r .info.sqsARN[] | grep '_:webhook')
  if [ $arn ]; then
    mc event remove s3/$S3_BUCKET $arn
    mc event add s3/$S3_BUCKET $arn --event put
  fi
fi

inotifywait -e close_write --format %f --monitor /data |\
  xargs -d'\n' -n1 -I{} \
    sh -c "tsp ./post-process.sh {} > /dev/null && echo Added \'{}\' to post-process queue."
