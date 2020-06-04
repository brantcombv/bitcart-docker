[[ -f ".deploy" ]] && . .deploy

bitcart_update_docker_env() {
touch $BITCART_ENV_FILE
cat > $BITCART_ENV_FILE << EOF
BITCART_HOST=$BITCART_HOST
BITCART_LETSENCRYPT_EMAIL=$BITCART_LETSENCRYPT_EMAIL
BITCART_FRONTEND_HOST=$BITCART_FRONTEND_HOST
BITCART_FRONTEND_URL=$BITCART_FRONTEND_URL
BITCART_ADMIN_HOST=$BITCART_ADMIN_HOST
BITCART_ADMIN_URL=$BITCART_ADMIN_URL
BITCART_CRYPTOS=${BITCART_CRYPTOS:-btc}
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
EOF
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