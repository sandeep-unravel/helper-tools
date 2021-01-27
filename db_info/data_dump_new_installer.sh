for ARGUMENT in "$@"
do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)   

    case "$KEY" in
            unravel_path)              UNRAVEL_PATH=${VALUE} ;;
            unravel_version)           UNRAVEL_VERSION=${VALUE} ;;
            *)   
    esac 
done

# echo "unravel_path=$UNRAVEL_PATH"


DEFAULT_PATH=/opt/unravel
DEFAULT_VERSION=saml_auth-1.yaml.796
UNRAVEL_PATH=${UNRAVEL_PATH:-$DEFAULT_PATH}
UNRAVEL_VERSION=${UNRAVEL_VERSION:-$DEFAULT_VERSION}
echo "unravel_path=$UNRAVEL_PATH"
echo "unravel_version=$UNRAVEL_VERSION"
UNRAVEL_PROPERTIES="$UNRAVEL_PATH/data/conf/unravel.properties"


function getProperty {
   PROP_KEY=$1
   PROP_VALUE=`cat $UNRAVEL_PROPERTIES | grep "$PROP_KEY" | cut -d'=' -f2`
   echo $PROP_VALUE
}

JDBC_USERNAME=$(getProperty "unravel.jdbc.username")
JDBC_URL=$(getProperty "unravel.jdbc.url")
echo "jdbc_username=$JDBC_USERNAME"
echo "jdbc_url=$JDBC_URL"
temp=`echo $JDBC_URL | sed -e 's|^[^/]*//||' -e 's|/.*$||'`
echo "temp: $temp"
arrIN=(${temp//:/ })
DB_HOST=`echo ${arrIN[0]}`
DB_PORT=`echo ${arrIN[1]}`
echo "DB_HOST=$DB_HOST"
echo "DB_PORT=$DB_PORT"

echo "PATH SET"

mkdir unravel-info
cd unravel-info

$UNRAVEL_PATH/manager version > unravel-version.txt
cp -p ../db_connection_counter.py .

# Please update the unravel version
# UNRAVEL_VERSION="/opt/unravel/versions/SUPPORT-342.816"

# tables to be cleaned up defined in tableFieldData.json
# Please update the unravel_version
cp -p $UNRAVEL_PATH/versions/$UNRAVEL_VERSION/core/etc/tableFieldData.json .
cp -p $UNRAVEL_PATH/data/conf/unravel.properties .
cp -p $UNRAVEL_PATH/logs/tidydir.log .
cp -p -r $UNRAVEL_PATH/logs/elasticsearch_1 .
cp -p $UNRAVEL_PATH/logs/hitdoc_loader.log .


# Please update the table_schema accordingly
$UNRAVEL_PATH/manager run dbcli -e 'SELECT table_schema AS "DB Name", SUM(data_length + index_length) / 1024 / 1024 / 1024 AS "DB Size (GB)" FROM information_schema.TABLES where table_schema="unravel_mysql_prod" GROUP BY table_schema'  > mysql-unravel-db-size.txt

$UNRAVEL_PATH/manager run dbcli -e 'select TABLE_NAME, round((data_length + index_length) / 1024 / 1024 / 1024, 2) as total_size_gb, round(DATA_LENGTH / 1024 / 1024 / 1024, 2) as data_size_gb, round(INDEX_LENGTH / 1024 / 1024 / 1024, 2) as index_size_gb, TABLE_ROWS from information_schema.tables where table_schema not in ("information_schema", "mysql") order by total_size_gb desc' > mysql-unravel-table-size.txt

$UNRAVEL_PATH/manager run dbcli -e 'select * from information_schema.partitions where TABLE_SCHEMA="unravel_mysql_prod" and PARTITION_NAME is not null' > mysql-unravel-partitions.txt

$UNRAVEL_PATH/manager run dbcli -e 'show variables like "%version%"' > mysql-version.txt

df -h > disk.txt

cat /proc/cpuinfo > cpu.txt

free -h > mem.txt

du -sh $UNRAVEL_PATH > du-local-unravel.txt

# Please update the right directory
du -sh $UNRAVEL_PATH/data/* > du-srv-unravel.txt

ps aux | grep unravel > unravel-ps.txt

cat /etc/redhat-release > os.txt

# Check Db session per unravel Daemon
# NOTE: DB_HOST parameter should match the host part of JDBC URL specified via unravel.jdbc.url in unravel.properties. Otherwise, you may see empty result.
# this will generate db_session.txt
echo "Running DB Counter: UNRAVEL_USER=$JDBC_USERNAME DB_HOST=$DB_HOST DB_PORT=$DB_PORT python db_connection_counter.py"
UNRAVEL_USER=$JDBC_USERNAME DB_HOST=$DB_HOST DB_PORT=$DB_PORT python db_connection_counter.py

# ElasticSearch data:
curl "localhost:4171/_cat/indices?v" > es_indices.txt
curl -v -XGET "http://localhost:4171/_mapping?pretty=true" > es_mapping.txt
curl -X GET "localhost:4171/_template/*?filter_path=*.version&pretty" > es_template.txt
curl -X GET "localhost:4171/_settings?pretty=true" > es_flash_setting.txt

cd ..
tar czvf unravel-info.tgz unravel-info

