mkdir unravel-info
cd unravel-info

/opt/unravel/manager version > unravel-version.txt

cp -p ../db_connection_counter.py .

# Please update the unravel version
UNRAVEL_VERSION="/opt/unravel/versions/SUPPORT-342.816"

# tables to be cleaned up defined in tableFieldData.json
# Please update the unravel_version
cp -p $UNRAVEL_VERSION/core/etc/tableFieldData.json .
cp -p /opt/unravel/data/conf/unravel.properties .
cp -p /opt/unravel/logs/tidydir.log .
cp -p -r /opt/unravel/logs/elasticsearch_1 .
cp -p /opt/unravel/logs/hitdoc_loader.log .


# Please update the table_schema accordingly
/opt/unravel/manager run dbcli -e 'SELECT table_schema AS "DB Name", SUM(data_length + index_length) / 1024 / 1024 / 1024 AS "DB Size (GB)" FROM information_schema.TABLES where table_schema="unravel_mysql_prod" GROUP BY table_schema'  > mysql-unravel-db-size.txt

/opt/unravel/manager run dbcli -e 'select TABLE_NAME, round((data_length + index_length) / 1024 / 1024 / 1024, 2) as total_size_gb, round(DATA_LENGTH / 1024 / 1024 / 1024, 2) as data_size_gb, round(INDEX_LENGTH / 1024 / 1024 / 1024, 2) as index_size_gb, TABLE_ROWS from information_schema.tables where table_schema not in ("information_schema", "mysql") order by total_size_gb desc' > mysql-unravel-table-size.txt

/opt/unravel/manager run dbcli -e 'select * from information_schema.partitions where TABLE_SCHEMA="unravel_mysql_prod" and PARTITION_NAME is not null' > mysql-unravel-partitions.txt

/opt/unravel/manager run dbcli -e 'show variables like "%version%"' > mysql-version.txt

df -h > disk.txt

cat /proc/cpuinfo > cpu.txt

free -h > mem.txt

du -sh /opt/unravel > du-local-unravel.txt

# Please update the right directory
du -sh /opt/unravel/data/* > du-srv-unravel.txt

ps aux | grep unravel > unravel-ps.txt

cat /etc/redhat-release > os.txt

# Check Db session per unravel Daemon
# NOTE: DB_HOST parameter should match the host part of JDBC URL specified via unravel.jdbc.url in unravel.properties. Otherwise, you may see empty result.
# this will generate db_session.txt
UNRAVEL_USER=unravel DB_HOST=localhost DB_PORT=5432 python db_connection_counter.py

# ElasticSearch data:
curl "localhost:4171/_cat/indices?v" > es_indices.txt
curl -v -XGET "http://localhost:4171/_mapping?pretty=true" > es_mapping.txt
curl -X GET "localhost:4171/_template/*?filter_path=*.version&pretty" > es_template.txt
curl -X GET "localhost:4171/_settings?pretty=true" > es_flash_setting.txt

cd ..
tar czvf unravel-info.tgz unravel-info

