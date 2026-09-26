#!/bin/sh
set -eu

cluster_root=/tmp/prova_social_postgres_5433
data_dir="$cluster_root/data"
socket_dir="$cluster_root/socket"
log_file="$cluster_root/postgresql.log"
port=5433

if [ "${data_dir}" != /tmp/prova_social_postgres_5433/data ]; then
  echo "Diretório de dados inesperado; inicialização recusada." >&2
  exit 1
fi

mkdir -p "$data_dir" "$socket_dir"
chown -R postgres:postgres "$cluster_root"
chmod 700 "$data_dir"
chmod 770 "$socket_dir"

if [ -f "$data_dir/PG_VERSION" ] && [ ! -s "$data_dir/global/pg_control" ]; then
  echo "Cluster local incompleto: global/pg_control ausente. Preserve o diretório para diagnóstico antes de recriar o ambiente descartável." >&2
  exit 1
fi

if [ ! -f "$data_dir/PG_VERSION" ]; then
  if [ -n "$(find "$data_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "Diretório não vazio sem PG_VERSION; inicialização recusada." >&2
    exit 1
  fi
  su postgres -s /bin/sh -c \
    "initdb -D '$data_dir' --encoding=UTF8 --locale=C --auth-local=trust --auth-host=reject"
  cat >>"$data_dir/postgresql.conf" <<EOF
port = $port
listen_addresses = '127.0.0.1'
unix_socket_directories = '$socket_dir'
fsync = off
synchronous_commit = off
full_page_writes = off
EOF
  chown postgres:postgres "$data_dir/postgresql.conf"
fi

if su postgres -s /bin/sh -c "pg_ctl -D '$data_dir' status" >/dev/null 2>&1; then
  echo "PostgreSQL local já está ativo na porta $port."
  exit 0
fi

su postgres -s /bin/sh -c \
  "pg_ctl -D '$data_dir' -l '$log_file' -w start"
echo "PostgreSQL local iniciado: socket=$socket_dir porta=$port"
