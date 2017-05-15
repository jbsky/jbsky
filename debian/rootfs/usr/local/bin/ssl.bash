#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+	${SCRIPT_NAME} -r {OPTIONS}
#+	${SCRIPT_NAME} -i FILE {OPTIONS}
#+	${SCRIPT_NAME} -s {OPTIONS}
#+	${SCRIPT_NAME} -c {OPTIONS}
#+
#% DESCRIPTION
#%	This script help to generate certificat
#%
#% OPTIONS
#%	-p|--path=FILE									default /etc/ssl/openssl.cnf
#%	-a|--authority=NAME								default Root
#% 	-i|--intermediate								Generate Certificat Intermediate Authority
#%	-r|--root									Generate Certificat Authority 
#%	-s|--server									Generate Certificat Server
#%	-c|--client									Generate Certificat Client
#%	-d|--default									Set new default option in /etc/default/ssl
#%	-h|--help									Print this help
#%	-v|--verbose									Script en mode verbeux
#%	--info										Print script information
#%
#% EXAMPLES
#%	${SCRIPT_NAME} -r -a NAME 
#%	${SCRIPT_NAME} -i -a NAME -p FILE  
#%	${SCRIPT_NAME} -s  
#%	${SCRIPT_NAME} -c  
#%
#================================================================
#- IMPLEMENTATION
#-	version		 ${SCRIPT_NAME} 0.0.1
#-	author		Jbsky
#-	copyright	 
#-	license		 GNU General Public License
#-
#================================================================
#  HISTORY
#	 2016/03/01 : Script creation
# 
#================================================================
#  DEBUG OPTION
# set -n  # Uncomment to check your syntax, without execution.
# set -x  # Uncomment to debug this shell script
#
#================================================================
# END_OF_HEADER
#================================================================


# trap 'error "${SCRIPT_NAME}: FATAL ERROR at $(date "+%HH%M") (${SECONDS}s): Interrupt signal intercepted! Exiting now..."
	  # 2>&1 | tee -a ${fileLog:-/dev/null} >&2 ;
	  # exit 99;' INT QUIT TERM
# trap 'cleanup' EXIT

#============================
#  FUNCTIONS
#============================
  #== exec_cmd function ==#
exec_cmd() {
  {
	${*}
	rc_save
  } 2>&1 | fecho CAT "${*}"
  rc_restore
  rc_assert "Command failed: ${*}"
  return $rc ;
}

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

