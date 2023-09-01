#!/command/with-contenv bashio
# shellcheck disable=SC2207
# ==============================================================================
# Home Assistant Add-on: Cloudflared
#
# Configures the Cloudflare Tunnel and creates the needed DNS entry under the
# given hostname(s)
# ==============================================================================

# ------------------------------------------------------------------------------
# Checks if the config is valid
# ------------------------------------------------------------------------------
checkConfig() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Checking add-on config..."

    local validHostnameRegex="^(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])$"

     # Check for minimum configuration options
    if bashio::config.is_empty 'ais_subdomain' && bashio::config.is_empty 'ais_password';
    then
        bashio::exit.nok "Cannot run without subdomain and password. Please set these add-on options."
    fi

    if ! [[ $(bashio::config 'ais_subdomain') =~ ${validHostnameRegex} ]] ; then
                bashio::exit.nok " $(bashio::config 'ais_subdomain') selected subdomain is not a valid hostname. Please make sure not to include the protocol (e.g. 'https://') nor the port (e.g. ':8123') and only use lowercase characters in the 'subdomain'."
    fi
}

# ------------------------------------------------------------------------------
# Checks if Cloudflare services are reachable
# ------------------------------------------------------------------------------
checkConnectivity() {
    local pass_test=true
    bashio::log.debug "Checking connectivity to Cloudflare"

    # Check for region1 TCP
    bashio::log.debug "Checking region1.v2.argotunnel.com TCP port 7844"
    if ! nc -z -w 1 region1.v2.argotunnel.com 7844 &> /dev/null ; then
        bashio::log.warning "region1.v2.argotunnel.com TCP port 7844 not reachable"
        pass_test=false
    fi

    # Check for region1 UDP
    bashio::log.debug "Checking region1.v2.argotunnel.com UDP port 7844"
    if ! nc -z -u -w 1 region1.v2.argotunnel.com 7844 &> /dev/null ; then
        bashio::log.warning "region1.v2.argotunnel.com UDP port 7844 not reachable"
        pass_test=false
    fi

    # Check for region2 TCP
    bashio::log.debug "Checking region2.v2.argotunnel.com TCP port 7844"
    if ! nc -z -w 1 region2.v2.argotunnel.com 7844 &> /dev/null ; then
        bashio::log.warning "region2.v2.argotunnel.com TCP port 7844 not reachable"
        pass_test=false
    fi

    # Check for region2 UDP
    bashio::log.debug "Checking region2.v2.argotunnel.com UDP port 7844"
    if ! nc -z -u -w 1 region2.v2.argotunnel.com 7844 &> /dev/null ; then
        bashio::log.warning "region2.v2.argotunnel.com UDP port 7844 not reachable"
        pass_test=false
    fi

    # Check for API TCP
    bashio::log.debug "Checking api.cloudflare.com TCP port 443"
    if ! nc -z -w 1 api.cloudflare.com 443 &> /dev/null ; then
        bashio::log.warning "api.cloudflare.com TCP port 443 not reachable"
        pass_test=false
    fi

    if bashio::var.false ${pass_test} ; then
        bashio::log.warning "Some necessary services may not be reachable from your host."
        bashio::log.warning "Please review lines above and check your firewall/router settings."
    fi

}

# ------------------------------------------------------------------------------
# Check if Cloudflared certificate (authorization) is available
# ------------------------------------------------------------------------------
hasCertificate() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Checking for existing certificate..."
    if bashio::fs.file_exists "${data_path}/cert.pem" ; then
        bashio::log.info "Existing certificate found"
        return "${__BASHIO_EXIT_OK}"
    fi

    bashio::log.notice "No certificate found"
    return "${__BASHIO_EXIT_NOK}"
}

# ------------------------------------------------------------------------------
# Check ais subdomain
# ------------------------------------------------------------------------------
checkSubdomain(){
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Checking the subdomain..."
    bashio::log.notice
    bashio::log.notice "Please wait for subdomain check in AIS"
    bashio::log.notice

    if bashio::debug ; then
         args="-X POST -v --show-error --user "$(bashio::config 'ais_subdomain'):$(bashio::config 'ais_password')" https://powiedz.co/ords/dom/dom/set_tunnel_subdomain"
         curl -f "$args" && bashio::log.info "Subdomain OK" || bashio::exit.nok "Failed to use this subdomain, maybe somebody reserved it. Check the name and password."
    else
        args="-X POST -s --show-error --user  "$(bashio::config 'ais_subdomain'):$(bashio::config 'ais_password')" https://powiedz.co/ords/dom/dom/set_tunnel_subdomain"
         curl -f "$args" && bashio::log.info "Subdomain OK" || bashio::exit.nok "Failed to use this subdomain, maybe somebody reserved it. Check the name and password."
    fi

    tunnel_name="$(bashio::config 'ais_subdomain')"
    external_hostname="$(bashio::config 'ais_subdomain').paczka.pro"

    bashio::log.warning "Creating tunnel: https://${external_hostname}"
}

