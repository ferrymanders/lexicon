#!/usr/bin/env bash
#
# Example how to deploy a DNS challange using lexicon

set -e
set -u
set -o pipefail

export PROVIDER=${PROVIDER:-"cloudflare"}
export WAIT_TIME=${WAIT_TIME:=30}
export RETRY=${RETRY:=10}
export DNS_SERVER=${DNS_SERVER:=8.8.8.8}
export DEBUG=${DEBUG:=false}

function deploy_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}" COUNTER=0 RESULT=false

    echo "deploy_challenge called: ${DOMAIN}, ${TOKEN_FILENAME}, ${TOKEN_VALUE}"

    if $DEBUG;
    then
        lexicon $PROVIDER create ${DOMAIN} TXT --name="_acme-challenge.${DOMAIN}." --content="${TOKEN_VALUE}"
    else
        lexicon $PROVIDER create ${DOMAIN} TXT --name="_acme-challenge.${DOMAIN}." --content="${TOKEN_VALUE}" &> /dev/null
    fi

    echo -n "Waiting for record update : "

    while [ $COUNTER -lt $RETRY ];
    do
        check=$(dig +short TXT _acme-challenge.${DOMAIN} @${DNS_SERVER} | sed 's/"//g')

        if $DEBUG;
        then
            echo "_acme-challenge.${DOMAIN} -> $COUNTER/$RETRY -> $TOKEN_VALUE = $check"
        else
            echo -n "."
        fi
        COUNTER=$((COUNTER+1))

        if [ "$check" == "$TOKEN_VALUE" ];
        then
            RESULT=true
            COUNTER=$RETRY
        fi

        sleep $WAIT_TIME
    done

    echo ""

    if $RESULT;
    then
        echo "Check success!"
    else
        echo "Check failed!"
    fi



    # This hook is called once for every domain that needs to be
    # validated, including any alternative names you may have listed.
    #
    # Parameters:
    # - DOMAIN
    #   The domain name (CN or subject alternative name) being
    #   validated.
    # - TOKEN_FILENAME
    #   The name of the file containing the token to be served for HTTP
    #   validation. Should be served by your web server as
    #   /.well-known/acme-challenge/${TOKEN_FILENAME}.
    # - TOKEN_VALUE
    #   The token value that needs to be served for validation. For DNS
    #   validation, this is what you want to put in the _acme-challenge
    #   TXT record. For HTTP validation it is the value that is expected
    #   be found in the $TOKEN_FILENAME file.
}

function clean_challenge {
    local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

    echo "clean_challenge called: ${DOMAIN}, ${TOKEN_FILENAME}, ${TOKEN_VALUE}"

    if $DEBUG;
    then
        lexicon $PROVIDER delete ${DOMAIN} TXT --name="_acme-challenge.${DOMAIN}." --content="${TOKEN_VALUE}"
    else
        lexicon $PROVIDER delete ${DOMAIN} TXT --name="_acme-challenge.${DOMAIN}." --content="${TOKEN_VALUE}" &> /dev/null
    fi

    # This hook is called after attempting to validate each domain,
    # whether or not validation was successful. Here you can delete
    # files or DNS records that are no longer needed.
    #
    # The parameters are the same as for deploy_challenge.
}

function invalid_challenge() {
    local DOMAIN="${1}" RESPONSE="${2}"

    echo "invalid_challenge called: ${DOMAIN}, ${RESPONSE}"

    # This hook is called if the challenge response has failed, so domain
    # owners can be aware and act accordingly.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - RESPONSE
    #   The response that the verification server returned
}

function deploy_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"

    echo "deploy_cert called: ${DOMAIN}, ${KEYFILE}, ${CERTFILE}, ${FULLCHAINFILE}, ${CHAINFILE}"

    # This hook is called once for each certificate that has been
    # produced. Here you might, for instance, copy your new certificates
    # to service-specific locations and reload the service.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
}

function unchanged_cert {
    local DOMAIN="${1}" KEYFILE="${2}" CERTFILE="${3}" FULLCHAINFILE="${4}" CHAINFILE="${5}"

    echo "unchanged_cert called: ${DOMAIN}, ${KEYFILE}, ${CERTFILE}, ${FULLCHAINFILE}, ${CHAINFILE}"

    # This hook is called once for each certificate that is still
    # valid and therefore wasn't reissued.
    #
    # Parameters:
    # - DOMAIN
    #   The primary domain name, i.e. the certificate common
    #   name (CN).
    # - KEYFILE
    #   The path of the file containing the private key.
    # - CERTFILE
    #   The path of the file containing the signed certificate.
    # - FULLCHAINFILE
    #   The path of the file containing the full certificate chain.
    # - CHAINFILE
    #   The path of the file containing the intermediate certificate(s).
}

exit_hook() {
  # This hook is called at the end of a dehydrated command and can be used
  # to do some final (cleanup or other) tasks.

  :
}

startup_hook() {
  # This hook is called before the dehydrated command to do some initial tasks
  # (e.g. starting a webserver).

  :
}

HANDLER=$1; shift; $HANDLER "$@"