CheckAndCreateConfigFile(){

	if [ ! -f ${2} ];then
		case "${1}" in
			Root ) DoConfigFile ${2} ${RootAuthority}
			rm /usr/lib/ssl/openssl.cnf
			ln -s ${2} /usr/lib/ssl/openssl.cnf ;;
			Intermediate )
			DoIntermediateConfigFile
			DoConfigFile ${2} ${IntermediateAuthority}
			;;
		esac 
		info "${SCRIPT_NAME}: Config file ${1} created for ${2}" 1>&2
	else
		info "${SCRIPT_NAME}: Config file ${2} already exit " 1>&2
	fi
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
	if [ ! -f ${1}/index.db ];then
		touch ${1}/index.db
	else
		info "${SCRIPT_NAME}: ${1}/index.db already exit " 1>&2
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
	if [ ${flagOptVerbose} -eq 1 ];then
		echo "DoDefault"
	fi
	if [ "${DefaultConfigFile}" == "" ];then
		if [[ "${ConfigFolder}" == "" ]];then
			ConfigFolder="/etc/ssl/"
		fi
		if [[ "${ConfigFile}" == "" ]];then
			ConfigFile="openssl.cnf"
		fi
		DefaultConfigFile=${ConfigFolder}${ConfigFile}

	fi
	read -p "Please enter the path to your default config files, '"${DefaultConfigFile}"' press [ENTER] to confirm : " NEW_PathConfigFile
	if [[ "${NEW_PathConfigFile}" == "" ]];then
		echo "DefaultConfigFile=${DefaultConfigFile}">/etc/default/ssl 
	else
		echo "DefaultConfigFile=${NEW_PathConfigFile}">/etc/default/ssl 
	fi
			
	if [[ "${OptAuthority}" == "" ]];then
		RootAuthority="Root"
	else
		RootAuthority=${OptAuthority}
	fi
	
	read -p "Please enter the name for your RootAuthority, '"${RootAuthority}"' press [ENTER] to confirm : " NEW_RootAuthority
	if [[ "${NEW_RootAuthority}" == "" ]];then
		echo "RootAuthority=${RootAuthority}">>/etc/default/ssl 
	else
		echo "RootAuthority=${NEW_RootAuthority}">>/etc/default/ssl 
	fi	
	if [[ "${Bits}" == "" ]];then
		Bits=2048
	fi
	read -p  "Set the new number of Bits : '"${Bits}"' Bits press [ENTER] to confirm : " NEW_Bits
	case "${NEW_Bits}" in
		2048|4096|8192)
		echo "Bits=${NEW_Bits}">>/etc/default/ssl
		;;
	*)
		echo "Bits=1024">>/etc/default/ssl	
		;;
	esac
		
	if [[ "${Organisation}" == "" ]];then
		Organisation="Discover"
	fi
	read -p "Please enter the name for your organisation, '"${Organisation}"' press [ENTER] to confirm : " NEW_Organisation
	if [[ "${NEW_Organisation}" == "" ]];then
		echo "Organisation=${Organisation}">>/etc/default/ssl
	else 
		echo "Organisation=${NEW_Organisation}">>/etc/default/ssl
	fi
		
	if [[ "${Country}" == "" ]];then
		Country=FR
	fi
	read -p "Please enter the name for your country, '"${Country}"' press [ENTER] to confirm : " NEW_Country
	if [[ "${NEW_Country}" == "" ]];then
		echo "Country=${Country}">>/etc/default/ssl 
	else 
		echo "Country=${NEW_Country}">>/etc/default/ssl
	fi
		
	if [[ "${Locality}" == "" ]];then
		Locality=Montpellier
	fi
	read -p "Please enter the name for your locality, '"${Locality}"' press [ENTER] to confirm : " NEW_Locality
	if [[ "${NEW_Locality}" == "" ]];then
		echo "Locality=${Locality}">>/etc/default/ssl
	else 
		echo "Locality=${NEW_Locality}">>/etc/default/ssl
	fi
		
	if [[ "${stateOrProvince}" == "" ]];then
		stateOrProvince="Occitanie"
	fi
	read -p "Please enter the name for your stateOrProvince, '"${stateOrProvince}"' press [ENTER] to confirm : " NEW_stateOrProvince
	if [[ "${NEW_stateOrProvince}" == "" ]];then
		echo "stateOrProvince=${stateOrProvince}">>/etc/default/ssl 
	else 
		echo "stateOrProvince=${NEW_stateOrProvince}">>/etc/default/ssl
	fi
	
	read -p "Please enter your email address, '"${emailAddress}"' press [ENTER] to confirm : " NEW_emailAddress
	if [[ "${NEW_emailAddress}" == "" ]];then
		echo "emailAddress=${emailAddress}">>/etc/default/ssl 
	else 
		echo "emailAddress=${NEW_emailAddress}">>/etc/default/ssl
	fi

	[ ${flagOptRoot} -eq 0 ] && exit 0
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

  # == cr‚er le fichier ${IntermediateConfigFile} ==#
  # == ex:  /etc/ssl/service.cnf ==#
DoIntermediateConfigFile(){
 	if [ ${flagOptVerbose} -eq 1 ];then
		echo "DoIntermediateConfigFile"
	fi

cat <<EOF>> ${RootConfigFile}

[${IntermediateAuthority^^}_CA]
nsComment                         = "${IntermediateAuthority^^} Secure Digital Certificate Signing"
subjectKeyIdentifier              = hash
authorityKeyIdentifier            = keyid:always,issuer
basicConstraints                  = critical, CA:true, pathlen:0
keyUsage                          = critical, digitalSignature, cRLSign, keyCertSign
nsCertType                        = sslCA
EOF

}

  # == cr‚er le fichier	${IntermediateConfigFile} ==#
  # == out				${RootConfigFile} ==#
  # == ex:  /etc/ssl/openssl.cnf ==#
