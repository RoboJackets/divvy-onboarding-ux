mkdir --parents /assets/${NOMAD_JOB_NAME}/static/
cp --recursive --verbose static/* /assets/${NOMAD_JOB_NAME}/static/
cp --verbose static/robots.txt /assets/${NOMAD_JOB_NAME}/