# ------------------------------------------------------------------------------
# Get cloudflare certificate
# ------------------------------------------------------------------------------
getCertificate() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating new certificate..."
    bashio::log.notice
    bashio::log.notice "Please wait for the AIS certificate"
    bashio::log.notice

    if bashio::debug ; then
        curl -L -o "${data_path}/cert.pem" -v https://ai-speaker.com/ota/ais_cloudflared
    else
        curl -sS -L -o "${data_path}/cert.pem" https://ai-speaker.com/ota/ais_cloudflared
    fi
    bashio::log.info "AIS Authentication successfull!"

    hasCertificate || bashio::exit.nok "Failed to create certificate"
}

# ------------------------------------------------------------------------------
# Check if Cloudflare Tunnel is existing
# ------------------------------------------------------------------------------
hasTunnel() {
    bashio::log.trace "${FUNCNAME[0]}:"
    bashio::log.info "Checking for existing tunnel..."

    # Check if tunnel file(s) exist
    if ! bashio::fs.file_exists "${data_path}/tunnel.json" ; then
        bashio::log.notice "No tunnel file found"
        return "${__BASHIO_EXIT_NOK}"
    fi

    # Get tunnel UUID from JSON
    tunnel_uuid="$(bashio::jq "${data_path}/tunnel.json" ".TunnelID")"

    bashio::log.info "Existing tunnel with ID ${tunnel_uuid} found"

    # Get tunnel name from Cloudflare API by tunnel id and chek if it matches config value
    bashio::log.info "Checking if existing tunnel matches name given in config"
    local existing_tunnel_name
    existing_tunnel_name=$(cloudflared --origincert="${data_path}/cert.pem" tunnel \
        list --output="json" --id="${tunnel_uuid}" | jq -er '.[].name')
    bashio::log.debug "Existing Cloudflare Tunnel name: $existing_tunnel_name"
    if [[ $tunnel_name != "$existing_tunnel_name" ]]; then
        bashio::log.error "Existing Cloudflare Tunnel name does not match add-on config."
        bashio::log.error "---------------------------------------"
        bashio::log.error "Add-on Configuration tunnel name: ${tunnel_name}"
        bashio::log.error "Tunnel credentials file tunnel name: ${existing_tunnel_name}"
        bashio::log.error "---------------------------------------"
        bashio::log.error "Align add-on configuration to match existing tunnel credential file"
        bashio::log.error "or re-install the add-on."
        bashio::exit.nok
    fi
    bashio::log.info "Existing Cloudflare Tunnel name matches config, proceeding with existing tunnel file"

    return "${__BASHIO_EXIT_OK}"
}

# ------------------------------------------------------------------------------
# Delete Cloudflare Tunnel with name from mac
# ------------------------------------------------------------------------------
deleteTunnel() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Deleting old tunnel..."

    # delete current tunnel
    cloudflared --origincert="${data_path}/cert.pem" tunnel --loglevel "${CLOUDFLARED_LOG}" delete -f "${tunnel_name}" \
    || bashio::log.debug "No tunnel to delete!"

    # delete previous/old tunnel
    old_tunnel_name=$(cat "${data_path}/tunnel_name.txt")
    bashio::log.debug "Old tunnel to delete " "${old_tunnel_name}"
    cloudflared --origincert="${data_path}/cert.pem" tunnel --loglevel "${CLOUDFLARED_LOG}" delete -f "${old_tunnel_name}" \
    || bashio::log.debug "No old tunnel to delete!"


    if bashio::fs.file_exists "${data_path}/tunnel.json" ; then
       rm "${data_path}/tunnel.json"
    fi

    bashio::log.info "Deleted old tunnel"

    return "${__BASHIO_EXIT_OK}"
}

# ------------------------------------------------------------------------------
# Create Cloudflare Tunnel with name from mac
# ------------------------------------------------------------------------------
createTunnel() {
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating new tunnel..."
    cloudflared --origincert="${data_path}/cert.pem" --cred-file="${data_path}/tunnel.json" tunnel --loglevel "${CLOUDFLARED_LOG}" create "${tunnel_name}" \
    || bashio::exit.nok "Failed to create tunnel."

    bashio::log.debug "Created new tunnel: $(cat "${data_path}"/tunnel.json)"

    hasTunnel || bashio::exit.nok "Failed to create tunnel"
}