DoConfigFile(){
 	if [ ${flagOptVerbose} -eq 1 ];then
		echo "DoConfigFile"
	fi
cat <<EOF> ${1}
HOME                              = .
RANDFILE                          = \$ENV::HOME/.rnd

[policy_strict]
countryName                       = match
stateOrProvinceName               = match
localityName                      = match
organizationName                  = match
organizationalUnitName            = match
commonName                        = supplied
emailAddress                      = match

[ca]
default_ca                        = ${2^^}

[${2^^}]
dir                               = ${ConfigFolder}/${2}
certs                             = \$dir/certs                        # Where the issued certs are kept
new_certs_dir                     = \$dir/newcerts                     # default place for new certs.
database                          = \$dir/index.db                     # database index file.
certificate                       = \$dir/certs/ca.pem                 # The CA certificate
serial                            = \$dir/serial                       # The current serial number
private_key                       = \$dir/private/ca.key               # The private key
default_days                      = 3650                               # how long to certify for
default_md                        = sha256                             # which md to use.
preserve                          = no                                 # keep passed DN ordering
policy                            = policy_strict                      # voir le champs ci dessous
 
 
[${2^^}_CA]
nsComment                         = "${2} Secure Digital Certificate Signing"
subjectKeyIdentifier              = hash
authorityKeyIdentifier            = keyid,issuer:always
basicConstraints                  = critical,CA:TRUE,pathlen:0
keyUsage                          = critical, digitalSignature, cRLSign, keyCertSign


[req]
default_bits                      = 2048
distinguished_name                = req_distinguished_name
string_mask                       = utf8only
default_md                        = sha256                             # SHA-2
x509_extensions                   = ${2^^}_CA

[req_distinguished_name]
countryName                       = Country Name (2 letter code)
countryName_min                   = 2
countryName_max                   = 2
stateOrProvinceName               = State or Province Name (full name)
localityName                      = Locality Name (eg, city)
organizationName                  = Organization Name (eg, company)
organizationalUnitName            = Organizational Unit Name (eg, section)
commonName                        = Common Name (eg, YOUR name)
commonName_max                    = 64
emailAddress                      = Email Address
emailAddress_max                  = 40
commonName_default                = 
organizationalUnitName_default    = Secure Digital Certificate Signing
organizationName_default          = ${Organisation}
countryName_default               = ${Country}
localityName_default              = ${Locality}
stateOrProvinceName_default       = ${stateOrProvince}
emailAddress_default              = ${emailAddress}

[SERVER]
nsComment                         = "Secure Digital Certificate Server - ${RootAuthority}"
subjectKeyIdentifier              = hash
authorityKeyIdentifier            = keyid,issuer:always
issuerAltName                     = issuer:copy
subjectAltName                    = @alt_names
basicConstraints                  = critical,CA:FALSE
keyUsage                          = digitalSignature, nonRepudiation, keyEncipherment
nsCertType                        = server
extendedKeyUsage                  = serverAuth
 
[alt_names]
DNS.1                             =
DNS.2                             =

[CLIENT]
nsComment                         = "Secure Digital Certificate Client - ${RootAuthority}"
subjectKeyIdentifier              = hash
authorityKeyIdentifier            = keyid,issuer:always
subjectAltName                    = email:copy
issuerAltName                     = issuer:copy
basicConstraints                  = critical,CA:FALSE
keyUsage                          = digitalSignature, nonRepudiation, keyEncipherment
nsCertType                        = client, email, objsign
extendedKeyUsage                  = clientAuth
EOF
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
DoAuthority(){
	local ca;
	ca="ca"
	if [ ${flagOptVerbose} -eq 1 ];then
		echo "DoAuthority"
	fi
	
	sed -i -e 's/^commonName_default.*$/commonName_default                 = '${Organisation}' - Certification Authority '${RootAuthority}'/g'  ${RootConfigFile}
	
	if [ ! -f ${RootConfigFolder}/certs/${ca}.pem ];then
		
		openssl req -x509 -newkey rsa:${Bits} -sha256 -extensions ${RootAuthority^^}_CA -days 3650 -keyout ${RootConfigFolder}/private/${ca}.key -out ${RootConfigFolder}/certs/${ca}.pem -config ${RootConfigFile} 
	
		chmod 400 ${RootConfigFolder}/private/${ca}.key
		chmod 444 ${RootConfigFolder}/certs/${ca}.pem
		openssl x509 -serial -noout -in ${RootConfigFolder}/certs/${ca}.pem | cut -d= -f2 > ${RootConfigFolder}/serial
		printf "%X\n" $((0x`cat ${RootConfigFolder}/serial`+1))>${RootConfigFolder}/serial
	else
		info "${RootConfigFolder}/certs/${ca}.pem already exist, continu..." 1>&2
	fi
}

  #== cr‚er CA Intermediate ==#
DoIntermediate(){
	local ca;
	ca="ca"

	if [ ${flagOptVerbose} -eq 1 ];then
		echo "DoIntermediate"
	fi

	sed -i -e 's/^commonName_default.*$/commonName_default                = '${Organisation}' - Certification Authority '${IntermediateAuthority}'/g' ${IntermediateConfigFile}

	DoPrivateKey ${ca} ${IntermediateConfigFolder} ${IntermediateConfigFile}

	# echo "G‚n‚ration de la cl‚ priv‚ crypt‚ pour [${RootAuthority^^}_CA]..."
	if [ ! -f ${RootConfigFolder}/certs/${ca}.pem ];then
		Error "${RootConfigFolder}/certs/${ca}.pem not exist, please use --root flag first! " 1>&2
		usage
		exit 101
	fi
	if [ ! -f ${IntermediateConfigFolder}/certs/${ca}.pem ];then
		# openssl req -new -out CSR.csr -key privateKey.key 
		openssl req -sha256 -new -key  ${IntermediateConfigFolder}/private/${ca}.key -out ${IntermediateConfigFolder}/newcerts/${ca}.csr  -config ${IntermediateConfigFile}

		# echo "Signature du certificat d'autorit‚ par [${IntermediateAuthority^^}_CA]."
		openssl ca -extensions ${IntermediateAuthority^^}_CA -in ${IntermediateConfigFolder}/newcerts/${ca}.csr -out ${IntermediateConfigFolder}/certs/${ca}.pem -config ${RootConfigFile}

		cat  ${RootConfigFolder}/certs/${ca}.pem > ${IntermediateConfigFolder}/certs/ca-chain.pem
		cat  ${IntermediateConfigFolder}/certs/${ca}.pem >> ${IntermediateConfigFolder}/certs/ca-chain.pem

		chmod 444 ${IntermediateConfigFolder}/certs/ca-chain.pem
		chmod 400 ${IntermediateConfigFolder}/private/${ca}.key
		chmod 444 ${IntermediateConfigFolder}/certs/${ca}.pem

		openssl x509 -serial -noout -in ${IntermediateConfigFolder}/certs/ca.pem | cut -d= -f2 > ${IntermediateConfigFolder}/serial
	else
		info "${IntermediateConfigFolder}/certs/${ca}.pem already exist, continu..." 1>&2
	fi
}

DoCert(){

	case "${1}" in
	"client")
		read -p "Name for a new client:" CommonName
		;;
	"server")
		while [ "${CommonName}" == "" ];do
			read -p "FQND or IP (not blank) : " CommonName
		done
		sed -i -e 's/^DNS.1.*$/DNS.1                             = '${CommonName}'/g'  ${RootConfigFile}
		read -p "IP :" CommonName2
		sed -i -e 's/^DNS.2.*$/DNS.2                             = '${CommonName2}'/g'  ${RootConfigFile}
		;;
	esac
	if [ ${flagOptVerbose} -eq 1 ];then
		echo "DoCert"
	fi

	
	sed -i -e 's/^commonName_default.*$/commonName_default                = '${CommonName}'/g'  ${RootConfigFile}

	DoPrivateKey ${CommonName} ${RootConfigFolder} ${RootConfigFile}
	
	if [ ! -f ${RootConfigFolder}/certs/${CommonName}.pem ];then
		openssl req -new -sha256 -key ${RootConfigFolder}/private/${CommonName}.key -out ${RootConfigFolder}/newcerts/${CommonName}.csr -nodes -config ${RootConfigFile}
	
		case "${1}" in
		"client")
			openssl ca -name ${RootAuthority^^} -extensions CLIENT -in ${RootConfigFolder}/newcerts/${CommonName}.csr -out ${RootConfigFolder}/certs/${CommonName}.pem -config ${RootConfigFile}
			openssl pkcs12 -export -inkey ${RootConfigFolder}/private/${CommonName}.key -in ${RootConfigFolder}/certs/${CommonName}.pem -name "${CommonName}" -certfile ${RootConfigFolder}/certs/ca.pem -caname "${RootAuthority}" -out ${RootConfigFolder}/${CommonName}.p12 
			;;
		"server")
			openssl ca -name ${RootAuthority^^} -extensions SERVER -in ${RootConfigFolder}/newcerts/${CommonName}.csr -out ${RootConfigFolder}/certs/${CommonName}.pem -config  ${RootConfigFile}
			;;
		esac

		chmod 400 ${RootConfigFolder}/private/${CommonName}.key
		chmod 444 ${RootConfigFolder}/certs/${CommonName}.pem
	else
		info "${RootConfigFolder}/certs/${CommonName}.pem already exist, continu..." 1>&2
	fi
}

