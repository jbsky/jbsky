#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ${SCRIPT_NAME} {OPTIONS}
#+
#% DESCRIPTION
#% Script helping to generate and manage SSL certificates.
#%
#% /!\Don't forget to put the following lines in openssl.
#%
#%
#%[server]
#%subjectKeyIdentifier              = hash
#%authorityKeyIdentifier            = keyid,issuer:always
#%issuerAltName                     = issuer:copy
#%subjectAltName                    = @alt_names
#%basicConstraints                  = critical,CA:FALSE
#%keyUsage                          = digitalSignature, nonRepudiation, keyEnciphe$
#%nsCertType                        = server
#%extendedKeyUsage                  = serverAuth
#%nsComment                         = "OpenSSL Generated Certificate"
#%
#%[client]
#%subjectKeyIdentifier              = hash
#%authorityKeyIdentifier            = keyid,issuer:always
#%subjectAltName                    = email:copy
#%issuerAltName                     = issuer:copy
#%basicConstraints                  = critical,CA:FALSE
#%keyUsage                          = digitalSignature, nonRepudiation, keyEnciphe$
#%nsCertType                        = client, email, objsign
#%extendedKeyUsage                  = clientAuth
#%nsComment                         = "OpenSSL Generated Certificate"
#%
#% OPTIONS
#%    -a                                                create authority
#%    -m                                                show cert
#%    -s                                                create cert server
#%    -c                                                create cert client
#%    -h                                                print this help
#%    -v                                                verbose
#%
#%
#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME} 0.0.1
#-    author        Jbsky
#-    copyright     
#-    license         GNU General Public License
#-
#================================================================
#  HISTORY
#     2016/03/01 : Script creation
# 
#================================================================
#  DEBUG OPTION
# set -n  # Uncomment to check your syntax, without execution.
# set -x  # Uncomment to debug this shell script
#
#================================================================
# END_OF_HEADER
#================================================================

#============================
#  FUNCTIONS
#============================

  #== fecho function ==#
