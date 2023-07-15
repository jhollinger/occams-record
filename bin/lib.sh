function podpose {
  if [[ -n "${OCCAMS_PODMAN-}" ]]; then
    podman-compose "$@"
  else
    docker compose "$@"
  fi
}

function array_in_array {
  args=("$@")
  term_size=${args[0]}
  terms=("${args[@]:1:$term_size}")
  array=("${args[@]:$(($term_size+1))}")

  for x in ${terms[@]}; do
    if ! in_array $x ${array[@]}; then
      return 1
    fi
  done
  return 0
}

function in_array {
  term=$1
  shift 1
  for x in $@; do [[ $term == $x ]] && return 0; done
  return 1
}

function announce {
  box="#############################################################"
  printf "\n%s\n  %s\n%s\n" $box "$@" $box
}

function nyancat {
  red='\e[31m'
  green='\e[32m'
  yellow='\e[33m'
  blue='\e[34m'
  bold='\033[1m'
  normal='\e[0m'

  lines=(
    ""
    "+      o     +              o"
    "    +             o     +       +"
    "o          +"
    "    o  +           +        +"
    "+        o     o       +        o"
    "${red}-_-_-_-_-_-_-_${normal},------,      o "
    "${yellow}_-_-_-_-_-_-_-${normal}|   /\\_/\\  "
    "${green}-_-_-_-_-_-_-${normal}~|__( ^ .^)  +     +  "
    "${blue}_-_-_-_-_-_-_-${normal}\"\"  \"\"      "
    "    +      o         o   +       o"
    "    +         +"
    "o        o         o      o     +"
    "    o           +"
    "+      +     o        o      +    "
    ""
  )

  for line in "${lines[@]}"; do
    printf "${line}\n"
  done
}
