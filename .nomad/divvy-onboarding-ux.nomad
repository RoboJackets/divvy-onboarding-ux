variable "image" {
  type = string
  description = "The image to use for running the service"
}

variable "hostname" {
  type = string
  description = "The hostname for this instance of the service"
}

locals {
  # compressed in this context refers to the config string itself, not the assets
  compressed_nginx_configuration = trimspace(
    trimsuffix(
      trimspace(
        regex_replace(
          regex_replace(
            regex_replace(
              regex_replace(
                regex_replace(
                  regex_replace(
                    regex_replace(
                      regex_replace(
                        trimspace(
                          file("conf/nginx.conf")
                        ),
                        "server\\s{\\s",      # remove server keyword and opening bracket (autogenerated in nginx nomad job)
                        ""
                      ),
                      "server_name\\s\\S+;",  # remove server_name directive (autogenerated in nginx nomad job)
                      ""
                    ),
                    "root\\s\\S+;",           # remove root directive (autogenerated in nginx nomad job)
                    ""
                  ),
                  "listen\\s.+;",             # remove listen directive  (autogenerated in nginx nomad job)
                  ""
                ),
                "#.+\\n",                     # remove comments (no semantic difference)
                ""
              ),
              ";\\s+",                        # remove whitespace after semicolons (no semantic difference)
              ";"
            ),
            "{\\s+",                          # remove whitespace after opening brackets (no semantic difference)
            "{"
          ),
          "\\s+",                             # replace any occurrence of one or more whitespace characters with single space (no semantic difference)
          " "
        )
      ),
      "}"                                     # remove trailing closing bracket (autogenerated in nginx nomad job)
    )
  )
}

job "divvy-onboarding-ux" {
  region = "campus"

  datacenters = ["bcdc"]

  type = "service"

  group "divvy-onboarding-ux" {
    volume "assets" {
      type = "host"
      source = "assets"
    }

    network {
      port "http" {}
    }

    volume "run" {
      type = "host"
      source = "run"
    }

    task "prestart" {
      driver = "docker"

      lifecycle {
        hook = "prestart"
      }

      config {
        image = var.image

        force_pull = true

        network_mode = "host"

        entrypoint = [
          "/bin/bash",
          "-xeuo",
          "pipefail",
          "-c",
          trimspace(file("scripts/prestart.sh"))
        ]
      }

      resources {
        cpu = 100
        memory = 128
        memory_max = 2048
      }

      volume_mount {
        volume = "assets"
        destination = "/assets/"
      }
    }

    task "web" {
      driver = "docker"

      config {
        image = var.image

        force_pull = true

        network_mode = "host"

        entrypoint = [
          "/usr/local/bin/uwsgi",
          "--master",
          "--enable-threads",
          "--processes=4",
          "--uwsgi-socket",
          "/var/opt/nomad/run/${NOMAD_JOB_NAME}-${NOMAD_ALLOC_ID}.sock",
          "--chmod-socket=777",
          "--http-socket",
          "0.0.0.0:${NOMAD_PORT_http}",
          "--chdir=/app/",
          "--module=divvy_onboarding_ux:app",
          "--buffer-size=8192",
          "--single-interpreter",
        ]
      }

      resources {
        cpu = 100
        memory = 256
        memory_max = 2048
      }

      volume_mount {
        volume = "run"
        destination = "/var/opt/nomad/run/"
      }

      template {
        data = trimspace(file("conf/.env.tpl"))

        destination = "/secrets/.env"
        env = true
      }

      template {
        data = "SENTRY_RELEASE=\"${split("@", var.image)[1]}\""

        destination = "/secrets/.sentry_release"
        env = true
      }

      service {
        name = "${NOMAD_JOB_NAME}"

        port = "http"

        tags = [
          "uwsgi",
          "http",
        ]

        check {
          success_before_passing = 3
          failures_before_critical = 2

          interval = "5s"

          name = "GET /ping"
          path = "/ping"
          port = "http"
          protocol = "http"
          timeout = "1s"
          type = "http"
          header {
            Host = [var.hostname]
          }
        }

        check_restart {
          limit = 5
          grace = "20s"
        }

        meta {
          nginx-config = local.compressed_nginx_configuration
          socket = "/var/opt/nomad/run/${NOMAD_JOB_NAME}-${NOMAD_ALLOC_ID}.sock"
          firewall-rules = jsonencode(["internet"])
        }
      }

      restart {
        attempts = 1
        delay = "10s"
        interval = "1m"
        mode = "fail"
      }
    }
  }

  update {
    healthy_deadline = "5m"
    progress_deadline = "10m"
    auto_revert = true
    auto_promote = true
    canary = 1
  }
}