# ------------------------------------------------------------------------------
# Create Cloudflare config with variables from HA-Add-on-Config
# ------------------------------------------------------------------------------
createConfig() {
    local ha_service_protocol
    local config
    bashio::log.trace "${FUNCNAME[0]}"
    bashio::log.info "Creating config file..."

    # Add tunnel information
    config=$(bashio::jq "{\"tunnel\":\"${tunnel_uuid}\"}" ".")
    config=$(bashio::jq "${config}" ".\"credentials-file\" += \"${data_path}/tunnel.json\"")

    bashio::log.debug "Checking if SSL is used..."
    if bashio::var.true "$(bashio::core.ssl)" ; then
        ha_service_protocol="https"
    else
        ha_service_protocol="http"
    fi
    bashio::log.debug "ha_service_protocol: ${ha_service_protocol}"

    if bashio::var.is_empty "${ha_service_protocol}" ; then
        bashio::exit.nok "Error checking if SSL is enabled"
    fi

    # Add Service for Home Assistant
    config=$(bashio::jq "${config}" ".\"ingress\" += [{\"hostname\": \"${external_hostname}\", \"service\": \"${ha_service_protocol}://homeassistant:$(bashio::core.port)\"}]")

    config=$(bashio::jq "${config}" ".\"ingress\" += [{\"service\": \"http_status:404\"}]")

    # Deactivate TLS verification for all services
    config=$(bashio::jq "${config}" ".ingress[].originRequest += {\"noTLSVerify\": true}")

    # Write content of config variable to config file for cloudflared
    bashio::jq "${config}" "." > "${default_config}"

    # Validate config using cloudflared
    bashio::log.info "Validating config file..."
    bashio::log.debug "Validating created config file: $(bashio::jq "${default_config}" ".")"
    cloudflared tunnel --config="${default_config}" --loglevel "${CLOUDFLARED_LOG}" ingress validate \
    || bashio::exit.nok "Validation of Config failed, please check the logs above."

    bashio::log.debug "Sucessfully created config file: $(bashio::jq "${default_config}" ".")"
}

# ------------------------------------------------------------------------------
# Create cloudflare DNS entry for dom-xxx hostname
# ------------------------------------------------------------------------------
createDNS() {
    bashio::log.trace "${FUNCNAME[0]}"

    # Create DNS entry for external hostname of Home Assistant
    bashio::log.info "Creating DNS entry ${external_hostname}..."
    cloudflared --origincert="${data_path}/cert.pem" tunnel --loglevel "${CLOUDFLARED_LOG}" route dns -f "${tunnel_uuid}" "${external_hostname}" \
    || bashio::exit.nok "Failed to create DNS entry ${external_hostname}."
}

# ------------------------------------------------------------------------------
# Set Cloudflared log level
# ------------------------------------------------------------------------------
setCloudflaredLogLevel() {
local log

# Map Home Assistant log levels to Cloudflared
if bashio::config.exists 'log_level' ; then
    case $(bashio::config 'log_level') in
        "trace") log="info";;
        "debug") log="info";;
        "info") log="info";;
        "notice") log="info";;
        "warning") log="warn";;
        "error") log="error";;
        "fatal") log="fatal";;
    esac
else
    log="info"
fi

# Write log level to S6 environment
printf "%s" "${log}" > /var/run/s6/container_environment/CLOUDFLARED_LOG
CLOUDFLARED_LOG=${log}
bashio::log.debug "Cloudflared log level set to \"${log}\""

}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
declare default_config=/tmp/config.json
external_hostname=""
tunnel_name=""
tunnel_uuid=""
data_path="/data"

main() {
    bashio::log.trace "${FUNCNAME[0]}"

    setCloudflaredLogLevel

    checkConfig

    # remove ais cert
    if hasCertificate ; then
        rm "${data_path}/cert.pem"
    fi

    # Run connectivity checks if debug mode activated
    if bashio::debug ; then
        checkConnectivity
    fi

    checkSubdomain

    getCertificate

    deleteTunnel

    createTunnel

    createConfig

    createDNS

    # store tunnel name to remove it as onld tunnel in case of name change
    echo "$(bashio::config 'ais_subdomain')" > "${data_path}/tunnel_name.txt"


    bashio::log.info "Finished setting up the Cloudflare Tunnel"
}
main "$@"