#============================
#  ALIAS AND FUNCTIONS
#============================

  #== error management function ==#
info() { fecho INF "${*}"; }
warning() { fecho WRN "WARNING: ${*}" 1>&2; countWrn=$(( ${countWrn} + 1 )); }
error() { 	if [ ${flagOptVerbose} -eq 1 ];then
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
usage() { printf "Usage: "; head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#+" | sed -e "s/^#+[ ]*//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" ; }
usagefull() { head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#[%+-]" | sed -e "s/^#[%+-]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" ; }
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
flagOptServer=0
flagOptClient=0
flagOptRoot=0
flagOptIntermediate=0
flagOptPath=0

  #== options par d‚faut du script ==#
DefaultConfigFile=""						# label pour une sous certification … racine root
PathIntermediateConfigFile=""			# label pour une sous certification … racine root
IntermediateConfigFolder=""				# designe le r‚pertoire des certificat: $ConfigFolder/$IntermediateConfigFile
ConfigPathIConfigFile=""				# designe le r‚pertoire des certificat: $ConfigFolder/$IntermediateConfigFile
ConfigFile=""							# default: openssl.cnf
ConfigFolder="" 						# default: /etc/ssl/
RootConfigFile=""						# ex: openssl.cnf
RootConfigFolder="" 					# ex: /etc/ssl/Root
RootAuthority=""						# ex: Root


#============================
#  PARSE OPTIONS WITH GETOPTS
#============================

  #== set short options ==#
SCRIPT_OPTS='hvdscra:p:i:-:'

  #== set long options associated with short one ==#
typeset -A ARRAY_OPTS
ARRAY_OPTS=(
	[help]=h
	[man]=h	
	[verbose]=v
	[default]=d
	[server]=s	
	[client]=c
	[root]=r
	[authority]=a
	[path]=p
	[intermediate]=i
	[info]=j
)

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
		a ) flagOptAuthority=1
			OptAuthority="${OPTARG}" ;;
			
		p ) flagOptPath=1
			OptPath="${OPTARG}" ;;

		d )	flagOptDefault=1 ;;
	
		r )	flagOptRoot=1  ;;

		i )	flagOptIntermediate=1 
			OptIntermediatePath="${OPTARG}" 
		;;
		
		s )	flagOptServer=1 ;;
		
		c ) flagOptClient=1 ;;

		h ) usagefull
			exit 0 ;;

		j ) scriptinfo
			exit 0 ;;
		
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

