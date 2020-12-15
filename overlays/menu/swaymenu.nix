{ pkgs, terminal }:
pkgs.writeScriptBin "swaymenu" ''
  #!${pkgs.stdenv.shell}

  shopt -s nullglob globstar
  set -o pipefail
  # shellcheck disable=SC2154
  trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
  IFS=$'\n\t'
  DEL=$'\34'

  # Defaulting terminal to urxvt, but feel free to either change
  # this or override with an environment variable in your sway config
  # It would be good to move this to a config file eventually
  TERMINAL_COMMAND="''${TERMINAL_COMMAND:="${terminal} -e"}"
  GLYPH_COMMAND="  "
  GLYPH_DESKTOP="  "
  CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/sway-launcher-desktop"
  PROVIDERS_FILE="''${PROVIDERS_FILE:=providers.conf}"
  if [[ "''${PROVIDERS_FILE#/}" == "$PROVIDERS_FILE" ]]; then
      # $PROVIDERS_FILE is a relative path, prepend $CONFIG_DIR
      PROVIDERS_FILE="$CONFIG_DIR/$PROVIDERS_FILE"
  fi

  # Provider config entries are separated by the field separator \034 and have the following structure:
  # list_cmd,preview_cmd,launch_cmd
  declare -A PROVIDERS
  if [ -f "$PROVIDERS_FILE" ]; then
    eval "$(awk -F= '
    BEGINFILE{ provider=""; }
    /^\[.*\]/{sub("^\\[", "");sub("\\]$", "");provider=$0}
    /^(launch|list|preview)_cmd/{st = index($0,"=");providers[provider][$1] = substr($0,st+1)}
    ENDFILE{
      for (key in providers){
        if(!("list_cmd" in providers[key])){continue;}
        if(!("launch_cmd" in providers[key])){continue;}
        if(!("preview_cmd" in providers[key])){continue;}
        for (entry in providers[key]){
         gsub(/[\x27,\047]/,"\x27\"\x27\"\x27", providers[key][entry])
        }
        print "PROVIDERS[\x27" key "\x27]=\x27" providers[key]["list_cmd"] "\034" providers[key]["preview_cmd"] "\034" providers[key]["launch_cmd"] "\x27\n"
      }
    }' "$PROVIDERS_FILE")"
    HIST_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/''${0##*/}-''${PROVIDERS_FILE##*/}-history.txt"
  else
    PROVIDERS['desktop']="$0 list-entries$DEL$0 describe-desktop '{1}'$DEL$0 run-desktop '{1}' {2}"
    PROVIDERS['command']="$0 list-commands$DEL$0 describe-command {1}$DEL$TERMINAL_COMMAND {1}"
    HIST_FILE="''${XDG_CACHE_HOME:-$HOME/.cache}/''${0##*/}-history.txt"
  fi

  touch "$HIST_FILE"
  readarray HIST_LINES <"$HIST_FILE"

  function describe() {
    # shellcheck disable=SC2086
    readarray -d $DEL -t PROVIDER_ARGS <<<''${PROVIDERS[$1]}
    # shellcheck disable=SC2086
    [ -n "''${PROVIDER_ARGS[1]}" ] && eval "''${PROVIDER_ARGS[1]//\{1\}/$2}"
  }
  function describe-desktop() {
    description=$(sed -ne '/^Comment=/{s/^Comment=//;p;q}' "$1")
    echo -e "\033[33m$(sed -ne '/^Name=/{s/^Name=//;p;q}' "$1")\033[0m"
    echo "''${description:-No description}"
  }
  function describe-command() {
    readarray arr < <(whatis -l "$1" 2>/dev/null)
    description="''${arr[0]}"
    description="''${description#* - }"
    echo -e "\033[33m$1\033[0m"
    echo "''${description:-No description}"
  }

  function provide() {
    # shellcheck disable=SC2086
    readarray -d $DEL -t PROVIDER_ARGS <<<''${PROVIDERS[$1]}
    eval "''${PROVIDER_ARGS[0]}"
  }
  function list-commands() {
    IFS=: read -ra path <<<"$PATH"
    for dir in "''${path[@]}"; do
      printf '%s\n' "$dir/"* |
        awk -F / -v pre="$GLYPH_COMMAND" '{print $NF "\034command\034\033[31m" pre "\033[0m" $NF;}'
    done | sort -u
  }
  function list-entries() {
    # Get locations of desktop application folders according to spec
    # https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
    IFS=':' read -ra DIRS <<<"/run/current-system/sw/share":"$HOME/.nix-profile/share"
    for i in "''${!DIRS[@]}"; do
      if [[ ! -d "''${DIRS[i]}" ]]; then
        unset -v 'DIRS[$i]'
      else
        DIRS[$i]="''${DIRS[i]}/applications/**/*.desktop"
      fi
    done
    # shellcheck disable=SC2068
    entries ''${DIRS[@]}
  }
  function entries() {
    # shellcheck disable=SC2068
    awk -v pre="$GLYPH_DESKTOP" -F= '
      function desktopFileID(filename){
        sub("^.*applications/", "", filename);
        sub("/", "-", filename);
        return filename
      }
      BEGINFILE{
        application=0;
        block="";
        a=0

        id=desktopFileID(FILENAME)
        if(id in fileIds){
          nextfile;
        }else{
          fileIds[id]=0
        }
      }
      /^\[Desktop Entry\]/{block="entry"}
      /^Type=Application/{application=1}
      /^\[Desktop Action/{
        sub("^\\[Desktop Action ", "");
        sub("\\]$", "");
        block="action";
        a++;
        actions[a,"key"]=$0
      }
      /^Name=/{ (block=="action")? actions[a,"name"]=$2 : name=$2 }
      ENDFILE{
        if (application){
            print FILENAME "\034desktop\034\033[33m" pre name "\033[0m";
            if (a>0)
                for (i=1; i<=a; i++)
                    print FILENAME "\034desktop\034\033[33m" pre name "\033[0m (" actions[i, "name"] ")\034" actions[i, "key"]
        }
      }' \
      $@ </dev/null
    # the empty stdin is needed in case no *.desktop files
  }
  function run-desktop() {
    bash -c "$("$0" generate-command "$@")"
  }
  function generate-command() {
    # Define the search pattern that specifies the block to search for within the .desktop file
    PATTERN="^\\\\[Desktop Entry\\\\]"
    if [[ -n $2 ]]; then
      PATTERN="^\\\\[Desktop Action ''${2%?}\\\\]"
    fi
    # 1. We see a line starting [Desktop, but we're already searching: deactivate search again
    # 2. We see the specified pattern: start search
    # 3. We see an Exec= line during search: remove field codes and set variable
    # 3. We see a Path= line during search: set variable
    # 4. Finally, build command line
    awk -v pattern="$PATTERN" -v terminal_cmd="$TERMINAL_COMMAND" -F= '
      BEGIN{a=0;exec=0;path=0}
         /^\[Desktop/{
          if(a){ a=0 }
         }
        $0 ~ pattern{ a=1 }
        /^Terminal=/{
          sub("^Terminal=", "");
          if ($0 == "true") { terminal=1 }
        }
        /^Exec=/{
          if(a && !exec){
            sub("^Exec=", "");
            gsub(" ?%[cDdFfikmNnUuv]", "");
            exec=$0;
          }
        }
        /^Path=/{
          if(a && !path){ path=$2 }
         }
      END{
        if(path){ printf "cd " path " && " }
        if (terminal){ printf terminal_cmd " " }
        print exec
      }' "$1"
  }

  case "$1" in
  describe | describe-desktop | describe-command | entries | list-entries | list-commands | generate-command | run-desktop | provide)
    "$@"
    exit
    ;;
  esac

  FZFPIPE=$(mktemp -u)
  mkfifo "$FZFPIPE"
  trap 'rm "$FZFPIPE"' EXIT INT

  # Append Launcher History, removing usage count
  (printf '%s' "''${HIST_LINES[@]#* }" >>"$FZFPIPE") &

  # Iterate over providers and run their list-command
  for PROVIDER_NAME in "''${!PROVIDERS[@]}"; do
    (bash -c "$0 provide $PROVIDER_NAME" >>"$FZFPIPE") &
  done

  COMMAND_STR=$(
    ${pkgs.fzf}/bin/fzf +s -x -d '\034' --nth ..3 --with-nth 3 \
      --preview "$0 describe {2} {1}" \
      --preview-window=up:3:wrap --ansi \
      <"$FZFPIPE"
  ) || exit 1

  [ -z "$COMMAND_STR" ] && exit 1

  # update history
  for i in "''${!HIST_LINES[@]}"; do
    if [[ "''${HIST_LINES[i]}" == *" $COMMAND_STR"$'\n' ]]; then
      HIST_COUNT=''${HIST_LINES[i]%% *}
      HIST_LINES[$i]="$((HIST_COUNT + 1)) $COMMAND_STR"$'\n'
      match=1
      break
    fi
  done
  if ! ((match)); then
    HIST_LINES+=("1 $COMMAND_STR"$'\n')
  fi

  printf '%s' "''${HIST_LINES[@]}" | sort -nr >"$HIST_FILE"

  # shellcheck disable=SC2086
  readarray -d $'\034' -t PARAMS <<<$COMMAND_STR
  # shellcheck disable=SC2086
  readarray -d $DEL -t PROVIDER_ARGS <<<''${PROVIDERS[''${PARAMS[1]}]}
  # Substitute {1}, {2} etc with the correct values
  COMMAND=''${PROVIDER_ARGS[2]//\{1\}/''${PARAMS[0]}}
  COMMAND=''${COMMAND//\{2\}/''${PARAMS[3]}}

  (exec swaymsg -t command "exec $COMMAND")
''
