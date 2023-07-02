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
