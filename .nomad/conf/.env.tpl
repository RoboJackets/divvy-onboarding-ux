{{ range $key, $value := (key (printf "divvy-onboarding-ux/%s" (slice (env "NOMAD_JOB_NAME") 20)) | parseJSON) -}}
{{- $key | trimSpace -}}={{- $value | toJSON }}
{{ end -}}
SENTRY_ENVIRONMENT={{ slice (env "NOMAD_JOB_NAME") 20 }}
