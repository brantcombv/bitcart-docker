[[ -f ".deploy" ]] && . .deploy

bitcart_update_docker_env() {
touch $BITCART_ENV_FILE
cat > $BITCART_ENV_FILE << EOF
BITCART_HOST=$BITCART_HOST
BITCART_LETSENCRYPT_EMAIL=$BITCART_LETSENCRYPT_EMAIL
REVERSEPROXY_HTTP_PORT=$REVERSEPROXY_HTTP_PORT
REVERSEPROXY_HTTPS_PORT=$REVERSEPROXY_HTTPS_PORT
REVERSEPROXY_DEFAULT_HOST=$REVERSEPROXY_DEFAULT_HOST
BITCART_STORE_HOST=$BITCART_STORE_HOST
BITCART_STORE_API_URL=$BITCART_STORE_API_URL
BITCART_ADMIN_HOST=$BITCART_ADMIN_HOST
BITCART_ADMIN_API_URL=$BITCART_ADMIN_API_URL
BITCART_CRYPTOS=$BITCART_CRYPTOS
BTC_NETWORK=$BTC_NETWORK
BTC_LIGHTNING=$BTC_LIGHTNING
BCH_NETWORK=$BCH_NETWORK
LTC_NETWORK=$LTC_NETWORK
LTC_LIGHTNING=$LTC_LIGHTNING
GZRO_NETWORK=$GZRO_NETWORK
GZRO_LIGHTNING=$GZRO_LIGHTNING
BSTY_NETWORK=$BSTY_NETWORK
BSTY_LIGHTNING=$BSTY_LIGHTNING
$(env | awk -F "=" '{print "\n"$0}' | grep "BITCART_.*.*_PORT")
$(env | awk -F "=" '{print "\n"$0}' | grep "BITCART_.*.*_EXPOSE")
$(env | awk -F "=" '{print "\n"$0}' | grep "BITCART_.*.*_ROOTPATH")
EOF
}

bitcart_start_listener() {
    # setup pipe and it's listener
    mkfifo queue &> /dev/null
    nohup sh -c "tail -f queue | sh" &> /dev/null &
    echo $! > listener.pid
}

bitcart_stop_listener() {
    kill $(cat listener.pid) &> /dev/null || true
}

bitcart_start() {
    bitcart_start_listener || true
    USER_UID=${UID} USER_GID=${GID} docker-compose -p "$NAME" -f compose/generated.yml up --remove-orphans -d
}

bitcart_stop() {
    bitcart_stop_listener
    USER_UID=${UID} USER_GID=${GID} docker-compose -p "$NAME" -f compose/generated.yml down
}

bitcart_pull() {
    docker-compose -f compose/generated.yml pull
}

bitcart_restart() {
    bitcart_stop
    bitcart_start
}

get_profile_file() {
    CHECK_ROOT=${2:-true}
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Mac OS

        if $CHECK_ROOT && [[ $EUID -eq 0 ]]; then
            # Running as root is discouraged on Mac OS. Run under the current user instead.
            echo "This script should not be run as root."
            exit 1
        fi

        BASH_PROFILE_SCRIPT="$HOME/bitcartcc-env$1.sh"

        # Mac OS doesn't use /etc/profile.d/xxx.sh. Instead we create a new file and load that from ~/.bash_profile
        if [[ ! -f "$HOME/.bash_profile" ]]; then
            touch "$HOME/.bash_profile"
        fi
        if [[ -z $(grep ". \"$BASH_PROFILE_SCRIPT\"" "$HOME/.bash_profile") ]]; then
            # Line does not exist, add it
            echo ". \"$BASH_PROFILE_SCRIPT\"" >> "$HOME/.bash_profile"
        fi

    else
        BASH_PROFILE_SCRIPT="/etc/profile.d/bitcartcc-env$1.sh"

        if $CHECK_ROOT && [[ $EUID -ne 0 ]]; then
            echo "This script must be run as root after running \"sudo su -\""
            exit 1
        fi
    fi
}

load_env() {
    get_profile_file "$SCRIPTS_POSTFIX" false
    . ${BASH_PROFILE_SCRIPT}
}

try() {
    "$@" || true
}

remove_host() {
    if [ -n "$(grep -w "$1$" /etc/hosts)" ]; then
        try sed -ie "/[[:space:]]$1/d" /etc/hosts
    fi
}

add_host() {
    if [ -z "$(grep -P "[[:space:]]$2" /etc/hosts)" ]; then
        try printf "%s\t%s\n" "$1" "$2" | sudo tee -a /etc/hosts > /dev/null
    fi
}

modify_host() {
    remove_host $2
    add_host $1 $2
}

apply_local_modifications() {
    if [[ "$BITCART_HOST" == *.local ]] ; then
        echo "Local setup detected."
        if [[ "$BITCART_NOHOSTSEDIT" = true ]] ; then
            echo "Not modifying hosts."
        else
            echo "WARNING! Modifying /etc/hosts to make local setup work. It may require superuser privileges."
            modify_host 172.17.0.1 $BITCART_STORE_HOST
            modify_host 172.17.0.1 $BITCART_HOST
            modify_host 172.17.0.1 $BITCART_ADMIN_HOST
        fi
    fi
}