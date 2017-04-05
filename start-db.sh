#!/usr/bin/env nix-shell
#! nix-shell -i bash -p docker

BLUE="$(printf '\033[0;34m')"
YELLOW='\033[1;33m'
NC="$(printf '\033[0m')"

echo -e "${YELLOW}Starting postgresql:${NC}"
mkdir -p pgdata
docker run -it\
    --net=host\
    -v $(pwd)/pgdata:/var/lib/postgresql/data/pgdata\
    -e PGDATA=/var/lib/postgresql/data/pgdata\
    -e POSTGRES_DB=adventure_club\
    mdillon/postgis\
    | sed "s/.*/  ${BLUE}&${NC}/"

