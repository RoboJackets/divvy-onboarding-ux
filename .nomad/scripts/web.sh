uwsgi --uwsgi-socket /var/opt/nomad/run/${NOMAD_JOB_NAME}-${NOMAD_ALLOC_ID}.sock --http-socket 0.0.0.0:${NOMAD_PORT_http} --chdir=/app/ --module=divvy_onboarding_ux.app