fecho() {
  myType=${1} ; shift ;
  [[ ${SCRIPT_TIMELOG_FLAG:-0} -ne 0 ]] && printf "$( date ${SCRIPT_TIMELOG_FORMAT} )"
  printf "[${myType%[A-Z][A-Z]}] ${*}\n"
  if [[ "${myType}" = CAT ]]; then
    if [[ ${SCRIPT_TIMELOG_FLAG:-0} -eq 0 ]]; then
        cat -un - | awk '$0="[O] "$0; fflush();' ;
    elif [[ "${GNU_AWK_FLAG}" ]]; then # fast - compatible linux
        cat -un - | awk -v tformat=${SCRIPT_TIMELOG_FORMAT#+} '$0=strftime(tformat)"[O] "$0; fflush();' ; 
    else # average speed and more resource intensive- compatible unix/linux
        cat -un - | while read LINE; do \
            [[ ${OLDSECONDS:=$(( ${SECONDS}-1 ))} -lt ${SECONDS} ]] && OLDSECONDS=$(( ${SECONDS}+1 )) \
            && TSTAMP="$( date ${SCRIPT_TIMELOG_FORMAT} )"; printf "${TSTAMP}[O] ${LINE}\n"; \
        done 
    fi
  fi
}

  #== custom function ==#
check_cre_file() {
    myFile=${1}
    [[ "${myFile}" = "/dev/null" ]] && return 0
    [[ -e ${myFile} ]] && error "${SCRIPT_NAME}: ${myFile}: File already exists" && return 1
    touch ${myFile} 2>&1 1>/dev/null
    [[ $? -ne 0 ]] && error "${SCRIPT_NAME}: ${myFile}: Cannot create file" && return 2
    rm -f ${myFile} 2>&1 1>/dev/null
    [[ $? -ne 0 ]] && error "${SCRIPT_NAME}: ${myFile}: Cannot delete file" && return 3
    return 0
}

CheckAndCreateFolder(){

    if [ ! -d ${1} ];then
        mkdir -p ${1} 
    else
        info "${SCRIPT_NAME}: Config folder created ${1}" 1>&2 
    fi    
}

CheckAndCreateTreeFolder(){
    [ -d  ${1} ] && info "${SCRIPT_NAME}: Folder ${1} already exit " 1>&2

    CheckAndCreateFolder ${1}/certs
    CheckAndCreateFolder ${1}/crl
    CheckAndCreateFolder ${1}/newcerts
    CheckAndCreateFolder ${1}/private
    chmod -R 600 ${1}/private
    if [ ! -f ${1}/index.txt ];then
        touch ${1}/index.txt
    else
        info "${SCRIPT_NAME}: ${1}/index.txt already exit " 1>&2
    fi
    if [ ! -f ${1}/serial ];then
        touch ${1}/serial
    else
        info "${SCRIPT_NAME}: ${1}/serial already exit " 1>&2
    fi
}

  #== renseigne le fichier /etc/default/ssl ==#
  #
DoDefault(){
    [ ${flagOptVerbose} -eq 1 ] &&     echo "DoDefault"

    cat >>/etc/default/ssl << EOF
email=webmaster@jbsky.fr
bits=8192
days=365
O=Jbsky
L=Senas
ST=PACA
C=FR
OU=
oscp=ocsp.jbsky.fr
configfile=/etc/ssl/openssl.cnf
ca=CA_default
dir=/etc/ssl/jbsky
EOF

}

extract_FileAndFolderConfig(){
    if [ ${flagOptVerbose} -eq 1 ];then
        echo "extract_FileAndFolderConfig"
    fi
    # Test du repertoire
    if [ -d "${1}" -o "${1:${#1}-1:1}" = '/' -o ! "${1:${#1}-4:4}" = '.cnf' ]; then
        ConfigFolder=${1}
        CheckAndCreateFolder ${1}
    
    else
        if [ ${1:${#1}-5:5} = '/.cnf' ];then
            error "${SCRIPT_NAME}: ${1} /.cnf not correct  naming format ConfigFile! " 1>&2 && exit 4 ## print usage if option error and exit
        fi
        ConfigFolder=`dirname ${1}`
        ConfigFile=`basename ${1}`
    fi
    if [  "${ConfigFolder:${#ConfigFolder}-1:1}" = '/' ]; then
        ConfigFolder="${ConfigFolder:0:${#ConfigFolder}-1}"
    fi

    if [ "${ConfigFile}" = "" ];then
        ConfigFile="openssl.cnf"
    fi
    if [ ${flagOptVerbose} -eq 1 ];then
    echo "************************************
    ConfigFolder  : $ConfigFolder  
    ConfigFile    : $ConfigFile
    ************************************"
    fi
}

DoPrivateKey(){
    local OPTION
    OPTION=""
    if [ "${1}" = "ca" ];then
        OPTION="-des3"
    fi
    if [ -f ${2}/private/${1}.key ];then
        info "${2}/private/ca.key already exist, continu..." 1>&2
    else
        openssl genrsa ${OPTION} -out ${2}/private/${1}.key ${Bits} -config ${3}
    fi
    
}


  #== cr‚er le fichier ${RootConfigFolder}/${RootConfigFile} ==#
  #== cr‚er CA Root ==#
CreerAutorite(){

    [ ${flagOptVerbose} -eq 1 ]&& echo "CreerAutorite"
    echo "Dans la partie [CA_default] du fichier /etc/ssl/openssl.cnf, on vérifie que le repertoire dir correspond à la variable dans /etc/default/ssl"
    read p
    if [ ! -f  ${dir}/cacert.pem ];then
    
        CheckAndCreateTreeFolder ${dir}

        [ "${C}" = "" ] ||subj="/C=${C}"
        [ "${ST}" = "" ]||subj="${subj}/ST=${ST}"
        [ "${L}" = "" ] ||subj="${subj}/L=${L}"
        [ "${O}" = "" ] ||subj="${subj}/O=${O}"
        [ "${OU}" = "" ]||subj="${subj}/OU=${OU}"
        subj="${subj}/CN=Secure Digital Certificate Signing"
        
        openssl req -x509 -newkey rsa:${bits} -sha512 -extensions v3_ca -days ${days} -config ${configfile} -subj "${subj}" -keyout ${dir}/private/cakey.pem -out ${dir}/cacert.pem 

        chmod 400 ${dir}/private/cakey.pem
        chmod 444 ${dir}/cacert.pem
        openssl x509 -serial -noout -in ${dir}/cacert.pem | cut -d= -f2 > ${dir}/serial
        printf "%X\n" $((0x`cat ${dir}/serial`+1))>${dir}/serial
    else
        info "${dir}/cacert.pem already exist, continu..." 1>&2
    fi
}

CreerCertificat(){
    index=0
    CommonName=" "
    [ "${C}" = "" ] ||subj="/C=${C}"
    [ "${ST}" = "" ]||subj="${subj}/ST=${ST}"
    [ "${L}" = "" ] ||subj="${subj}/L=${L}"
    [ "${O}" = "" ] ||subj="${subj}/O=${O}"
    [ "${OU}" = "" ]||subj="${subj}/OU=${OU}"
    [ "${emailAddress}" = "" ]||subj="${subj}/emailAddress=${emailAddress}"
    while [ "${CommonName}" != "" ];do
        read -p "CN ${index}:" CommonName
        if [[ "${CommonName}" != "" && "${firstCN}" == ""  ]];then
            # alt_names="DNS.${index}:${CommonName}"
            firstCN=${CommonName}
            index=$((${index}+1))
            alt_names="DNS.${index}=${CommonName}"
        else
            if [[ "${CommonName}" != "" ]];then
                index=$((${index}+1))
                alt_names="${alt_names}\nDNS.${index}=${CommonName}"
            fi
        fi
    done
    subj="${subj}/CN=${firstCN}"
    echo -e ${alt_names} 
    
    [ ${flagOptVerbose} -eq 1 ]&& echo "CreerCertificat"
    
    if [ -f ${dir}/private/${firstCN}.key ];then
        info "${dir}/private/${firstCN}.key already exist, continu..." 1>&2
    else
#    -des3
        openssl genrsa  -out ${dir}/private/${firstCN}.key ${bits} -config ${configfile}
    fi
    
    if [ ! -f ${dir}/certs/${firstCN}.pem ];then

        if [ "${flagOptClient}" = "1" ];then
            openssl req -new -sha256 -key ${dir}/private/${firstCN}.key -out ${dir}/newcerts/${firstCN}.csr -nodes -subj "${subj}" -config  <(cat ${configfile} <(printf "
[client]
subjectKeyIdentifier              = hash
authorityKeyIdentifier            = keyid,issuer:always
subjectAltName                    = email:copy
issuerAltName                     = issuer:copy
basicConstraints                  = critical,CA:FALSE
keyUsage                          = digitalSignature, nonRepudiation, keyEncipherment
nsCertType                        = client, email, objsign
extendedKeyUsage                  = clientAuth
nsComment                         = \"OpenSSL Generated Certificate\"
"))

            openssl ca -name ${ca} -extensions client -in ${dir}/newcerts/${firstCN}.csr -out ${dir}/certs/${firstCN}.pem -config <(cat ${configfile} <(printf "
[client]
subjectKeyIdentifier              = hash
authorityKeyIdentifier            = keyid,issuer:always
subjectAltName                    = email:copy
issuerAltName                     = issuer:copy
basicConstraints                  = critical,CA:FALSE
keyUsage                          = digitalSignature, nonRepudiation, keyEncipherment
nsCertType                        = client, email, objsign
extendedKeyUsage                  = clientAuth
nsComment                         = \"OpenSSL Generated Certificate\"
"))
           
            openssl pkcs12 -export -inkey ${dir}/private/${firstCN}.key -in ${dir}/certs/${firstCN}.pem -name "${firstCN}" -certfile ${dir}/cacert.pem -caname "${ca}" -out ${dir}/${firstCN}.p12
        fi
        if [ "${flagOptServeur}" = "1" ];then
                    openssl req -new -sha256 -key ${dir}/private/${firstCN}.key -out ${dir}/newcerts/${firstCN}.csr -nodes -subj "${subj}" -config  <(cat ${configfile} <(printf "\n[alt_names]\n${alt_names}\n[server]
subjectKeyIdentifier              = hash
authorityKeyIdentifier            = keyid,issuer:always
issuerAltName                     = issuer:copy
subjectAltName                    = @alt_names
basicConstraints                  = critical,CA:FALSE
keyUsage                          = digitalSignature, nonRepudiation, keyEncipherment
nsCertType                        = server
extendedKeyUsage                  = serverAuth
nsComment                         = \"OpenSSL Generated Certificate\"
"))

            openssl ca -name ${ca} -extensions server -in ${dir}/newcerts/${firstCN}.csr -out ${dir}/certs/${firstCN}.pem  -config  <(cat ${configfile} <(printf "\n[alt_names]\n${alt_names}\n[server]
subjectKeyIdentifier              = hash
authorityKeyIdentifier            = keyid,issuer:always
issuerAltName                     = issuer:copy
subjectAltName                    = @alt_names
basicConstraints                  = critical,CA:FALSE
keyUsage                          = digitalSignature, nonRepudiation, keyEncipherment
nsCertType                        = server
extendedKeyUsage                  = serverAuth
nsComment                         = \"OpenSSL Generated Certificate\"
"))

        fi
        chmod 400 ${dir}/private/${firstCN}.key
        chmod 444 ${dir}/certs/${firstCN}.pem
    else
        info "${dir}/certs/${firstCN}.pem already exist, continu..." 1>&2
    fi
}

#============================
#  ALIAS AND FUNCTIONS
#============================

  #== error management function ==#
info() { fecho INF "${*}"; }
warning() { fecho WRN "WARNING: ${*}" 1>&2; countWrn=$(( ${countWrn} + 1 )); }
error() {     if [ ${flagOptVerbose} -eq 1 ];then
        checkdebug
    fi;fecho ERR "ERROR: ${*}" 1>&2; countErr=$(( ${countErr} + 1 )); }
cleanup() { [[ -e "${fileRC}" ]] && rm ${fileRC}; [[ -e "${fileLock}" ]] && [[ "$( head -1 ${fileLock} )" = "${EXEC_ID}" ]] && rm ${fileLock}; }
scriptfinish() { [[ $rc -eq 0 ]] && endType="INF" || endType="ERR";
    fecho ${endType} "${SCRIPT_NAME} finished at $(date "+%HH%M") (Time=${SECONDS}s, Error=${countErr}, Warning=${countWrn}, RC=$rc).";
    exit $rc ; }
checkdebug(){
echo "************************************************
 DefaultConfigFile : ${DefaultConfigFile}
 ConfigFile : ${ConfigFile}
 ConfigFolder : ${ConfigFolder}
 RootAuthority : ${RootAuthority}
 RootConfigFolder : ${RootConfigFolder}
 RootConfigFile : ${RootConfigFile}
 IntermediateAuthority : ${IntermediateAuthority}
 IntermediateConfigFolder : ${IntermediateConfigFolder}
 IntermediateConfigFile : ${IntermediateConfigFile}
 *******************************************************";}
  #== usage function ==#
usage() {
    . /etc/default/ssl;
    printf "Usage: ";
    head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#+" | sed -e "s/^#+[ ]*//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" | sed -e "s#\${DefaultConfigFile}#${DefaultConfigFile}#g";

}

usagefull() {
    . /etc/default/ssl;
    head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#[%+-]" | sed -e "s/^#[%+-]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" | sed -e "s#\${DefaultConfigFile}#${DefaultConfigFile}#g";
}
scriptinfo() { head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#-" | sed -e "s/^#-//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g"; }

  #== inter program return code function ==#
rc_save() { rc=$? && echo $rc > ${fileRC} ; }
rc_restore() { [[ -r "${fileRC}" ]] && rc=$(cat ${fileRC}) ; }
rc_assert() { [[ $rc -ne 0 ]] && error "${*} (RC=$rc)"; }


#============================
#  FILES AND VARIABLES
#============================

  #== general variables ==#
SCRIPT_HEADSIZE=$(head -200 ${0} |grep -n "^# END_OF_HEADER" | cut -f1 -d:)
SCRIPT_ID="$(scriptinfo | grep script_id | tr -s ' ' | cut -d' ' -f3)"
SCRIPT_NAME="$(basename ${0})" # scriptname without path
SCRIPT_UNIQ="${SCRIPT_NAME%.*}.${SCRIPT_ID}.$(date "+%y%m%d%H%M%S").${$}"
SCRIPT_DIR="$( cd $(dirname "$0") && pwd )" # script directory
SCRIPT_DIR_TEMP="/tmp" # Make sure temporary folder is RW

SCRIPT_TIMELOG_FLAG=0
SCRIPT_TIMELOG_FORMAT="+%y/%m/%d@%H:%M:%S"

HOSTNAME="$(hostname)"
FULL_COMMAND="${0} $*"
EXEC_DATE=$(date "+%y%m%d%H%M%S")
EXEC_ID=${$}
GNU_AWK_FLAG="$(awk --version 2>/dev/null | head -1 | grep GNU)"

fileRC="${SCRIPT_DIR_TEMP}/${SCRIPT_UNIQ}.tmp.rc";
fileLock="${SCRIPT_DIR_TEMP}/${SCRIPT_NAME%.*}.${SCRIPT_ID}.lock"
fileLog="/dev/null"
rc=0;

countErr=0;
countWrn=0;

  #== option variables ==#
flagOptErr=0
flagOptLog=0
flagOptinfo=0
flagOptVerbose=0

  #== option variables pour appel de fonction ==#
flagOptDefault=0
flagOptServeur=0
flagOptClient=0
flagOptRoot=0
flagOptIntermediate=0
flagOptPath=0

  #== options par d‚faut du script ==#
DefaultConfigFile=""                        # label pour une sous certification … racine root
PathIntermediateConfigFile=""            # label pour une sous certification … racine root
IntermediateConfigFolder=""                # designe le r‚pertoire des certificat: $ConfigFolder/$IntermediateConfigFile
ConfigPathIConfigFile=""                # designe le r‚pertoire des certificat: $ConfigFolder/$IntermediateConfigFile
ConfigFile=""                            # default: openssl.cnf
ConfigFolder=""                         # default: /etc/ssl/
RootConfigFile=""                        # ex: openssl.cnf
RootConfigFolder=""                     # ex: /etc/ssl/Root
RootAuthority=""                        # ex: Root

# typeset -A SSL_FLD
SSL_FLD=(
    RootAuthority
    Organisation
    Country
    Locality
    stateOrProvince
    emailAddress
    OCSP
    days
)

#============================
#  PARSE OPTIONS WITH GETOPTS
#============================

  #== set short options ==#
SCRIPT_OPTS='hvdscrap:i:-:m:'

  #== set long options associated with short one ==#
typeset -A ARRAY_OPTS
ARRAY_OPTS=(
    [help]=h
    [montre]=m
    [verbose]=v
    [default]=d
    [server]=s   
    [client]=c
    [authority]=a
    [intermediate]=i
    [info]=j
)

  #== set list of ssl fields ==#

  #== parse options ==#
while getopts ${SCRIPT_OPTS} OPTION ; do
    if [[ "x$OPTION" == "x-" ]]; then
        LONG_OPTION=$OPTARG
        LONG_OPTARG=$(echo $LONG_OPTION | grep "=" | cut -d'=' -f2)
        LONG_OPTIND=-1
        [[ "x$LONG_OPTARG" = "x" ]] && LONG_OPTIND=$OPTIND || LONG_OPTION=$(echo $OPTARG | cut -d'=' -f1)
        [[ $LONG_OPTIND -ne -1 ]] && eval LONG_OPTARG="\$$LONG_OPTIND"
        OPTION=${ARRAY_OPTS[$LONG_OPTION]}
        [[ "x$OPTION" = "x" ]] &&  OPTION="?" OPTARG="-$LONG_OPTION"
       
        if [[ $( echo "${SCRIPT_OPTS}" | grep -c "${OPTION}:" ) -eq 1 ]]; then
            if [[ "x${LONG_OPTARG}" = "x" ]] || [[ "${LONG_OPTARG}" = -* ]]; then
                OPTION=":" OPTARG="-$LONG_OPTION"
            else
                OPTARG="$LONG_OPTARG";
                if [[ $LONG_OPTIND -ne -1 ]]; then
                    [[ $OPTIND -le $Optnum ]] && OPTIND=$(( $OPTIND+1 ))
                    shift $OPTIND
                    OPTIND=1
                fi
            fi
        fi
    fi

    #== options follow by another option instead of argument ==#
    if [[ "x${OPTION}" != "x:" ]] && [[ "x${OPTION}" != "x?" ]] && [[ "${OPTARG}" = -* ]]; then
        OPTARG="$OPTION" OPTION=":"
    fi
    #== manage options ==#
    case "$OPTION" in
        a ) flagOptAutorite=1;;
           
        i )    flagOptIntermediate=1
            OptIntermediatePath="${OPTARG}"
        ;;
       
        s )    flagOptServeur=1;;
       
        c ) flagOptClient=1;;

        m)  flagOptMontre=1
             OptCert="${OPTARG}";;
       
        h ) usagefull
            exit 0;;

        j ) scriptinfo
            exit 0;;
       
        v ) flagOptVerbose=1
            set -x;;
       
        : ) error "${SCRIPT_NAME}: -$OPTARG: option requires an argument"
            flagOptErr=1 ;;

        ? ) error "${SCRIPT_NAME}: -$OPTARG: unknown option"
            flagOptErr=1 ;;
    esac
done
shift $((${OPTIND} - 1)) ## shift options

#============================
#  MAIN SCRIPT
#============================

if [ $flagOptDefault -eq 1 -o ! -f /etc/default/ssl ];then
    [ ${flagOptVerbose} -eq 1 ] && echo "flagOptDefault = 1"
   
    DoDefault
fi

. /etc/default/ssl

if [ "${flagOptAutorite}" = "1" ];then
    CreerAutorite
fi

if [ "${flagOptClient}" = "1" ];then
    CreerCertificat
fi
if [ "${flagOptServeur}" = "1" ];then
    CreerCertificat
fi
if [ "${flagOptMontre}" = "1" ];then
    openssl x509 -in ${OptCert} -noout -text
fi

