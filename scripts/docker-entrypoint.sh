
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

# Add file extensions .mjr -> .mjr.tmp
sed -i 's/#recordings_tmp_ext/recordings_tmp_ext="tmp"#/' /usr/local/etc/janus/janus.jcfg

# Check the existence of $RECORD_DIR
[ -f $RECORD_DIR ] || mkdir $RECORD_DIR
if [ ! -d $RECORD_DIR ]; then
  echo $RECORD_DIR is not a directory > /dev/stderr
  exit 1
fi

# Watch
tsp -S 2
tsp ./watch.sh $RECORD_DIR

# Janus
cd $RECORD_DIR && janus
