#!/bin/sh
set -eu

cluster_root=/tmp/prova_social_postgres_5433
data_dir="$cluster_root/data"

if [ "$data_dir" != /tmp/prova_social_postgres_5433/data ]; then
  echo "Diretório de dados inesperado; parada recusada." >&2
  exit 1
fi

if [ ! -f "$data_dir/PG_VERSION" ]; then
  echo "Cluster local de testes ainda não foi criado."
  exit 0
fi

if ! su postgres -s /bin/sh -c "pg_ctl -D '$data_dir' status" >/dev/null 2>&1; then
  echo "PostgreSQL local já está parado."
  exit 0
fi

su postgres -s /bin/sh -c "pg_ctl -D '$data_dir' -w stop -m fast"
echo "PostgreSQL local parado."
