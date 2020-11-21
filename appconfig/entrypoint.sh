#!/bin/bash

set -x

echo #######
echo $$
echo #######

##if [ "$$" = 1 ]; then
    #
    # Setup envinronment for Kubernetes deployment.
    #

    if [ -e /mnt/mapr-cluster-cm ]; then
        for file in /mnt/mapr-cluster-cm/*; do
            name=$(basename "$file")
            value=$(cat "$file")
            export "$name"="$value"
        done
    fi

    if [ -z "$MAPT_TZ" ]; then
        export MAPR_TZ="UTC"
    fi

##    if [ -e /mnt/mapr-cluster-secret ]; then
        MAPR_CONTAINER_USER=${MAPR_CONTAINER_USER:-$MAPR_USER}
        MAPR_CONTAINER_USER=${MAPR_CONTAINER_USER:-$(cat "/mnt/mapr-cluster-secret/MAPR_CONTAINER_USER" 2>/dev/null)}
        MAPR_CONTAINER_USER=${MAPR_CONTAINER_USER:-$(cat "/mnt/mapr-cluster-secret/MAPR_USER" 2>/dev/null)}
        MAPR_CONTAINER_USER=${MAPR_CONTAINER_USER:-"mapr"}
        export MAPR_CONTAINER_USER
        MAPR_USER=${MAPR_USER:-$(cat "/mnt/mapr-cluster-secret/MAPR_USER" 2>/dev/null)}
        [ -n "$MAPR_USER" ] && export MAPR_USER

        MAPR_CONTAINER_UID=${MAPR_CONTAINER_UID:-$MAPR_UID}
        MAPR_CONTAINER_UID=${MAPR_CONTAINER_UID:-$(cat "/mnt/mapr-cluster-secret/MAPR_CONTAINER_UID" 2>/dev/null)}
        MAPR_CONTAINER_UID=${MAPR_CONTAINER_UID:-$(cat "/mnt/mapr-cluster-secret/MAPR_UID" 2>/dev/null)}
        MAPR_CONTAINER_UID=${MAPR_CONTAINER_UID:-"5000"}
        export MAPR_CONTAINER_UID
        MAPR_UID=${MAPR_UID:-$(cat "/mnt/mapr-cluster-secret/MAPR_UID" 2>/dev/null)}
        [ -n "$MAPR_UID" ] && export MAPR_UID

        MAPR_CONTAINER_GROUP=${MAPR_CONTAINER_GROUP:-$MAPR_GROUP}
        MAPR_CONTAINER_GROUP=${MAPR_CONTAINER_GROUP:-$(cat "/mnt/mapr-cluster-secret/MAPR_CONTAINER_GROUP" 2>/dev/null)}
        MAPR_CONTAINER_GROUP=${MAPR_CONTAINER_GROUP:-$(cat "/mnt/mapr-cluster-secret/MAPR_GROUP" 2>/dev/null)}
        MAPR_CONTAINER_GROUP=${MAPR_CONTAINER_GROUP:-"$MAPR_CONTAINER_USER"}
        export MAPR_CONTAINER_GROUP
        MAPR_GROUP=${MAPR_GROUP:-$(cat "/mnt/mapr-cluster-secret/MAPR_GROUP" 2>/dev/null)}
        [ -n "$MAPR_GROUP" ] && export MAPR_GROUP

        MAPR_CONTAINER_GID=${MAPR_CONTAINER_GID:-$MAPR_GID}
        MAPR_CONTAINER_GID=${MAPR_CONTAINER_GID:-$(cat "/mnt/mapr-cluster-secret/MAPR_CONTAINER_GID" 2>/dev/null)}
        MAPR_CONTAINER_GID=${MAPR_CONTAINER_GID:-$(cat "/mnt/mapr-cluster-secret/MAPR_GID" 2>/dev/null)}
        MAPR_CONTAINER_GID=${MAPR_CONTAINER_GID:-"$MAPR_CONTAINER_UID"}
        export MAPR_CONTAINER_GID
        MAPR_GID=${MAPR_GID:-$(cat "/mnt/mapr-cluster-secret/MAPR_GID" 2>/dev/null)}
        [ -n "$MAPR_GID" ] && export MAPR_GID

        MAPR_CONTAINER_PASSWORD=${MAPR_CONTAINER_PASSWORD:-$MAPR_PASSWORD}
        MAPR_CONTAINER_PASSWORD=${MAPR_CONTAINER_PASSWORD:-$(cat "/mnt/mapr-cluster-secret/MAPR_CONTAINER_PASSWORD" 2>/dev/null)}
        MAPR_CONTAINER_PASSWORD=${MAPR_CONTAINER_PASSWORD:-$(cat "/mnt/mapr-cluster-secret/MAPR_PASSWORD" 2>/dev/null)}
        MAPR_CONTAINER_PASSWORD=${MAPR_CONTAINER_PASSWORD:-"mapr"}
        export MAPR_CONTAINER_PASSWORD
        MAPR_PASSWORD=${MAPR_PASSWORD:-$(cat "/mnt/mapr-cluster-secret/MAPR_PASSWORD" 2>/dev/null)}
        [ -n "$MAPR_PASSWORD" ] && export MAPR_PASSWORD

        mapr_tickefile="/mnt/mapr-cluster-secret/CONTAINER_TICKET"
        MAPR_TICKETFILE_LOCATION=${MAPR_TICKETFILE_LOCATION:-$([ -e "$mapr_tickefile" ] && echo "$mapr_tickefile")}
        [ -n "$MAPR_TICKETFILE_LOCATION" ] && export MAPR_TICKETFILE_LOCATION
##    fi


    if echo "$ZEPPELIN_PORT" | grep -q "^tcp"; then
        export ZEPPELIN_PORT=$(echo "$ZEPPELIN_PORT" | cut -d : -f 3)
    fi



    #
    # Run initial mapr-setup.sh for PACC.
    #

    # Hack that allows to run "mapr-setup.sh container" not as init script (with PID=1).
    # To details take a look at "/opt/mapr/initscripts/mapr-fuse" and "/etc/init.d/functions".
    # TODO: Check this on Ubuntu.
    if [ -e "/etc/redhat-release" ]; then
        export SYSTEMCTL_SKIP_REDIRECT=1
    fi

    /opt/mapr/installer/docker/mapr-setup.sh "container" "/bin/true"

    unset SYSTEMCTL_SKIP_REDIRECT



    #
    # Continue execution of this entrypoint as MAPR_CONTAINER_USER
    #
    # Following piece copied from "container_post_client" function of "mapr-setup.sh"
    exec sudo -E -H -n -u $MAPR_CONTAINER_USER \
        -g ${MAPR_CONTAINER_GROUP:-$MAPR_GROUP} "$0" "$@"
##fi



#
# Fix for Ubuntu issues with environment variables for non-root user in Docker.
#
MAPR_ENV_FILE="/etc/profile.d/mapr.sh"
if [ -e "$MAPR_ENV_FILE" ]; then
  . "$MAPR_ENV_FILE"
fi



#
# Common functions
#
log_warn() {
    echo "WARN: $@"
}
log_msg() {
    echo "MSG: $@"
}
log_err() {
    echo "ERR: $@"
}

# Sielent "hadoop fs" calls
hadoop_fs_mkdir_p() {
    hadoop fs -mkdir -p "$1" >/dev/null 2>&1
}
hadoop_fs_get() {
    hadoop fs -get "$1" "$2" >/dev/null 2>&1
}
hadoop_fs_put() {
    hadoop fs -put "$1" "$2" >/dev/null 2>&1
}
hadoop_fs_test_e() {
    hadoop fs -test -e "$1" >/dev/null 2>&1
}

# Create files from tuples like "file_source file_destination"
copy_src_dst() {
    local src dst
    echo "$1" | while read src dst; do
        cp --no-clobber "$src" "$dst"
    done
}



#
# Common environment variables
#
export MAPR_HOME=${MAPR_HOME:-/opt/mapr}
export MAPR_CLUSTER=${MAPR_CLUSTER:-my.cluster.com}

SPARK_VERSION_FILE="${MAPR_HOME}/spark/sparkversion"
if [ -e "$SPARK_VERSION_FILE" ]; then
    SPARK_VERSION=$(cat "$SPARK_VERSION_FILE")
    export SPARK_HOME="${MAPR_HOME}/spark/spark-${SPARK_VERSION}"
fi

LIVY_VERSION_FILE="${MAPR_HOME}/livy/livyversion"
if [ -e "$LIVY_VERSION_FILE" ]; then
    LIVY_VERSION=$(cat "${MAPR_HOME}/livy/livyversion")
    export LIVY_HOME="${MAPR_HOME}/livy/livy-${LIVY_VERSION}"
fi

ZEPPELIN_VERSION=$(cat "${MAPR_HOME}/zeppelin/zeppelinversion")
export ZEPPELIN_HOME="${MAPR_HOME}/zeppelin/zeppelin-${ZEPPELIN_VERSION}"



#
# Local environment variables
#
LIVY_CONF_TUPLES="${LIVY_HOME}/conf/livy-client.conf.container_template ${LIVY_HOME}/conf/livy-client.conf
${LIVY_HOME}/conf/livy.conf.container_template ${LIVY_HOME}/conf/livy.conf
${LIVY_HOME}/conf/livy-env.sh.template ${LIVY_HOME}/conf/livy-env.sh
${LIVY_HOME}/conf/log4j.properties.template ${LIVY_HOME}/conf/log4j.properties
${LIVY_HOME}/conf/spark-blacklist.conf.template ${LIVY_HOME}/conf/spark-blacklist.conf"

ZEPPELIN_CONF_TUPLES="${ZEPPELIN_HOME}/conf/zeppelin-site.xml.template ${ZEPPELIN_HOME}/conf/zeppelin-site.xml
${ZEPPELIN_HOME}/conf/zeppelin-env.sh.template ${ZEPPELIN_HOME}/conf/zeppelin-env.sh
${ZEPPELIN_HOME}/conf/shiro.ini.template ${ZEPPELIN_HOME}/conf/shiro.ini"

SPARK_CONF_TUPLES="${SPARK_HOME}/conf/spark-defaults.conf.template ${SPARK_HOME}/conf/spark-defaults.conf
${SPARK_HOME}/conf/log4j.properties.template ${SPARK_HOME}/conf/log4j.properties"

LIVY_RSC_PORT_RANGE=${LIVY_RSC_PORT_RANGE:-"10000~10010"}
LIVY_RSC_PORT_RANGE=$(echo $LIVY_RSC_PORT_RANGE | sed "s/-/~/")

# Implicitly increase LIVY_RSC_PORT_RANGE because of LIVY-451
livy_rsc_port_min=$(echo "$LIVY_RSC_PORT_RANGE" | cut -d '~' -f 1)
livy_rsc_port_max=$(echo "$LIVY_RSC_PORT_RANGE" | cut -d '~' -f 2)
livy_rsc_port_max_new=$(expr "$livy_rsc_port_max" + 10)
LIVY_RSC_PORT_RANGE_NEW="${livy_rsc_port_min}~${livy_rsc_port_max_new}"

ZEPPELIN_ENV_SH="${ZEPPELIN_HOME}/conf/zeppelin-env.sh"
ZEPPELIN_ENV_DSR="${ZEPPELIN_HOME}/conf/zeppelin-env-dsr.sh"

SPARK_PORT_RANGE="${SPARK_PORT_RANGE:-11000~11010}"
SPARK_PORT_RANGE=$(echo $SPARK_PORT_RANGE | sed "s/-/~/")

REMOTE_ARCHIVES_DIR="/user/${MAPR_CONTAINER_USER}/zeppelin/archives"

LOCAL_ARCHIVES_DIR="$(getent passwd $MAPR_CONTAINER_USER | cut -d':' -f6)/zeppelin/archives"
LOCAL_ARCHIVES_ZIPDIR="${LOCAL_ARCHIVES_DIR}/zip"



#
# Functions to configure Livy
#
livy_conf_subs() {
    local livy_conf="$1"
    local sub="$2"
    local val="$3"
    if [ -n "${val}" ]; then
        sed -i -r "s|# (.*) ${sub}|\1 ${val}|" "${livy_conf}"
    fi
}

livy_setup() {
    copy_src_dst "$LIVY_CONF_TUPLES"
    if [ -n "$HOST_IP" ]; then
        livy_conf_subs "${LIVY_HOME}/conf/livy-client.conf" "__LIVY_HOST_IP__" "$HOST_IP"
    fi
    livy_conf_subs "${LIVY_HOME}/conf/livy-client.conf" "__LIVY_RSC_PORT_RANGE__" "$LIVY_RSC_PORT_RANGE_NEW"

    # TODO: refactor setup of livy.conf.
    # MZEP-162:
    sed -i 's/^.*livy\.ui\.enabled.*$/livy.ui.enabled=false/g' "${LIVY_HOME}/conf/livy.conf"
}



#
# Functions to configure Zeppelin
#
zeppelin_create_certificates() {
    if [ "$JAVA_HOME"x = "x" ]; then
        KEYTOOL=`which keytool`
    else
        KEYTOOL=$JAVA_HOME/bin/keytool
    fi

    DOMAINNAME=`hostname -d`
    if [ "$DOMAINNAME"x = "x" ]; then
        CERTNAME=`hostname`
    else
        CERTNAME="*."$DOMAINNAME
    fi

    if [ ! -e "$ZEPPELIN_SSL_KEYSTORE_PATH" ]; then
        echo "Creating 10 year self signed certificate for Zeppelin with subjectDN='CN=$CERTNAME'"
        mkdir -p $(dirname "$ZEPPELIN_SSL_KEYSTORE_PATH")
        $KEYTOOL -genkeypair -sigalg SHA512withRSA -keyalg RSA -alias "$MAPR_CLUSTER" -dname "CN=$CERTNAME" -validity 3650 \
                 -storepass "$ZEPPELIN_SSL_KEYSTORE_PASSWORD" -keypass "$ZEPPELIN_SSL_KEYSTORE_PASSWORD" \
                 -keystore "$ZEPPELIN_SSL_KEYSTORE_PATH" -storetype "$ZEPPELIN_SSL_KEYSTORE_TYPE"
        if [ $? -ne 0 ]; then
            echo "Keytool command to generate key store failed"
        fi
    else
        echo "Creating of Zeppelin keystore was skipped as it already exists: ${ZEPPELIN_SSL_KEYSTORE_PATH}."
    fi
}

zeppelin_setup_callback_port_range() {
    ZEPPELIN_INTERPRETER_CALLBACK_PORTRANGE=${ZEPPELIN_INTERPRETER_CALLBACK_PORTRANGE:-$(echo "$SPARK_PORT_RANGE" | sed 's/~/:/')}
    cat >> "$ZEPPELIN_ENV_DSR" <<EOF
export ZEPPELIN_INTERPRETER_CALLBACK_PORTRANGE="$ZEPPELIN_INTERPRETER_CALLBACK_PORTRANGE"

EOF
}

zeppelin_setup() {
    copy_src_dst "$ZEPPELIN_CONF_TUPLES"

    # Cleanup zeppelin-env-dsr.sh, as it needs to be generated by this script
    echo > "$ZEPPELIN_ENV_DSR"

    # Read zeppelin-env.sh, as certificate-related variables definde there
    . "$ZEPPELIN_ENV_SH"
    zeppelin_create_certificates

    zeppelin_setup_callback_port_range
}



#
# Functions to configure Spark
#
spark_get_property() {
    local spark_conf="${SPARK_HOME}/conf/spark-defaults.conf"
    local property_name="$1"
    grep "^\s*${property_name}" "${spark_conf}" | sed "s|^\s*${property_name}\s*||"
}

spark_set_property() {
    local spark_conf="${SPARK_HOME}/conf/spark-defaults.conf"
    local property_name="$1"
    local property_value="$2"
    if grep -q "^\s*${property_name}\s*" "${spark_conf}"; then
        # modify property
        sed -i -r "s|^\s*${property_name}.*$|${property_name} ${property_value}|" "${spark_conf}"
    else
        # add property
        echo "${property_name} ${property_value}" >> "${spark_conf}"
    fi
}

spark_append_property() {
    local spark_conf="${SPARK_HOME}/conf/spark-defaults.conf"
    local property_name="$1"
    local property_value="$2"
    local old_value=$(spark_get_property "${property_name}")
    local new_value=""
    if [ -z "${old_value}" ]; then
        # new value
        new_value="${property_value}"
    elif echo "${old_value}" | grep -q -F "${property_value}"; then
        # nothing to do
        new_value="${old_value}"
    else
        # modify value
        new_value="${old_value},${property_value}"
    fi
    spark_set_property "${property_name}" "${new_value}"
}

setup_spark_jars() {
    HBASE_VERSION=$(cat "${MAPR_HOME}/hbase/hbaseversion")
    HBASE_HOME="${MAPR_HOME}/hbase/hbase-${HBASE_VERSION}"
    # Copy MapR-DB and Streaming jars into Spark
    JAR_WHILDCARDS="
        ${MAPR_HOME}/lib/kafka-clients-*-mapr-*.jar
        ${MAPR_HOME}/lib/mapr-hbase-*-mapr-*.jar
        ${HBASE_HOME}/lib/hbase-*-mapr-*.jar
        ${ZEPPELIN_HOME}/interpreter/spark/spark-interpreter*.jar
    "
    for jar_path in $JAR_WHILDCARDS; do
        jar_name=$(basename "${jar_path}")
        if [ -e "${jar_path}" ] && [ ! -e "${SPARK_HOME}/jars/${jar_name}" ]; then
            ln -s "${jar_path}" "${SPARK_HOME}/jars"
        fi
    done
}

spark_fix_log4j() {  #DSR-20
    # Copied from Spark configure.sh
    #
    # Improved default logging level (WARN instead of INFO)
    #
    sed -i 's/rootCategory=INFO/rootCategory=WARN/' "${SPARK_HOME}/conf/log4j.properties"
}

spark_configure_hive_site() {
    local spark_conf="${SPARK_HOME}/conf/spark-defaults.conf"
    local spark_hive_site="${SPARK_HOME}/conf/hive-site.xml"
    if [ ! -e "${spark_hive_site}" ]; then
        cat > "${spark_hive_site}" <<'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
</configuration>
EOF
    fi
    local spark_yarn_dist_files=$(spark_get_property "spark.yarn.dist.files")
    # Check if no "hive-site.xml" in "spark.yarn.dist.files"
    if ! spark_get_property "spark.yarn.dist.files" | grep -q "hive-site.xml"; then
        spark_append_property "spark.yarn.dist.files" "${spark_hive_site}"
    fi
}

out_archive_local=""
out_archive_extracted=""
out_archive_remote=""
out_archive_filename=""
setup_archive() {
    local archive_path="$1"
    local archive_filename=$(basename "$archive_path")
    local archive_local=""
    local archive_remote=""
    if hadoop_fs_test_e "$archive_path"; then
        archive_remote="$archive_path"
        archive_local="${LOCAL_ARCHIVES_ZIPDIR}/${archive_filename}"
        if [ ! -e "$archive_local" ]; then
            log_msg "Copying archive from MapR-FS: ${archive_remote} -> ${archive_local}"
            hadoop_fs_get "$archive_remote" "$archive_local"
        else
            log_msg "Skip copying archive from MapR-FS as it already exists"
        fi
    elif [ -e "$archive_path" ]; then
        archive_local="$archive_path"
        archive_remote="${REMOTE_ARCHIVES_DIR}/${archive_filename}"
        # Copy archive to MapR-FS
        if ! hadoop_fs_test_e "$archive_remote"; then
            log_msg "Copying archive to MapR-FS: ${archive_local} -> ${archive_remote}"
            hadoop_fs_put "$archive_local" "$archive_remote"
        else
            log_msg "Skip copying archive to MapR-FS as it already exists"
        fi
    else
        log_err "Archive '${archive_path}' not found"
        return 1
    fi
    local archive_extracted="${LOCAL_ARCHIVES_DIR}/${archive_filename}"
    if [ ! -e "$archive_extracted" ]; then
        log_msg "Extracting archive locally"
        mkdir -p "$archive_extracted"
        unzip -qq "$archive_local" -d "$archive_extracted" || return 1
    else
        log_msg "Skip extracting archive locally as it already exists"
    fi

    out_archive_local="$archive_local"
    out_archive_extracted="$archive_extracted"
    out_archive_remote=$(echo "$archive_remote" | sed "s|maprfs://||")
    out_archive_filename="$archive_filename"
    return 0
}

spark_configure_python() {
    log_msg "Setting up Python archive"
    setup_archive "$ZEPPELIN_ARCHIVE_PYTHON" || return 1
    log_msg "Configuring Spark to use custom Python"
    spark_append_property "spark.yarn.dist.archives" "maprfs://${out_archive_remote}"
    spark_set_property "spark.yarn.appMasterEnv.PYSPARK_PYTHON" "./${out_archive_filename}/bin/python"
    log_msg "Configuring Zeppelin to use custom Python with Spark interpreter"
    cat >> "$ZEPPELIN_ENV_DSR" << EOF
export ZEPPELIN_SPARK_YARN_DIST_ARCHIVES="maprfs://${out_archive_remote}"
export PYSPARK_PYTHON='./${out_archive_filename}/bin/python'

EOF
    return 0
}

spark_configure_custom_envs() {
    if ! hadoop_fs_test_e "/user/${MAPR_CONTAINER_USER}/"; then
        log_warn "/user/${MAPR_CONTAINER_USER} does not exist in MapR-FS"
        return 1
    fi

    hadoop_fs_mkdir_p "$REMOTE_ARCHIVES_DIR"
    mkdir -p "$LOCAL_ARCHIVES_DIR" "$LOCAL_ARCHIVES_ZIPDIR"

    if [ -n "$ZEPPELIN_ARCHIVE_PYTHON" ]; then
        spark_configure_python || log_msg "Using default Python"
    else
        log_msg "Using default Python"
    fi

    if [ -n "$ZEPPELIN_ARCHIVE_PYTHON3" ]; then
        log_warn "Property 'ZEPPELIN_ARCHIVE_PYTHON3' is deprecated. Ignoring."
    fi
}

spark_setup() {
    copy_src_dst "$SPARK_CONF_TUPLES"

    setup_spark_jars
    spark_fix_log4j
    spark_configure_hive_site
    spark_configure_custom_envs

    if [ -n "$HOST_IP" ]; then
        spark_ports=$(echo "$SPARK_PORT_RANGE" | sed 's/~/\n/')
        read -a ports <<< $(seq $spark_ports)
        spark_set_property "spark.driver.bindAddress" "0.0.0.0"
        spark_set_property "spark.driver.host" "${HOST_IP}"
        spark_set_property "spark.driver.port" "${ports[0]}"
        spark_set_property "spark.blockManager.port" "${ports[1]}"
        spark_set_property "spark.ui.port" "${ports[2]}"
    else
      log_err "Can't configure Spark networking because \$HOST_IP is not set"
    fi
}



#
# Configure Livy, Zeppelin, and Spark
#
if [ -e "$LIVY_HOME" ]; then
    livy_setup
else
    log_warn '$LIVY_HOME not found'
fi

zeppelin_setup

if [ -e "$SPARK_HOME" ]; then
    spark_setup
else
    log_warn '$SPARK_HOME not found'
fi



#
# Start Livy and Zeppelin
#
if [ -e "$LIVY_HOME" ]; then
    cd "$LIVY_HOME"
    "${LIVY_HOME}/bin/livy-server" start &
fi

# Explicitly set Zeppelin working directory
# To prevent issues when Zeppelin started in / and its subprocesses cannot write to CWD
cd "${ZEPPELIN_HOME}"

# DSR-42
# Ensure that DEPLOY_MODE variable is not set as it affects Spark behaviour.
if [ -n "$DEPLOY_MODE" ]; then
    log_warn "'DEPLOY_MODE' parameter is obsolete. Use 'ZEPPELIN_DEPLOY_MODE' instead."

    # Backward compatibility with DEPLOY_MODE parameter.
    if [ -z "$ZEPPELIN_DEPLOY_MODE" ]; then
        ZEPPELIN_DEPLOY_MODE="$DEPLOY_MODE"
    fi

    unset DEPLOY_MODE
fi


if [ "$ZEPPELIN_DEPLOY_MODE" = "kubernetes" ]; then
    exec "${ZEPPELIN_HOME}/bin/zeppelin.sh" start
else
    "${ZEPPELIN_HOME}/bin/zeppelin-daemon.sh" start
    if [ $# -eq 0 ]; then
        exec bash
    else
        exec "$@"
    fi
fi
