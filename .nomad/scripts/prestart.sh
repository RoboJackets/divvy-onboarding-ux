mkdir --parents /assets/${NOMAD_JOB_NAME}/
cp --recursive --verbose static/* /assets/${NOMAD_JOB_NAME}/static/
