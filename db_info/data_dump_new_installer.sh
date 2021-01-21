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

if [ -f "$UNRAVEL_PROPERTIES" ]
then
  echo "$file found."
  source <(grep -v '^ *#' $UNRAVEL_PROPERTIES | grep '[^ ] *=' | awk '{split($0,a,"="); print gensub(/\./, "_", "g", a[1]) "=" a[2]}')

  echo "unravel.jdbc.username=$unravel_jdbc_username"
  echo "unravel.jdbc.url=$unravel_jdbc_url"
  temp=`echo $unravel_jdbc_url | sed -e 's|^[^/]*//||' -e 's|/.*$||'`
  arrIN=(${temp//:/ })
  db_host=`echo ${arrIN[0]}`
  db_port=`echo ${arrIN[1]}`
  echo "db_host=$db_host"
  echo "db_port=$db_port"
  
else
  echo "$file not found."
fi

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
UNRAVEL_USER=$unravel_jdbc_username DB_HOST=$db_host DB_PORT=$db_port python db_connection_counter.py

# ElasticSearch data:
curl "localhost:4171/_cat/indices?v" > es_indices.txt
curl -v -XGET "http://localhost:4171/_mapping?pretty=true" > es_mapping.txt
curl -X GET "localhost:4171/_template/*?filter_path=*.version&pretty" > es_template.txt
curl -X GET "localhost:4171/_settings?pretty=true" > es_flash_setting.txt

cd ..
tar czvf unravel-info.tgz unravel-info