[ $flagOptErr -eq 1 ] && usage 1>&2 && exit 1 ## print usage if option error and exit

  #== Check/Set arguments ==#
[[ $# -gt 2 ]] && error "${SCRIPT_NAME}: Too many arguments" && usage 1>&2 && exit 5

if [ $flagOptDefault -eq 1 -o ! -f /etc/default/ssl ];then
	[ ${flagOptVerbose} -eq 1 ] && echo "flagOptDefault = 1"
	
	if [ -f /etc/default/ssl ];then
		. /etc/default/ssl
	fi
	
	DoDefault
else
	. /etc/default/ssl

fi

if [ ${flagOptPath} -eq 1 ];then
	RootPath=${OptPath}
else
	RootPath=${DefaultConfigFile}
fi

[ ${flagOptVerbose} -eq 1 ] && echo "extract_FileAndFolderConfig \$RootPath :" ${RootPath}

extract_FileAndFolderConfig ${RootPath}

RootConfigFile=${ConfigFolder}/${ConfigFile}

if [ -f "${RootConfigFile}" ];then
	RootAuthority=`grep "^default_ca\ " ${RootConfigFile} | sed 's/  */ /g' | cut -d "=" -f 2 | xargs`
	RootConfigFolder=`grep "^dir\ " ${RootConfigFile} | sed 's/  */ /g' | cut -d "=" -f 2 | xargs`
else
	RootConfigFolder=${ConfigFolder}/${RootAuthority}
fi



[ ${flagOptVerbose} -eq 1 ] && echo checkcheck && checkdebug

if [ ${flagOptRoot} -eq 1 ];then
	[ ${flagOptVerbose} -eq 1 ] && echo "flagOptRoot"

	[ ! "${OptAuthority}" = "" -a ${flagOptIntermediate} -eq 0 ] && RootAuthority=${OptAuthority}

	[ ${flagOptVerbose} -eq 1 ] && echo "Parametre ConfigFile : ${ConfigFile}"
		
	CheckAndCreateTreeFolder ${RootConfigFolder}

	CheckAndCreateConfigFile "Root" ${RootConfigFile}

	DoAuthority  ${ConfigFile}
fi

if [[ ${flagOptIntermediate} -eq 1 ]];then
	[ ${flagOptVerbose} -eq 1 ] && echo "flagOptIntermediate"

	if [ ! "${OptAuthority}" = "" ];then
		IntermediateAuthority=${OptAuthority}
	else
		while [ "${IntermediateAuthority}" == "" ];do
			read -p "Please enter the name for your intermedaite authority : " IntermediateAuthority
		done
	fi
	
	extract_FileAndFolderConfig ${OptIntermediatePath}
	
	IntermediateConfigFolder=${ConfigFolder}/${IntermediateAuthority}
	IntermediateConfigFile=${ConfigFolder}/${ConfigFile}
		
	[ ${RootConfigFile} = ${IntermediateConfigFile} ] && error "Intermediate config file is same as root config file." && usage 1>&2 && exit 11

	[ ${flagOptVerbose} -eq 1 ] && checkdebug 

	CheckAndCreateConfigFile "Intermediate" ${IntermediateConfigFile}

	CheckAndCreateTreeFolder  ${IntermediateConfigFolder}

	DoIntermediate
fi
[ ${flagOptVerbose} -eq 1 ] && checkdebug

if [  `echo $((flagOptServer))` -eq 1 ];then
	DoCert "server"
fi
if [ `echo $((flagOptClient))` -eq 1 ];then
	DoCert "client"
fi
